terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.9.0"
    }

  github = {
      source  = "integrations/github"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "2.3.1"
    }

    local = {
      source  = "hashicorp/local"
      version = "1.4.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "2.1.2"
    }

    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "github" {}