# ---------------------------------------------------------------------------
# Module: pim-entra-role
# ---------------------------------------------------------------------------

data "azuread_client_config" "current" {}

# Look up the directory role by display name so callers use human-readable
# names (e.g. "Application Administrator") instead of template_id GUIDs.
data "azuread_directory_role" "this" {
  display_name = var.entra_role_display_name
}

# Look up directory object type for approvers that have no explicit type set.
data "azuread_directory_object" "approvers" {
  for_each  = { for a in var.approvers : a.object_id => a if a.type == null }
  object_id = each.key
}

locals {
  # The Terraform SPN is always an owner so both groups remain manageable
  # via automation. Callers may add further owners via var.group_owners.
  owners = distinct(concat(
    [data.azuread_client_config.current.object_id],
    var.group_owners,
  ))

  # Slug derived from group_display_name – same pattern as pim-azure-role.
  # Example: "Application Admin" → "application-admin"
  # Resulting groups: "pim-application-admin" (privileged) + "pim-application-admin-eligible"
  group_slug = join("-", regexall("[a-z0-9]+", lower(var.group_display_name)))

  # Approval is derived from whether any approvers are configured.
  require_approval = length(var.approvers) > 0

  # Resolve approver type: explicit value wins; when null, infer from the Entra
  # directory object type. "Group" (any casing) → "groupMembers"; else → "singleUser".
  resolved_approvers = [
    for a in var.approvers : {
      object_id = a.object_id
      type = a.type != null ? a.type : (
        endswith(lower(try(data.azuread_directory_object.approvers[a.object_id].type, "")), "group")
        ? "groupMembers"
        : "singleUser"
      )
    }
  ]
}

resource "time_rotating" "this" {
  rotation_years = var.eligibility_years
}

# ---------------------------------------------------------------------------
# Eligible group
# Members of this group can activate (PIM) into the privileged group.
# Note: must NOT have assignable_to_role = true – only the privileged group holds the role.
# ---------------------------------------------------------------------------
resource "azuread_group" "eligible" {
  display_name            = "pim-${local.group_slug}-eligible"
  description             = "Members eligible to activate 'pim-${local.group_slug}' via PIM."
  owners                  = local.owners
  security_enabled        = true
  prevent_duplicate_names = true
}

# Optional: seed initial members via Terraform.
# Leave var.members = [] to manage group membership outside Terraform.
resource "azuread_group_member" "eligible" {
  for_each = {
    for m in var.members :
    (m.display_name != "" ? m.display_name : m.object_id) => m
  }

  group_object_id  = azuread_group.eligible.object_id
  member_object_id = each.value.object_id
}

# ---------------------------------------------------------------------------
# Privileged group (role-assignable)
# Holds the Entra directory role assignment. Membership via PIM activation only.
# assignable_to_role = true requires Entra ID P2 / Entra ID Governance.
# ---------------------------------------------------------------------------
resource "azuread_group" "privileged" {
  display_name            = "pim-${local.group_slug}"
  description             = "Active role holders for 'pim-${local.group_slug}'. Membership via PIM activation only."
  owners                  = local.owners
  security_enabled        = true
  assignable_to_role      = true
  prevent_duplicate_names = true
}

# PIM activation policy on the privileged group.
resource "azuread_group_role_management_policy" "this" {
  group_id = azuread_group.privileged.object_id
  role_id  = "member"

  activation_rules {
    maximum_duration      = var.maximum_activation_duration
    require_justification = true
    require_approval      = local.require_approval

    dynamic "approval_stage" {
      for_each = local.require_approval ? [local.resolved_approvers] : []
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

  eligible_assignment_rules {
    # Expiration is controlled by time_rotating below – no policy-level enforcement needed.
    expiration_required = false
  }
}

# Single schedule: the entire eligible group is the PIM principal.
resource "azuread_privileged_access_group_eligibility_schedule" "this" {
  group_id        = azuread_group_role_management_policy.this.group_id
  principal_id    = azuread_group.eligible.object_id
  assignment_type = "member"
  start_date      = time_rotating.this.id
  expiration_date = timeadd(time_rotating.this.id, "${var.eligibility_years * 365 * 24}h")
}

# The privileged group holds the directory role permanently.
# Individual access is controlled by PIM eligibility above.
resource "azuread_directory_role_assignment" "this" {
  role_id             = data.azuread_directory_role.this.template_id
  principal_object_id = azuread_group.privileged.object_id
}
