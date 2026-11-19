variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "endpoints" {
  type = map(object({
    resource_id       = string
    subresource_names = list(string)
    dns_zone_ids      = list(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "azurerm_private_endpoint" "this" {
  for_each            = var.endpoints
  name                = "pe-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = each.value.subresource_names
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = each.value.dns_zone_ids
  }
}

output "ids" {
  value = { for key, endpoint in azurerm_private_endpoint.this : key => endpoint.id }
}
