terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }

  # Backend is configured via CLI flags in the GitHub Actions workflow
  # (no backend block needed here)
}

provider "azurerm" {
  features {}
}