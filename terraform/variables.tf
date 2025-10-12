# variable "region" {}
# variable "tenancy_ocid" {}
# variable "compartment_ocid" {}
# variable "user_ocid" {}
# variable "fingerprint" {}
# variable "private_key_pem" { sensitive = true }


variable "oke_kubernetes_version" {
  default = "v1.34.1"
}
variable "node_shape" {
  default = "VM.Standard.E3.Flex"
}
variable "node_count" {
  default = 1
}
