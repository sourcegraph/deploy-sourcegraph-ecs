#!/usr/bin/env bash
set -exuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"/..

version="3.41.0"

export aws_account=$(aws sts get-caller-identity | jq -r ".Account")
export aws_region=$(aws configure get default.region)

declare -a images=(
    "cadvisor"
    "codeinsights-db"
    "codeintel-db"
    "frontend"
    "github-proxy"
    "gitserver"
    "grafana"
    "indexed-searcher"
    "jaeger-all-in-one"
    "migrator"
    "minio"
    "postgres-12-alpine"
    "precise-code-intel-worker"
    "prometheus"
    "redis-cache"
    "redis-store"
    "repo-updater"
    "search-indexer"
    "searcher"
    "symbols"
    "syntax-highlighter"
    "worker"
)

for i in "${images[@]}"
do
    docker pull "sourcegraph/$i:$version"
    docker tag "sourcegraph/$i:$version" "$aws_account.dkr.ecr.$aws_region.amazonaws.com/sourcegraph-$i:$version"
done

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$aws_account.dkr.ecr.$aws_region.amazonaws.com"

for i in "${images[@]}"
do
    docker push "$aws_account.dkr.ecr.$aws_region.amazonaws.com/sourcegraph-$i:$version"
done
