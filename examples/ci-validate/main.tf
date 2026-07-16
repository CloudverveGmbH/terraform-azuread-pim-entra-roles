# ---------------------------------------------------------------------------
# CI validation wrapper.
# Instantiates the module with minimal inputs so `terraform validate` can run
# in CI without a backend or real Azure credentials.
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
  }
}

provider "azuread" {}

module "pim_entra_role" {
  source = "../.."

  entra_role_display_name = "Security Reader"
}
