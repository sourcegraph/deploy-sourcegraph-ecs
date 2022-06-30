# Terraform variables you can specify in terraform.tfvars

variable "prefix" {
  description = "A prefix string to apply to all resources, e.g. 'sourcegraph-staging' or 'sourcegraph-prod'"
  type        = string
}
variable "aws_access_key" {
  description = "AWS access key"
  type        = string
}
variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
}
variable "aws_region" {
  description = "AWS region, e.g. us-east-1"
  type        = string
}
