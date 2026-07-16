# ---------------------------------------------------------------------------
# Native test suite for pim-entra-role.
# All providers are mocked so tests run with no Azure credentials.
# Assertions target input-derived outputs (group names, approver types)
# that are deterministic at plan time.
# ---------------------------------------------------------------------------

mock_provider "azuread" {
  # object_id feeds the group owners list, which the provider validates as a UUID.
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "time" {}

# With no group_display_name, the slug is derived from the role name.
run "group_names_derived_from_role_name" {
  command = plan

  variables {
    entra_role_display_name = "Application Administrator"
  }

  assert {
    condition     = output.eligible_group_name == "pim-application-administrator-eligible"
    error_message = "Eligible group name not derived correctly from entra_role_display_name."
  }

  assert {
    condition     = output.privileged_group_name == "pim-application-administrator"
    error_message = "Privileged group name not derived correctly from entra_role_display_name."
  }
}

# group_display_name overrides the role-name-based slug.
run "group_display_name_overrides_role_name" {
  command = plan

  variables {
    entra_role_display_name = "Application Administrator"
    group_display_name      = "Application Admin Team B"
  }

  assert {
    condition     = output.privileged_group_name == "pim-application-admin-team-b"
    error_message = "group_display_name should override the role-name-derived slug."
  }
}

# Explicit approver type must be preserved (no auto-inference).
run "explicit_approver_type_is_preserved" {
  command = plan

  variables {
    entra_role_display_name = "Privileged Role Administrator"
    approvers = [
      { object_id = "11111111-1111-1111-1111-111111111111", type = "singleUser" },
    ]
  }

  assert {
    condition     = one(output.resolved_approvers).type == "singleUser"
    error_message = "Explicit approver type should be kept unchanged."
  }
}

# Empty approvers → resolved_approvers is empty.
run "no_approvers_yields_empty_resolved_list" {
  command = plan

  variables {
    entra_role_display_name = "Security Reader"
  }

  assert {
    condition     = length(output.resolved_approvers) == 0
    error_message = "Expected no resolved approvers when approvers is empty."
  }
}

# Members are keyed by display_name for readable state addresses.
run "members_keyed_by_display_name" {
  command = plan

  variables {
    entra_role_display_name = "Security Reader"
    members = [
      { object_id = "22222222-2222-2222-2222-222222222222", display_name = "Bob" },
    ]
  }

  assert {
    condition     = contains(keys(azuread_group_member.eligible), "Bob")
    error_message = "Members should be keyed by display_name when provided."
  }
}
