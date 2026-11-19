variable "assignments" {
  type = map(object({
    scope                = string
    role_definition_name = string
    principal_id         = string
  }))
}

resource "azurerm_role_assignment" "this" {
  for_each = var.assignments

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}
