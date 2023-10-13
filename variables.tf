# passed from subscription.tf

variable "aip_sp_cicd_az_onboarding_object_id" { type = string }


variable "resource_name" { type = string }
variable "resource_desc" { type = string }
variable "owners" { type = list(string) }
variable "business_unit" { type = string }
variable "famis_account" { type = string }
variable "expenditure" { type = string }
variable "data_classification" { type = string }
variable "account_name" { type = string }
variable "ou_id" { type = string }
