variable "project_id" {
  type        = string
  description = "The project for the resource"

}



variable "delivery_pipeline_name" {
  type        = string
  description = "Name of the DeliveryPipeline"

}
variable "region" {
  type        = string
  description = "The default Google Cloud region."

}

variable "anthos_target_cluster_membership" {
  type        = list(any)
  description = "Anthos Membership name of the target environment."
}