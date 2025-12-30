resource "google_artifact_registry_repository" "main" {
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = var.format

  cleanup_policy_dry_run = var.cleanup_policy_dry_run

  dynamic "cleanup_policies" {
    for_each = var.delete_untagged ? [1] : []
    content {
      id     = "delete-untagged"
      action = "DELETE"

      condition {
        tag_state = "UNTAGGED"
      }
    }
  }

  dynamic "cleanup_policies" {
    for_each = var.keep_recent_count > 0 ? [1] : []
    content {
      id     = "keep-recent"
      action = "KEEP"

      most_recent_versions {
        keep_count = var.keep_recent_count
      }
    }
  }
}