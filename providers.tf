terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    virtual_machine_scale_set {
      roll_instances_when_required = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}