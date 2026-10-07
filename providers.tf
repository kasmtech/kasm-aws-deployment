terraform {
  required_version = "~> 1.11"
  backend "s3" {
    bucket  = var.backend_bucket
    key     = "aws/${local.standard_customer_name}/terraform.tfstate"
    region  = var.backend_bucket_region
    profile = var.aws_profile
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

locals {
  all_aws_regions = toset([
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "eu-central-1",   # Frankfurt
    "eu-north-1",     # Stockholm
    "eu-west-2",      # London
    "eu-west-3",      # Paris
    "ap-northeast-1", # Tokyo
    "ap-northeast-2", # Seoul
    "ap-east-2",      # Taipai Taiwan
    "ap-southeast-1", # Signapore
    "ap-southeast-3", # Indonesia
    "me-central-1",   # UAE
    "mx-central-1",   # Mexico
    "sa-east-1",      # Brazil
    "il-central-1"
  ])
}
provider "aws" {
  for_each = local.all_aws_regions

  alias   = "regions"
  profile = var.aws_profile
  region  = each.key

  ## Uncomment if you want to use access keys instead of SSO
  #access_key = var.aws_access_key
  #secret_key = var.aws_secret_key

  default_tags {
    tags = local.aws_default_tags
  }
}

provider "aws" {
  alias   = "dns"
  profile = var.dns_aws_profile
  region  = var.dns_aws_region

  ## Uncomment if you want to use access keys instead of SSO
  #access_key = var.aws_access_key
  #secret_key = var.aws_secret_key

  default_tags {
    tags = local.aws_default_tags
  }
}
