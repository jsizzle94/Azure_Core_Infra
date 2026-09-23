

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
}

resource "azurerm_virtual_network_peering" "spoketohub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.Core.name
  virtual_network_name      = azurerm_virtual_network.spokevnet.name
  remote_virtual_network_id = azurerm_virtual_network.hubvnet.id
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

}