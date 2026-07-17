# Changelog

All notable changes to this module are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-17
### Changed
- optional attribute `group_display_name` now called `override_group_display_name` to better indicate, that a default is taken from the entra role naming. ([#1](https://github.com/CloudverveGmbH/terraform-azuread-pim-entra-roles/pull/1))


## [0.1.0] - 2026-07-16

### Added

- Two-group PIM pattern (Eligible + Privileged) for Entra directory roles.
- Automatic group naming from `entra_role_display_name`, with optional `group_display_name` override.
- Role-assignable Privileged group holding the directory role (`assignable_to_role = true`).
- Approver type auto-inference (singleUser / groupMembers) from the Entra directory object.
- Auto-renewing eligibility schedule via `time_rotating`.
- Explicit `require_justification` toggle (default `true`).
- Input validation for durations, eligibility years, approver types, and group names.
- `versions.tf` pinning Terraform `>= 1.9`, azuread `>= 3.0`, time `>= 0.10`.
- Native `terraform test` suite with mocked providers.
- Outputs: `eligible_group_name`, `privileged_group_name`, `directory_role_assignment_id`, `resolved_approvers`.
