# Sentry (EU region) for noonside: one project for the Go API and one for the
# React SPA, each with its DSN. The DSNs are not secret; they are chart values
# of the noonside HelmRelease (sentry.api.dsn, sentry.web.dsn).
#
# Moved here from chrishrb/solar0 (infra/modules/sentry, state
# solar0/prod.tfstate) with `tofu state mv`, see
# kubernetes/apps/noonside/k8s-migration.md. The organization, its DPA, the
# GitHub integration and the auth tokens are set up in the Sentry console. New
# projects get Sentry's default alert rule (email on new high-priority issues).

resource "sentry_team" "noonside" {
  organization = var.sentry_organization
  name         = "noonside"
}

resource "sentry_project" "noonside_api" {
  organization  = var.sentry_organization
  teams         = [sentry_team.noonside.slug]
  name          = "noonside-api"
  platform      = "go"
  default_key   = false
  default_rules = true
}

resource "sentry_project" "noonside_web" {
  organization  = var.sentry_organization
  teams         = [sentry_team.noonside.slug]
  name          = "noonside-web"
  platform      = "javascript-react"
  default_key   = false
  default_rules = true
}

# The key names are from the AWS setup; renaming them would not change the DSNs.
resource "sentry_key" "noonside_api" {
  organization = var.sentry_organization
  project      = sentry_project.noonside_api.slug
  name         = "lambda"
}

resource "sentry_key" "noonside_web" {
  organization = var.sentry_organization
  project      = sentry_project.noonside_web.slug
  name         = "spa"
}
