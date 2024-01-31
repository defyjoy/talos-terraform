terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.4.1"
    }
  }

  backend "s3" {
    bucket         = "intree-sandbox-tfstate"
    key            = "talos/environments/sandbox/eu-west-1/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock-dynamo"
  }
}
