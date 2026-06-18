terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      configuration_aliases = [
        aws.requester,
        aws.accepter
      ]
    }
  }
}

provider "aws" {
  alias = "requester"
}

provider "aws" {
  alias = "accepter"
}