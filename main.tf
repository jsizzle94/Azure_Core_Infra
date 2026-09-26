

resource "azurerm_resource_group" "Core" {
  name     = "core-rg"
  location = var.location
}

resource "azurerm_virtual_network" "hubvnet" {
  location            = azurerm_resource_group.Core.location
  name                = "hubvnet"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.Core.name
  subnet {
    name             = "AzureFirewallSubnet"
    address_prefixes = ["10.0.10.0/24"]
  }
  subnet {
    name             = "GatewaySubnet"
    address_prefixes = ["10.0.1.0/24"]
  }
  subnet {
    name             = "snet-shared-services"
    address_prefixes = ["10.0.2.0/24"]
  }
  subnet {
    name             = "snet-dns-resolver"
    address_prefixes = ["10.0.3.0/24"]

    delegation {
      name = "dns-resolver"

      service_delegation {
        name = "Microsoft.Network/dnsResolvers"

        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action"
        ]

      }
    }
  }

}

resource "azurerm_virtual_network" "spokevnet" {
  location            = azurerm_resource_group.Core.location
  name                = "spokevnet"
  address_space       = ["10.1.0.0/16"]
  resource_group_name = azurerm_resource_group.Core.name

  subnet {
    name             = "snet-workload"
    address_prefixes = ["10.1.1.0/24"]
  }

  subnet {
    name             = "snet-private-endpoints"
    address_prefixes = ["10.1.2.0/24"]
  }
  subnet {
    name             = "snet-aci"
    address_prefixes = ["10.1.3.0/24"]
    delegation {
      name = "aci"

      service_delegation {
        name = "Microsoft.ContainerInstance/containerGroups"

        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
  }
}



resource "azurerm_virtual_network_peering" "hubtospoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.Core.name
  virtual_network_name      = azurerm_virtual_network.hubvnet.name
  remote_virtual_network_id = azurerm_virtual_network.spokevnet.id
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "spoketohub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.Core.name
  virtual_network_name      = azurerm_virtual_network.spokevnet.name
  remote_virtual_network_id = azurerm_virtual_network.hubvnet.id
  use_remote_gateways       = true



}


#### Test networking container to run network tests and DNS digs to git into Azure networking deeply.
resource "azurerm_container_group" "Mytestcontainergroup" {
  name                = "testcontainergroup"
  location            = azurerm_resource_group.Core.location
  ip_address_type     = "Private"
  subnet_ids          = [for subnet in azurerm_virtual_network.spokevnet.subnet : subnet.id if subnet.name == "snet-aci"]
  os_type             = "Linux"
  resource_group_name = azurerm_resource_group.Core.name

  container {
    name   = "hello-world"
    image  = "nicolaka/netshoot:latest"
    cpu    = "0.5"
    memory = "0.5"

    ports {
      port     = 443
      protocol = "TCP"
    }

    commands = [
      "/bin/sh",
      "-c",
      "sleep infinity"
    ]
  }
}

resource "azurerm_network_interface" "testvmnic" {
  name                = "testvmnic"
  location            = azurerm_resource_group.Core.location
  resource_group_name = azurerm_resource_group.Core.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = one([for subnet in azurerm_virtual_network.spokevnet.subnet : subnet.id if subnet.name == "snet-workload"])
    private_ip_address_allocation = "Dynamic"
  }
}

#### Test VM on spoke workload network to test connectivity to hub and other networks. 
resource "azurerm_windows_virtual_machine" "testvm" {
  count                 = var.Lab_Shutdown ? 0 : 1
  resource_group_name   = azurerm_resource_group.Core.name
  location              = azurerm_resource_group.Core.location
  name                  = "testvm"
  network_interface_ids = [azurerm_network_interface.testvmnic.id]
  size                  = "Standard_B2ats_v2"
  admin_password        = "Butillaw7970-"
  admin_username        = "jamie"
  patch_mode            = "AutomaticByPlatform"


  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition-core"
    version   = "latest"
  }

}

