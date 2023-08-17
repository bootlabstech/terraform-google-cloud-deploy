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



resource "google_workflows_workflow" "event-trigger-destination1" {
  # for_each        = toset(var.anthos_target_cluster_membership)
  name            = "workflow"
  project         = var.project_id
  region          = var.region
  service_account = "viai-model-deploy-service@${var.project_id}.iam.gserviceaccount.com"
  source_contents = <<-EOF
main:
  params: [event]
  steps:
    - init:
        assign:
          - project_id: ${var.project_id}
          - location_id: ${var.region}
          - pipeline: ${var.project_id}
    - decode_pubsub_message:
        assign:
            - data: $${event.data}
            - action: $${data.protoPayload.methodName}
            - resource_name: $${event.resourceName}
            - image_url_path_array: $${text.split(resource_name, "/")}
            - image_tag: $${image_url_path_array[len(image_url_path_array) - 1]}
            - repository_name: $${image_url_path_array[len(image_url_path_array) - 3]}
            - image_location: $${location_id + "-docker.pkg.dev/" + project_id + "/" + repository_name + "/" + image_tag}
            - target_cluster: 
            - time_string: $${text.replace_all(text.replace_all(text.split(time.format(sys.now()), ".")[0], "-", ""), ":", "")}
            - tag_string: $${text.split(image_tag, "@")[0]}
            - requestId: $${text.to_lower(tag_string) + text.to_lower(time_string)}
    - cloud_deploy:
        call: http.post
        args:
          url: $${"https://clouddeploy.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/deliveryPipelines/${google_clouddeploy_delivery_pipeline.primary_pipeline.name}/releases?releaseId=" + requestId}
          auth:
            type: OAuth2
            scopes: https://www.googleapis.com/auth/cloud-platform
          body:
            buildArtifacts:
              - image: viai-inference-module
                tag: $${image_location}
            skaffoldConfigUri: $${"gs://" + project_id + "_cloudbuild/viai-models/" + tag_string + ".tar.gz" }
            skaffoldConfigPath: /skaffold.yaml
    - the_end:
        return: "SUCCESS"
    EOF
}

resource "google_eventarc_trigger" "artifact_registry_trigger" {

  location = var.region
  name     = "event-trigger"
  project  = var.project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "artifactregistry.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "Docker-PutManifest"
  }
  matching_criteria {
    attribute = "resourceName"
    operator  = "match-path-pattern"
    value     = "/projects/${var.project_id}/locations/${var.region}/repositories/${var.region}-viai-models/dockerImages/*"
  }
  destination {
    workflow = google_workflows_workflow.event-trigger-destination1.id
  }
  service_account = "viai-model-deploy-service@${var.project_id}.iam.gserviceaccount.com"
  depends_on = [
    google_workflows_workflow.event-trigger-destination1,
    google_clouddeploy_delivery_pipeline.primary_pipeline
  ]
}
