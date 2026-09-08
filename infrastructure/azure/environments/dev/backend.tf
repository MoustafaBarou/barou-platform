terraform {
  backend "azurerm" {
    storage_account_name = "stbaroutf2ad92dcc"
    container_name       = "tfstate"
    key                  = "azure-secure-delivery-platform/dev.tfstate"
    use_azuread_auth     = true
  }
}
