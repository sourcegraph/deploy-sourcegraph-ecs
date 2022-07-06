#!/usr/bin/env bash
set -exuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"/..

export aws_account=$(aws sts get-caller-identity | jq -r ".Account")
export aws_region=$(aws configure get default.region)

docker pull sourcegraph/syntax-highlighter:3.41.0
docker tag sourcegraph/syntax-highlighter:3.41.0 "$aws_account.dkr.ecr.$aws_region.amazonaws.com/sourcegraph-syntax-highlighter:3.41.0"

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$aws_account.dkr.ecr.$aws_region.amazonaws.com"

docker push "$aws_account.dkr.ecr.$aws_region.amazonaws.com/sourcegraph-syntax-highlighter:3.41.0"
