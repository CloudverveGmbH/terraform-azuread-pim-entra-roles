# ---------------------------------------------------------------------------
# Module: pim-entra-role
# Purpose: Creates a two-group PIM setup (Eligible + Privileged) for Entra
#          directory roles (e.g. "Application Administrator").
#          Members of the Eligible group activate into the Privileged group via PIM;
#          the Privileged group holds the permanent directory role assignment.
#
# Prerequisites:
#   - Microsoft Entra ID P2 (or Entra ID Governance) licence in the tenant
#   - The Terraform principal needs "Privileged Role Administrator" or
#     "Global Administrator" to create role-assignable groups and assign roles
#
# Usage pattern:
#   module "app_admin_pim" {
#     source                  = "./modules/pim-entra-role"
#     entra_role_display_name = "Application Administrator"
#     members                 = [{ object_id = data.azuread_user.alice.object_id, display_name = "Alice" }]
#   }
#
#   # Override the group name (e.g. two groups for the same role, different teams):
#   module "app_admin_pim_teamb" {
#     source                  = "./modules/pim-entra-role"
#     entra_role_display_name = "Application Administrator"
#     override_group_display_name = "Application Admin Team B"
#   }
# ---------------------------------------------------------------------------

variable "override_group_display_name" {
  description = <<-EOT
    Optional override for the group base name. When omitted, the slug is derived
    from entra_role_display_name automatically.
    Two groups are always created: 'pim-<slug>-eligible' and 'pim-<slug>'.
  EOT
  type        = string
  default     = null

  validation {
    # When set, it must contain at least one alphanumeric character so the
    # derived slug is non-empty. null keeps the automatic role-name derivation.
    condition     = var.override_group_display_name == null || length(join("-", regexall("[a-z0-9]+", lower(coalesce(var.override_group_display_name, "x"))))) > 0
    error_message = "override_group_display_name, when set, must contain at least one alphanumeric character."
  }
}

variable "group_owners" {
  description = <<-EOT
    Additional owner object IDs for both groups (users or SPNs).
    The Terraform principal (data.azuread_client_config.current) is always
    added as an owner automatically so the groups remain manageable.
  EOT
  type        = list(string)
  default     = []
}

variable "members" {
  description = <<-EOT
    Entra ID objects to add as permanent members of the Eligible group via Terraform.
    Leave empty ([]) to manage group membership outside Terraform (recommended for
    large teams – avoids a terraform apply per joiner/leaver).
  EOT
  type = list(object({
    object_id    = string
    display_name = optional(string, "")
  }))
  default = []
}

variable "entra_role_display_name" {
  description = <<-EOT
    Display name of the Entra ID directory role to assign permanently to the Privileged group.
    Examples: "Application Administrator", "Cloud Application Administrator",
              "Privileged Role Administrator".
  EOT
  type        = string

  validation {
    condition     = length(trimspace(var.entra_role_display_name)) > 0
    error_message = "entra_role_display_name must not be empty."
  }
}

variable "approvers" {
  description = <<-EOT
    PIM approvers. When set, activations require both approval and a business justification.
    Leave empty ([]) to allow self-activation without approval.
    Each entry:
      object_id = "<uuid>"                        # user or group object_id
      type      = "singleUser" | "groupMembers"   # optional - auto-inferred from Entra if omitted
    Examples:
      approvers = [{ object_id = data.azuread_user.joscha.object_id }]
      approvers = [{ object_id = azuread_group.managers.object_id }]
      approvers = [{ object_id = "...", type = "groupMembers" }]
  EOT
  type = list(object({
    object_id = string
    type      = optional(string) # null = auto-infer from Entra directory object type
  }))
  default = []

  validation {
    condition = alltrue([
      for a in var.approvers : a.type == null || contains(["singleUser", "groupMembers"], a.type)
    ])
    error_message = "approvers[].type must be null (auto-infer), \"singleUser\", or \"groupMembers\"."
  }
}

variable "require_justification" {
  description = "Require a business justification on activation. Independent of approval."
  type        = bool
  default     = true
}

variable "maximum_activation_duration" {
  description = <<-EOT
    Maximum time a member may stay active after activation (ISO 8601 duration).
    Examples: "PT1H" (1 h), "PT4H" (4 h), "PT8H" (8 h).
    Entra recommends shorter windows for high-privilege directory roles.
  EOT
  type        = string
  default     = "PT4H"

  validation {
    condition     = can(regex("^P(T?)([0-9]+[HMD])+$|^PT[0-9]+[HMS]$", var.maximum_activation_duration))
    error_message = "maximum_activation_duration must be an ISO 8601 duration, e.g. \"PT1H\", \"PT4H\", or \"PT8H\"."
  }
}

variable "eligibility_years" {
  description = <<-EOT
    How many years the eligibility schedule remains valid.
    A time_rotating resource triggers re-application after this period so
    schedules are automatically renewed without manual intervention.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = var.eligibility_years >= 1
    error_message = "eligibility_years must be at least 1."
  }
}
