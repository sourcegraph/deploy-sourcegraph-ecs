# 🚨 Deprecation Notice 🚨

This repository is no longer a supported Sourcegraph deployment method.
If you'd like to deploy Sourcegraph, please see our [Deployment Documentation](https://sourcegraph.com/docs/admin/deploy) to learn about our supported deployment methods.

---

# Warning: reference repository

We suggest you deploy Sourcegraph using [Amazon EKS and Helm](https://docs.sourcegraph.com/admin/deploy/kubernetes/helm) or [Docker Compose](https://docs.sourcegraph.com/admin/deploy/docker-compose) as these are the most well-supported deployment methods.

This repository is a work-in-progress, and intended to be a reference for deploying Sourcegraph on the ECS container platform.

## Warning: Incomplete!

This repository is very incomplete and we have not been able to successfully deploy Sourcegraph on ECS/Fargate on our side yet; we strongly advise deploying Sourcegraph using a different method.

# Deploy Sourcegraph using Amazon ECS

This deploys Sourcegraph on [Amazon ECS (using EC2 launch types)](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/application_architecture.html). We provide:

- ECS Task definitions
- Terraform infrastructure-as-code which you can use to deploy the Task definitions to ECS

### Note: Sourcegraph requires EC2 launch type

Sourcegraph services **cannot be deployed using the Fargate ECS launch type**. The reason for this is that Fargate only supports EFS volumes, not EBS volumes, and Sourcegraph requires local SSD performance for its search indexes. Additionally, Sourcegraph's search backend and repository indexing process opens more files than is allowed by EFS generally.

The EC2 launch type / EBS volumes are highly advised for all Sourcegraph services.

## Overview of this repository

- `iam.tf` IAM role definitions
- `network.tf` ECS cluster & VPC definitions
- `variables.tf` Variables you can specify in `terraform.tfvars`
- `provider.tf` Terraform boilerplate
- `.tool-versions` ASDF tool versions (optional)
- `svc-foobar.tf` Sourcegraph service definitions

## Installation

### Prerequisites

- You must have `aws` CLI [installed and configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- You must have `terraform` installed.

### Configure Terraform access to EC2

- Fork this repository, so you can commit your changes/modifications and manage them in Git.
- Create a `terraform.tfvars` file, replacing the values with your keys and region (which you got when configuring the `aws` CLI above):

```terraform
prefix         = "sourcegraph-staging"
aws_access_key = "aws-access-key"
aws_secret_key = "aws-secret-key"
aws_region     = "us-west-1"
```

Note: There are more secure ways to store your Terraform secrets, please consult [the Terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#provider-configuration) and your security team for best practices.

### Initialize Terraform

```sh
terraform init
```

Note: This may produce a `terraform.tfstate` file, which is how Terraform keeps track of your infrastructure state. It's important you do not lose this file. See [the Terraform state documentation](https://www.terraform.io/language/state) and [Terraform Cloud](https://www.terraform.io/cloud-docs) for some options on storing this file safely in the cloud. You may also choose to [store this information in S3](https://www.terraform.io/language/settings/backends/s3) by modifying `provider.tf`.
