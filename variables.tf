# ---------------------------------------------------------------------------
# Module: pim-entra-role
# Purpose: Creates a PIM-enabled, role-assignable Entra ID security group
#          and assigns it a directory role (e.g. "Application Administrator").
#          Members activate group membership via PIM; the group holds the
#          permanent Entra directory role assignment.
#
# Prerequisites:
#   - Microsoft Entra ID P2 (or Entra ID Governance) licence in the tenant
#   - The Terraform principal needs "Privileged Role Administrator" or
#     "Global Administrator" to create role-assignable groups and assign roles
#
# Usage pattern:
#   module "app_admin_pim" {
#     source                  = "./modules/pim-entra-role"
#     group_display_name      = "Application Admin PIM"
#     entra_role_display_name = "Application Administrator"
#     members                 = [{ object_id = data.azuread_user.alice.object_id }]
#   }
# ---------------------------------------------------------------------------

variable "group_display_name" {
  description = "Display name for the role-assignable Entra ID security group."
  type        = string
}

variable "group_description" {
  description = "Optional description for the security group."
  type        = string
  default     = ""
}

variable "group_owners" {
  description = <<-EOT
    Additional owner object IDs for the group (users or SPNs).
    The Terraform principal (data.azuread_client_config.current) is always
    added as an owner automatically so the group remains manageable.
  EOT
  type        = list(string)
  default     = []
}

variable "members" {
  description = "Entra ID objects that become PIM-eligible members of the group."
  type = list(object({
    object_id    = string
    display_name = optional(string, "")
  }))
}

variable "entra_role_display_name" {
  description = <<-EOT
    Display name of the Entra ID directory role to assign permanently to the group.
    The group's members can then activate it via PIM.
    Examples: "Application Administrator", "Cloud Application Administrator",
              "Privileged Role Administrator".
  EOT
  type        = string
}

variable "require_approval" {
  description = "Whether activating the role requires explicit approval from an approver."
  type        = bool
  default     = false
}

variable "maximum_activation_duration" {
  description = <<-EOT
    Maximum time a member may stay active after activation (ISO 8601 duration).
    Examples: "PT1H" (1 h), "PT4H" (4 h), "PT8H" (8 h).
    Entra recommends shorter windows for high-privilege directory roles.
  EOT
  type        = string
  default     = "PT4H"
}

variable "approvers" {
  description = <<-EOT
    PIM approvers, required when require_approval = true.
    Each entry: { object_id = "<uuid>", type = "singleUser" | "groupMembers" }
    type defaults to "singleUser".
  EOT
  type = list(object({
    object_id = string
    type      = optional(string, "singleUser")
  }))
  default = []
}

variable "eligibility_years" {
  description = <<-EOT
    How many years each eligibility schedule remains valid.
    A time_rotating resource triggers re-application after this period so
    schedules are automatically renewed without manual intervention.
  EOT
  type    = number
  default = 1
}
