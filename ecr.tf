# ECR Repositories, i.e. where Sourcegraph Docker images will be stored
# (and scanned by ECR for security vulnerabilities.)

resource "aws_ecr_repository" "syntax_highlighter" {
  name                 = "sourcegraph-syntax-highlighter"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "search_indexer" {
  name                 = "sourcegraph-search-indexer"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "indexed_searcher" {
  name                 = "sourcegraph-indexed-searcher"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}
