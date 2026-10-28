# One-time setup, applied locally with your own AWS credentials: the state
# bucket for infra/ (and this stack) and the role that GitHub Actions assumes
# (through the account's existing GitHub OIDC provider) to apply infra/. The
# first apply runs on local state and then migrates it into the new bucket:
#   task infra:bootstrap

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bucket and region are passed by `task infra:bootstrap:init` (TF_STATE_BUCKET).
  backend "s3" {
    key          = "k8s-home/bootstrap.tfstate"
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

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to deploy."
  type        = string
  default     = "chrishrb/k8s-home"
}

variable "github_environment" {
  description = "GitHub environment whose jobs may assume the deploy role. Restrict it to main under the environment's deployment branches."
  type        = string
  default     = "production"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # infra/ names its buckets ${prefix}-backup-* and its users ${prefix}-*, so the deploy role can be scoped to them.
  prefix = "k8s-home"
}

# --- State bucket ---------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket = "${local.prefix}-tfstate-${local.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Old state versions are the way back from a broken apply.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }
  }
  depends_on = [aws_s3_bucket_versioning.state]
}

# --- GitHub Actions OIDC deploy role -----------------------------------------------

# One provider per URL and account: it already exists and belongs to solar0's
# infra/bootstrap, so it's only looked up here (importing it would give it two owners).
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Jobs that use an environment get this subject (not the branch ref).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${local.prefix}-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
}

# infra/ only manages the k8s-home-backup-* buckets, IAM users named k8s-home-*
# and its own state key, so the role is limited to those (the state bucket
# itself and the bootstrap state stay out of reach).
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "State"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid     = "StateObjects"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.state.arn}/k8s-home/infra.tfstate",
      "${aws_s3_bucket.state.arn}/k8s-home/infra.tfstate.tflock",
    ]
  }
  statement {
    sid     = "BackupBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.prefix}-backup-*",
      "arn:aws:s3:::${local.prefix}-backup-*/*",
    ]
  }
  # Users only with the backup boundary, so the role can't hand out more than
  # access to the backup buckets (no AttachUserPolicy, no boundary removal).
  statement {
    sid       = "UsersWithBoundary"
    actions   = ["iam:CreateUser", "iam:PutUserPolicy", "iam:PutUserPermissionsBoundary"]
    resources = ["arn:aws:iam::${local.account_id}:user/${local.prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.backup_boundary.arn]
    }
  }
  statement {
    sid = "Users"
    actions = [
      "iam:GetUser",
      "iam:DeleteUser",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:ListUserTags",
      "iam:GetUserPolicy",
      "iam:ListUserPolicies",
      "iam:DeleteUserPolicy",
      "iam:ListAttachedUserPolicies",
      "iam:ListGroupsForUser",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
    ]
    resources = ["arn:aws:iam::${local.account_id}:user/${local.prefix}-*"]
  }
  statement {
    sid       = "Identity"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

# Permissions boundary of every user infra/ creates: at most the backup buckets.
data "aws_iam_policy_document" "backup_boundary" {
  statement {
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.prefix}-backup-*",
      "arn:aws:s3:::${local.prefix}-backup-*/*",
    ]
  }
}

resource "aws_iam_policy" "backup_boundary" {
  name        = "${local.prefix}-backup-boundary"
  description = "Permissions boundary for the IAM users that infra/ creates"
  policy      = data.aws_iam_policy_document.backup_boundary.json
}

resource "aws_iam_role_policy" "deploy" {
  name   = "infra"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

output "state_bucket" {
  description = "Set as TF_STATE_BUCKET locally and as the TF_STATE_BUCKET variable in GitHub."
  value       = aws_s3_bucket.state.id
}

output "deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN variable in GitHub."
  value       = aws_iam_role.deploy.arn
}

output "backup_boundary_arn" {
  description = "Permissions boundary infra/ must set on its IAM users."
  value       = aws_iam_policy.backup_boundary.arn
}
