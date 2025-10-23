terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archieve = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.region
}

# global context
locals {
  project_name = var.project_name
  bucket_name  = "${var.project_name}-rag-doc"
  namespace    = "default"
  embed_model  =
  chat_model   =
}

# aws account/region data
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}