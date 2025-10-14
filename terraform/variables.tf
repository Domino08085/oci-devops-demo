variable "region" {}
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_pem" { sensitive = true }

variable "oke_kubernetes_version" {
  default = "v1.34.1"
}
variable "node_shape" {
  default = "VM.Standard.E4.Flex"
}
variable "node_count" {
  default = 1
}
variable "node_ocpus" {
  default = 2
}
variable "node_memory_gbs" {
  default = 8
}
variable "node_pool_node_source_details_boot_volume_size_in_gbs" {
  default = 50
}

variable "node_image_id" {
  default = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaa24qxuqkpjds52wpq6jqcbxmf6p4dl56rlpqlz72cn7ycjxrocza" # Oracle-Linux-8.10-2025.08.31-0-OKE-1.34.1-1191
}

# Looking for image_id
# oci compute pic listing list --all | jq -r -c '.data[] | select(."publisher-name" | test ("Ctrl IQ, Inc."))'
# oci compute pic version list --listing-id <listing-id> | jq -r '.data[]."listing-resource-id"'
# OR (command with cluster image)
# oci ce node-pool-options get --node-pool-option-id ocid1.cluster.oc1.eu-frankfurt-1.aaaaaaaayzfbvr7o3f5f6c77s7ie4236rcoklvqplju3hvgr2cmeixxndtja --region eu-frankfurt-1