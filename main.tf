resource "google_clouddeploy_delivery_pipeline" "primary_pipeline" {
  name        = var.delivery_pipeline_name
  location    = var.location
  project     = var.project_id
  description = var.description
  labels      = length(keys(var.labels)) < 0 ? null : var.labels
  annotations = length(keys(var.annotations)) < 0 ? null : var.annotations

  dynamic "serial_pipeline" {
    for_each = var.enable_serial_pipeline ? [{}] : []
    content {
      stages {
        profiles  = var.stages_profiles
        target_id = var.target_id
      }
    }
  }
}

resource "google_clouddeploy_target" "target" {
  name             = var.target_id
  location         = var.location
  project          = var.project_id
  description      = var.description
  labels           = length(keys(var.labels)) < 0 ? null : var.labels
  annotations      = length(keys(var.annotations)) < 0 ? null : var.annotations
  require_approval = var.require_approval

  dynamic "gke" {
    for_each = var.enable_gke ? [{}] : []
    content {
      cluster = var.cluster
    }
  }
  depends_on = [
    google_clouddeploy_delivery_pipeline.primary_pipeline
  ]
}