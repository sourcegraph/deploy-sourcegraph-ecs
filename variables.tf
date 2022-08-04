# Terraform variables you can specify in terraform.tfvars

# Required variables
variable "cluster_name" {
  description = "Cluster name / prefix to apply to all Sourcegraph resources, e.g. 'sourcegraph-staging' or 'sourcegraph-prod'"
  type        = string
  default     = "sourcegraph-staging"
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
variable "availability_zones" {
  type        = list(string)
  description = "the name of availability zones to use"
  default     = ["us-east-1a", "us-east-1b"]
}

# Cluster tuning parameters
variable "instance_type" {
  description = "EC2 instance type to use for running ECS containers. e.g. m5a.2xlarge"
  type        = string
  default     = "m5a.2xlarge"
}
variable "autoscaling_max_instances" {
  description = "value"
  type        = number
  default     = 3
}
variable "autoscaling_min_instances" {
  description = "value"
  type        = number
  default     = 1
}
variable "indexed_search_instance_type" {
  description = "EC2 instance type to use for running indexed-search ECS containers. e.g. m5a.2xlarge"
  type        = string
  default     = "m5a.2xlarge"
}
variable "indexed_search_instances" {
  description = "value"
  type        = number
  default     = 3
}
variable "postgres_instance_type" {
  description = "RDS DB instance type to use for Postgres"
  type        = string
  default     = "db.m5.large"
}
variable "redis_instance_type" {
  description = "ElastiCache instance type to use for Rediss"
  type        = string
  default     = "cache.m4.large"
}

# Service tuning parameters
variable "frontend_cpu" {
  description = "frontend CPU allocation (1024 == one vCPU)"
  type        = number
  default     = 4096
}
variable "frontend_mem" {
  description = "frontend memory allocation (1024 == 1 GiB)"
  type        = number
  default     = 8192
}
variable "github_proxy_cpu" {
  description = "github-proxy CPU allocation (1024 == one vCPU)"
  type        = number
  default     = 1024
}
variable "github_proxy_mem" {
  description = "github-proxy memory allocation (1024 == 1 GiB)"
  type        = number
  default     = 1024
}
variable "search_indexer_cpu" {
  description = "search-indexer CPU allocation (1024 == one vCPU)"
  type        = number
  default     = 6144
}
variable "search_indexer_mem" {
  description = "search-indexer memory allocation (1024 == 1 GiB)"
  type        = number
  default     = 8192
}
variable "indexed_searcher_cpu" {
  description = "indexed-searcher CPU allocation (1024 == one vCPU)"
  type        = number
  default     = 2048
}
variable "indexed_searcher_mem" {
  description = "search-indexer memory allocation (1024 == 1 GiB)"
  type        = number
  default     = 4092
}
variable "syntax_highlighter_cpu" {
  description = "syntax-highlighter CPU allocation (1024 == one vCPU)"
  type        = number
  default     = 4096
}
variable "syntax_highlighter_mem" {
  description = "syntax-highlighter memory allocation (1024 == 1 GiB)"
  type        = number
  default     = 6144
}


# Optional configuration
variable "ssh_port" {
  type        = number
  description = "SSH port for all EC2 instances"
  default     = 22
}
variable "vpc_cidr" {
  default = "10.100.0.0/16"
}
variable "public_subnets" {
  type        = list(string)
  description = "the CIDR blocks to create public subnets"
  default     = ["10.100.10.0/24", "10.100.20.0/24"]
}
variable "private_subnets" {
  type        = list(string)
  description = "the CIDR blocks to create private subnets"
  default     = ["10.100.30.0/24", "10.100.40.0/24"]
}
