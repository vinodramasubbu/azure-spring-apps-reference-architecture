
data "azurerm_client_config" "current" {}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_private_dns_zone" "keyvault_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.hub_sc_corp_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv-hub-link" {
  name                  = "keyvault-zone-hub-link"
  resource_group_name   = azurerm_resource_group.hub_sc_corp_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault_zone.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv-spoke-link" {
  name                  = "keyvault-zone-spoke-link"
  resource_group_name   = azurerm_resource_group.hub_sc_corp_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault_zone.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

# NSG for keyvault subnet

resource "azurerm_network_security_group" "support_svc_nsg" { 
    name                        = "support-service-nsg"
    location                    = var.location
    resource_group_name         = azurerm_resource_group.spoke_sc_corp_rg.name
}

resource "azurerm_subnet_network_security_group_association" "support_svc_nsg_assoc" {
  subnet_id                 = azurerm_subnet.azuresbcloudsupport.id
  network_security_group_id = azurerm_network_security_group.support_svc_nsg.id
}

resource "azurerm_key_vault" "sc_vault" {
  name                = "${var.keyvault_prefix}-${random_string.random.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke_sc_corp_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules = [
      "${chomp(data.http.myip.body)}/32"
  ]
 
  }
 access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Backup",
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "Recover",
      "Restore",
      "SetIssuers",
      "Update"
    ]

    key_permissions = [
      "List",
      "Encrypt",
      "Decrypt",
      "WrapKey",
      "UnwrapKey",
      "Sign",
      "Verify",
      "Get",
      "Create",
      "Update",
      "Import",
      "Backup",
      "Restore",
      "Recover",
      "Delete",
      "Purge"
    ]

    secret_permissions = [
      "List",
      "Get",
      "Set",
      "Backup",
      "Restore",
      "Recover",
      "Purge",
      "Delete"
    ]

    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update"
    ]
  }

}


resource "azurerm_private_endpoint" "keyvault-endpoint" {
  name                = "sc-keyvault-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke_sc_corp_rg.name
  subnet_id           = azurerm_subnet.azuresbcloudsupport.id

  private_service_connection {
    name                           = "kv-private-link-connection"
    private_connection_resource_id = azurerm_key_vault.sc_vault.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                          = azurerm_private_dns_zone.keyvault_zone.name
    private_dns_zone_ids          = [ azurerm_private_dns_zone.keyvault_zone.id ]
  }

  depends_on = [
    azurerm_subnet.azuresbcloudsupport,
    azurerm_subnet_network_security_group_association.support_svc_nsg_assoc
  ]

}


