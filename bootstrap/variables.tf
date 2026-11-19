variable "location" {
  description = "Region in which to create the Terraform state resources."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Name of the state resource group."
  type        = string
  default     = "rg-ramcollins-tfstate"
}

variable "storage_account_name" {
  description = "Globally unique, lowercase storage account name (3-24 alphanumeric characters)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3 to 24 lowercase letters or digits."
  }
}

variable "container_name" {
  description = "Private Blob container used for Terraform states."
  type        = string
  default     = "tfstate"
}

variable "allowed_ip_addresses" {
  description = "Optional public IPv4 addresses/CIDRs permitted to reach the state account."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
