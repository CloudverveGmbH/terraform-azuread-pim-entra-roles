output "group_id" {
  description = "Object ID of the PIM-enabled, role-assignable security group."
  value       = azuread_group.this.object_id
}

output "principal_id" {
  description = "Alias for group_id."
  value       = azuread_group.this.object_id
}

output "directory_role_assignment_id" {
  description = "Resource ID of the Entra directory role assignment granted to the group."
  value       = azuread_directory_role_assignment.this.id
}