resource "azurerm_virtual_machine_extension" "allow_icmp2" {
  count                = var.Lab_Shutdown ? 0 : 1
  name                 = "allow-icmp"
  virtual_machine_id   = azurerm_windows_virtual_machine.testvm[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -Command \"New-NetFirewallRule -DisplayName 'Allow ICMPv4 Echo' -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow\""
  })
}



resource "azurerm_network_interface" "testvmnichub" {
  name                = "testvmnichub"
  location            = azurerm_resource_group.Core.location
  resource_group_name = azurerm_resource_group.Core.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = one([for subnet in azurerm_virtual_network.hubvnet.subnet : subnet.id if subnet.name == "snet-shared-services"])
    private_ip_address_allocation = "Dynamic"
  }
}


#### Test VM on hub network to test connectivity from hub to spoke network 
resource "azurerm_windows_virtual_machine" "testvmhub" {
  count                 = var.Lab_Shutdown ? 0 : 1
  resource_group_name   = azurerm_resource_group.Core.name
  location              = azurerm_resource_group.Core.location
  name                  = "testvmhub"
  network_interface_ids = [azurerm_network_interface.testvmnichub.id]
  size                  = "Standard_B2ats_v2"
  admin_password        = "Butillaw7970-"
  admin_username        = "jamie"
  patch_mode            = "AutomaticByPlatform"

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition-core"
    version   = "latest"
  }
  dynamic "identity" {
    for_each = var.sptype == "managed" ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [module.azuread_service_principal.serviceprincipalinfo.Managed_SP_ResoureID]
    }
  }
}

resource "azurerm_virtual_machine_extension" "allow_icmp" {
  count                = var.Lab_Shutdown ? 0 : 1
  name                 = "allow-icmp"
  virtual_machine_id   = azurerm_windows_virtual_machine.testvmhub[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Bypass -Command \"New-NetFirewallRule -DisplayName 'Allow ICMPv4 Echo' -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow\""
  })
}

resource "azurerm_network_security_group" "allowping" {
  location            = azurerm_resource_group.Core.location
  name                = "testgroup"
  resource_group_name = azurerm_resource_group.Core.name
  security_rule = [
    {
      access                                     = "Allow"
      description                                = null
      destination_address_prefix                 = "*"
      destination_address_prefixes               = []
      destination_application_security_group_ids = []
      destination_port_range                     = "*"
      destination_port_ranges                    = []
      direction                                  = "Inbound"
      name                                       = "allowping"
      priority                                   = 100
      protocol                                   = "Icmp"
      source_address_prefix                      = "*"
      source_address_prefixes                    = []
      source_application_security_group_ids      = []
      source_port_range                          = "*"
      source_port_ranges                         = []
    }
  ]
}


resource "azurerm_public_ip" "res-14" {
  allocation_method   = "Static"
  location            = "southafricanorth"
  name                = "Hub_VNG"
  resource_group_name = azurerm_resource_group.Core.name
  zones               = ["1", "2", "3"]
}
resource "azurerm_virtual_network_gateway" "res-15" {
  count               = var.Lab_Shutdown ? 0 : 1
  location            = "southafricanorth"
  name                = "Hub_VNG"
  resource_group_name = azurerm_resource_group.Core.name
  sku                 = "Basic"
  type                = "Vpn"
  ip_configuration {
    name                 = "default"
    public_ip_address_id = azurerm_public_ip.res-14.id
    subnet_id            = one([for subnet in azurerm_virtual_network.hubvnet.subnet : subnet.id if subnet.name == "GatewaySubnet"])
  }
}


