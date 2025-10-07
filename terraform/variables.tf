variable "region" {}
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}

variable "oke_kubernetes_version" {
  default = "v1.29.1"
}
variable "node_shape" {
  default = "VM.Standard.E3.Flex"
}
variable "node_count" {
  default = 2
}
