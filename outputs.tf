######################
# Outputs
######################

output "subscription_id" {
  value = azurerm_subscription.subscription.subscription_id
}

output "owner_group_name" {
  value = azuread_group.owner_group.display_name
}

output "role_name" {
  value = azurerm_role_assignment.subscription_owner.role_definition_name
}

output "owner_group_object_id" {
  value = azuread_group.owner_group.object_id
}