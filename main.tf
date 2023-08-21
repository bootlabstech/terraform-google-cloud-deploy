resource "google_clouddeploy_delivery_pipeline" "delivery_pipeline1" {
  for_each    = toset(var.anthos_target_cluster_membership)
  location    = var.region
  name        = "${var.delivery_pipeline_name}-${each.key}"
  description = "${each.key} delivery pipeline."
  project     = var.project_id
  serial_pipeline {
    stages {
      profiles  = []
      target_id = google_clouddeploy_target.dev1[each.key].name
    }
  }
}

resource "google_clouddeploy_target" "dev1" {
  for_each = toset(var.anthos_target_cluster_membership)
  location = var.region
  name     = each.key
  project  = var.project_id
  anthos_cluster {
    membership = "projects/${var.project_id}/locations/global/memberships/${each.key}"
  }
  require_approval = false
  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = "viai-abm-service@${var.project_id}.iam.gserviceaccount.com"
  }
}

resource "google_workflows_workflow" "event-trigger-destination1" {
  for_each        = toset(var.anthos_target_cluster_membership)
  name            = "workflow-${each.key}"
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
          - pipeline: ${var.project_id}-${each.key}
    - decode_pubsub_message:
        assign:
            - data: $${event.data}
            - action: $${data.protoPayload.methodName}
            - resource_name: $${event.resourceName}
            - image_url_path_array: $${text.split(resource_name, "/")}
            - image_tag: $${image_url_path_array[len(image_url_path_array) - 1]}
            - repository_name: $${image_url_path_array[len(image_url_path_array) - 3]}
            - image_location: $${location_id + "-docker.pkg.dev/" + project_id + "/" + repository_name + "/" + image_tag}
            - target_cluster: ${each.key}
            - time_string: $${text.replace_all(text.replace_all(text.split(time.format(sys.now()), ".")[0], "-", ""), ":", "")}
            - tag_string: $${text.split(image_tag, "@")[0]}
            - requestId: $${text.to_lower(tag_string) + text.to_lower(time_string)}
    - cloud_deploy:
        call: http.post
        args:
          url: $${"https://clouddeploy.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/deliveryPipelines/${google_clouddeploy_delivery_pipeline.delivery_pipeline1[each.key].name}/releases?releaseId=" + requestId}
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
  for_each = toset(var.anthos_target_cluster_membership)
  location = var.region
  name     = "${each.key}-event-trigger"
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
    workflow = google_workflows_workflow.event-trigger-destination1[each.key].id
  }
  service_account = "viai-model-deploy-service@${var.project_id}.iam.gserviceaccount.com"
  depends_on = [
    google_workflows_workflow.event-trigger-destination1,
    google_clouddeploy_delivery_pipeline.delivery_pipeline1
  ]
}
