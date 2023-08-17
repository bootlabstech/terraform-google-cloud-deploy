variable "project_id" {
  type        = string
  description = "The project for the resource"

}

variable "location" {
  type        = string
  description = "The location for the resource"
  
}

variable "delivery_pipeline_name" {
  type        = string
  description = "Name of the DeliveryPipeline"
  
}
variable "region" {
  type        = string
  description = "The default Google Cloud region."
  
}


variable "description" {
  type        = string
  description = "Description of the Target"
  
}

variable "labels" {
  type        = map(any)
  description = "Labels are attributes that can be set and used by both the user and by Google Cloud Deploy."
  default     = {}
}

variable "annotations" {
  type        = map(any)
  description = "Labels are attributes that can be set and used by both the user and by Google Cloud Deploy."
  default     = {}
}
variable "stages_profiles" {
  type        = list(string)
  description = "Skaffold profiles to use when rendering the manifest for this stage's Target"
  default = [ "" ]
}

variable "target_id" {
  type        = string
  description = "The target_id to which this stage points"
  
}

variable "target_name" {
  type        = string
  description = "The target_id to which this stage points"
}

variable "enable_serial_pipeline" {
  type        = bool
  description = "enable the serial_pipeline to run the block"
  default     = false
}

variable "require_approval" {
  type        = bool
  description = "Whether or not the Target requires approval. default value is false"
  default     = false
}

variable "enable_gke" {
  type        = bool
  description = ""
  default     = false
}

variable "cluster" {
  type        = string
  description = "Information specifying a GKE Cluster. Format is `projects/{project_id}/locations/{location_id}/clusters/{cluster_id}"
 
}