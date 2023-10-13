terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# commenting out until confirmation on dynamodb table usage
# data "terraform_remote_state" "config" {
#   backend = "s3"
#   config = {
#     region = "us-east-1"
#     bucket = "aip-az-foundation"
#     key    = "requirements/terraform.tfstate"
#     dynamodb_table = "aip-az-foundation-lock"
#   }
# }

######################
# Variables
######################

locals {
  owner_data = tolist(var.owners) 

  # Conditional logic for Azure management groups via json input
  management_group_id = var.data_classification == "Critical" ? "data-class-critical" : (
      var.data_classification == "Confidential" ? "data-class-confidential" : (
        var.data_classification == "University-Internal" ? "data-class-internal" : (
          var.data_classification == "Public" ? "data-class-public" : "available-to-reassign"
      )
    )
  )
}

# Obtainable by `az billing account list`
variable "billing_account_name" {
  description = "Billing account name that the Enrollment Account is under"
  type        = string
  sensitive   = true
}

# Obtainable by `az billing enrollment-account list`
variable "enrollment_account_name" {
  description = "Enrollment account name"
  type        = string
  sensitive   = true
}


######################
# Imported Resources
######################

#check on the relevance of this?
data "azurerm_billing_enrollment_account_scope" "aip" {
  billing_account_name    = var.billing_account_name
  enrollment_account_name = var.enrollment_account_name
}

data "azurerm_management_group" "mgmt_group" {
  name = var.ou_id != "" ? var.ou_id : local.management_group_id
}

data "azuread_users" "owner_group_members" {
  user_principal_names = tolist(concat(local.owner_data, ["aip-automation@tamu.edu"]))
}


######################
# Resources
######################


##
# Creates subscription resource 

resource "azurerm_subscription" "subscription" {
  subscription_name = var.account_name
  billing_scope_id  = data.azurerm_billing_enrollment_account_scope.aip.id 

  tags = {
    "Data Classification" = var.data_classification
    "FAMIS Account"       = var.famis_account
    "Description"         = var.resource_desc
  }
}

##
# Associates the subscription to a Management Group

resource "azurerm_management_group_subscription_association" "management" {
  management_group_id = data.azurerm_management_group.mgmt_group.id
  subscription_id     = "/subscriptions/${azurerm_subscription.subscription.subscription_id}"
}

##
# Creates the Azure AD Group of Owners

resource "azuread_group" "owner_group" {
  display_name = "aip-sg-az-sub-${var.account_name}-owners"
  owners  = concat(data.azuread_users.owner_group_members.object_ids, [var.aip_sp_cicd_az_onboarding_object_id])
  security_enabled = true
}


resource "azuread_group_member" "owner_group_members" {
  for_each = toset(data.azuread_users.owner_group_members.object_ids)

  group_object_id  = azuread_group.owner_group.id
  member_object_id = each.value
}

##
# Assigns the Azure AD owners group as the Owner of the subscription

resource "azurerm_role_assignment" "subscription_owner" {
  scope                = "/subscriptions/${azurerm_subscription.subscription.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = azuread_group.owner_group.object_id
}



######################
# Database
######################

#do we still want this in the run?
# resource "aws_dynamodb_table_item" "subscription_item" {
#   table_name = data.terraform_remote_state.config.outputs.data_table.id
#   hash_key   = data.terraform_remote_state.config.outputs.data_table.hash_key
#   range_key  = data.terraform_remote_state.config.outputs.data_table.range_key

#   item = <<ITEM
# {
#   "${data.terraform_remote_state.config.outputs.data_table.hash_key}": {"S": "SUBSCRIPTION#${azurerm_subscription.subscription.subscription_id}"},
#   "${data.terraform_remote_state.config.outputs.data_table.range_key}": {"S": "SUBSCRIPTION#${azurerm_subscription.subscription.subscription_id}"},
#   "name": {"S": "${local.account_name}"},
#   "subscription_id": {"S": "${azurerm_subscription.subscription.subscription_id}"},
#   "alias": {"S": "${azurerm_subscription.subscription.alias}"},
#   "description": { "S": "${var.resource_desc}" },
#   "owners": {
#     "L": [
#       {"S": "${local.owner_data}"}
#     ]
#   },
#   "business_unit": {"S": "${var.business_unit}"},
#   "famis_account": {"S": "${var.famis_account}"},
#   "data_classification": {"S": "${var.data_classification}"},
# }
# ITEM
# }
