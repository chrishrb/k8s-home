terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    contabo = {
      source  = "contabo/contabo"
      version = "~> 0.1.44"
    }
    sentry = {
      source  = "jianyuan/sentry"
      version = "~> 0.15"
    }
  }

  # State bucket from infra/bootstrap (bucket and region passed by `task infra:init`).
  backend "s3" {
    key          = "k8s-home/infra.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "k8s-home" }
  }
}

# Reads CNTB_OAUTH2_CLIENT_ID, CNTB_OAUTH2_CLIENT_SECRET, CNTB_OAUTH2_USER and
# CNTB_OAUTH2_PASS from the environment.
provider "contabo" {}

# EU region. Reads SENTRY_AUTH_TOKEN from the environment.
provider "sentry" {
  base_url = "https://de.sentry.io/api/"
}