resource "azurerm_virtual_network_gateway_connection" "res-6" {
  count                      = var.Lab_Shutdown ? 0 : 1
  connection_mode            = "ResponderOnly"
  dpd_timeout_seconds        = 45
  local_network_gateway_id   = azurerm_local_network_gateway.res-7.id
  location                   = "southafricanorth"
  name                       = "hub-to-home"
  resource_group_name        = azurerm_resource_group.Core.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.res-15[0].id
  shared_key                 = var.ipsecpsk

}
resource "azurerm_local_network_gateway" "res-7" {
  address_space       = ["192.168.50.0/24"]
  gateway_address     = "92.40.173.220"
  location            = "southafricanorth"
  name                = "homegateway"
  resource_group_name = azurerm_resource_group.Core.name

}

resource "azurerm_private_dns_zone" "myprivate" {
  resource_group_name = azurerm_resource_group.Core.name
  name                = "privatelink.vaultcore.azure.net"

}


resource "azurerm_private_dns_resolver" "privatednsresolver" {
  resource_group_name = azurerm_resource_group.Core.name
  name                = "private-resolver"
  virtual_network_id  = azurerm_virtual_network.hubvnet.id
  location            = azurerm_resource_group.Core.location
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "inbound" {
  location                = azurerm_resource_group.Core.location
  name                    = "dns-resolver"
  private_dns_resolver_id = azurerm_private_dns_resolver.privatednsresolver.id
  ip_configurations {
    subnet_id = one([for subnet in azurerm_virtual_network.hubvnet.subnet : subnet.id if subnet.name == "snet-dns-resolver"])
  }
}

resource "azurerm_private_endpoint" "res-0" {
  custom_network_interface_name = "KeyVaultPrivateEndpoint-nic"
  location                      = azurerm_resource_group.Core.location
  name                          = "KeyVaultPrivateEndpoint"
  resource_group_name           = azurerm_resource_group.Core.name
  subnet_id                     = "/subscriptions/9fc3b8bd-ef76-4f72-92eb-42ed00880f87/resourceGroups/core-rg/providers/Microsoft.Network/virtualNetworks/hubvnet/subnets/snet-shared-services"
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = ["/subscriptions/9fc3b8bd-ef76-4f72-92eb-42ed00880f87/resourceGroups/core-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
  }
  private_service_connection {
    is_manual_connection           = false
    name                           = "KeyVaultPrivateEndpoint"
    private_connection_resource_id = "/subscriptions/9fc3b8bd-ef76-4f72-92eb-42ed00880f87/resourceGroups/core-rg/providers/Microsoft.KeyVault/vaults/jamieskv-7a8"
    subresource_names              = ["vault"]
  }
}

resource "azurerm_network_interface" "res-0" {
  location            = azurerm_resource_group.Core.location
  name                = "KeyVaultPrivateEndpoint-nic"
  resource_group_name = azurerm_resource_group.Core.name
  ip_configuration {
    name                          = "privateEndpointIpConfig.82da9878-eea9-43cf-bcb2-b980815f1c13"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = one([for subnet in azurerm_virtual_network.hubvnet.subnet : subnet.id if subnet.name == "snet-shared-services"])
  }
}
module "keyvault" {
  source    = "./Modules/keyvault"
  location  = azurerm_resource_group.Core.location
  rgname    = azurerm_resource_group.Core.name
  tenant_id = var.tenant_id
  kvname    = "jamieskv"
}

module "azuread_service_principal" {
  source   = "./Modules/service-principal"
  rgname   = azurerm_resource_group.Core.name
  location = azurerm_resource_group.Core.location
  spname   = "mySP"
  sptype   = var.sptype

}

module "azurerm_role_assignment" {
  source               = "./Modules/role-assignment"
  principal_id         = var.sptype == "serviceprincipal" ? module.azuread_service_principal.serviceprincipalinfo.SP_ID : module.azuread_service_principal.serviceprincipalinfo.Managed_SP_ID
  role_definition_name = var.role_definition_name
  scope                = module.keyvault.keyvaultid

}

output "all_module_outputs" {
  value = {
    role_assignment   = module.azurerm_role_assignment
    keyvault          = module.keyvault
    service-principal = module.azuread_service_principal
  }

}
