variable "region" {
  description = "AWS region of the backup buckets."
  type        = string
  default     = "eu-central-1"
}

variable "contabo_product_id" {
  description = "Contabo product ID of the node (6 vCPU / 12 GB). List them with `cntb get products` or the API docs."
  type        = string

  validation {
    condition     = var.contabo_product_id != ""
    error_message = "Set contabo_product_id in environments/prod.tfvars."
  }
}

variable "contabo_region" {
  description = "Contabo region (EU, US-central, US-east, US-west, SIN)."
  type        = string
  default     = "EU"
}

variable "contabo_period" {
  description = "Contract period in months (1, 3, 6 or 12)."
  type        = number
  default     = 1
}

variable "backup_buckets" {
  description = "Backup buckets, one per consumer (e.g. noonside for noonside-pg's barman-cloud backups)."
  type        = set(string)
  default     = ["noonside"]
}

variable "backup_noncurrent_days" {
  description = "Days that overwritten or deleted backup objects are kept, in case a backup tool deletes too much."
  type        = number
  default     = 30
}
