terraform {
  cloud {


    organization = "jshizzleterransible"

    workspaces {
      name = "dev"

    }
  }
}