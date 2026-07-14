# ---------------------------------------------------------------------------
# Module: pim-entra-role
# ---------------------------------------------------------------------------

data "azuread_client_config" "current" {}

# Look up the directory role by display name so callers can use human-readable
# role names (e.g. "Application Administrator") instead of template_id GUIDs.
data "azuread_directory_role" "this" {
  display_name = var.entra_role_display_name
}

locals {
  # The Terraform SPN is always an owner so the group stays manageable via
  # automation. Callers may add further owners via var.group_owners.
  owners = distinct(concat(
    [data.azuread_client_config.current.object_id],
    var.group_owners,
  ))

  # Justification is automatically required whenever an approval workflow is
  # configured – if you have to wait for a human to approve, a reason is a
  # minimum expectation.
  require_justification = length(var.approvers) > 0
}

resource "time_rotating" "this" {
  rotation_years = var.eligibility_years
}

# assignable_to_role = true makes the group eligible for Entra directory role
# assignments. This requires Microsoft Entra ID P2 / Entra ID Governance.
resource "azuread_group" "this" {
  display_name       = var.group_display_name
  description        = var.group_description
  owners             = local.owners
  security_enabled   = true
  assignable_to_role = true
}

resource "azuread_group_role_management_policy" "this" {
  group_id = azuread_group.this.object_id
  role_id  = "member"

  activation_rules {
    maximum_duration      = var.maximum_activation_duration
    require_justification = local.require_justification
    require_approval      = var.require_approval

    dynamic "approval_stage" {
      for_each = var.require_approval ? [var.approvers] : []
      content {
        dynamic "primary_approver" {
          for_each = approval_stage.value
          content {
            type      = primary_approver.value.type
            object_id = primary_approver.value.object_id
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = !var.require_approval || length(var.approvers) > 0
      error_message = "At least one entry in var.approvers is required when require_approval = true."
    }
  }
}

resource "azuread_privileged_access_group_eligibility_schedule" "members" {
  for_each = { for m in var.members : m.object_id => m }

  group_id        = azuread_group_role_management_policy.this.group_id
  principal_id    = each.value.object_id
  assignment_type = "member"
  start_date      = time_rotating.this.id
  expiration_date = timeadd(time_rotating.this.id, "${var.eligibility_years * 365 * 24}h")
}

# The group receives the directory role permanently. Individual access is
# controlled by PIM eligibility (members activate group membership, which
# grants the role for the configured maximum_activation_duration).
resource "azuread_directory_role_assignment" "this" {
  role_id             = data.azuread_directory_role.this.template_id
  principal_object_id = azuread_group.this.object_id
}
