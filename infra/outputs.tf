output "node_ipv4" {
  description = "Public IPv4 of the node: use it in talconfig.yaml, the Talos patches and the LB IP pools."
  value       = contabo_instance.kmaster1.ip_config[0].v4[0].ip
}

output "backup_buckets" {
  description = "Backup bucket name per consumer."
  value       = { for k, b in aws_s3_bucket.backup : k => b.id }
}

output "backup_s3_endpoint" {
  description = "S3 endpoint for the backup tools."
  value       = "https://s3.${var.region}.amazonaws.com"
}

output "backup_access_key_id" {
  description = "Access key of the backup user: store it in Bitwarden with the secret."
  value       = aws_iam_access_key.backup.id
}

output "backup_secret_access_key" {
  description = "Read with `tofu -chdir=infra output -raw backup_secret_access_key`."
  value       = aws_iam_access_key.backup.secret
  sensitive   = true
}

# The provider marks the whole dsn map sensitive (it includes the deprecated
# secret DSN); the public DSN is not secret.
output "sentry_dsn_api" {
  description = "noonside HelmRelease value sentry.api.dsn."
  value       = nonsensitive(sentry_key.noonside_api.dsn["public"])
}

output "sentry_dsn_web" {
  description = "noonside HelmRelease value sentry.web.dsn."
  value       = nonsensitive(sentry_key.noonside_web.dsn["public"])
}
