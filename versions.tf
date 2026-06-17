terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  # Modules never declare a backend block.

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.44"
    }
  }
}
