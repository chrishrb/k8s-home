# Off-site backups of the cluster (e.g. CloudNativePG's barman-cloud), one
# private bucket per consumer. Not force_destroy: the objects are the backups.

data "aws_caller_identity" "current" {}

locals {
  # Created by infra/bootstrap; built from the name so the deploy role needs no IAM read rights.
  backup_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/k8s-home-backup-boundary"
}

resource "aws_s3_bucket" "backup" {
  for_each = var.backup_buckets
  # The deploy role may only manage k8s-home-backup-* buckets (infra/bootstrap).
  bucket = "k8s-home-backup-${each.key}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "backup" {
  for_each                = aws_s3_bucket.backup
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backup" {
  for_each = aws_s3_bucket.backup
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  for_each = aws_s3_bucket.backup
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Retention is the backup tool's job; versioning only keeps what it (or a
# compromised cluster) deletes for backup_noncurrent_days.
resource "aws_s3_bucket_versioning" "backup" {
  for_each = aws_s3_bucket.backup
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  for_each = aws_s3_bucket.backup
  bucket   = each.value.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.backup_noncurrent_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.backup]
}

# The cluster isn't on AWS, so it gets a static access key, stored in
# Bitwarden Secrets Manager and pulled by an ExternalSecret.
resource "aws_iam_user" "backup" {
  name                 = "k8s-home-backup"
  permissions_boundary = local.backup_boundary_arn
}

data "aws_iam_policy_document" "backup" {
  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [for b in aws_s3_bucket.backup : b.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [for b in aws_s3_bucket.backup : "${b.arn}/*"]
  }
}

resource "aws_iam_user_policy" "backup" {
  name   = "backup-buckets"
  user   = aws_iam_user.backup.name
  policy = data.aws_iam_policy_document.backup.json
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}
