
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59, < 7.0"
    }
  }
  backend "s3" {
    bucket         = "livitec-orion-tfstate"
    key            = "tf.tfstate"
    region         = "us-east-2"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-2"
}