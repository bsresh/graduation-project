variable "cloud_id" {
  type    = string
}

variable "folder_id" {
  description = "ID of the folder where resources will be created"
  type    = string
}

variable "iam_token" {
  type      = string
  sensitive = true
}

variable "domain" {
  type      = string
}