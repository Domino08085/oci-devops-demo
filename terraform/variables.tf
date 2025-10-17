variable "region" {}
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_pem" { sensitive = true }

resource "random_string" "deploy_id" {
  length  = 4
  special = false
}

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

variable "network_cidrs" {
  type = map(string)

  default = {
    VCN-CIDR                      = "10.20.0.0/16"
    SUBNET-REGIONAL-CIDR          = "10.20.10.0/24"
    LB-SUBNET-REGIONAL-CIDR       = "10.20.20.0/24"
    ENDPOINT-SUBNET-REGIONAL-CIDR = "10.20.0.0/28"
    ALL-CIDR                      = "0.0.0.0/0"
    PODS-CIDR                     = "10.244.0.0/16"
    KUBERNETES-SERVICE-CIDR       = "10.96.0.0/16"
  }
}

variable "user_admin_group_for_vault_policy" {
  default     = "Administrators"
  description = "User Identity Group to allow manage vault and keys. The user running the Terraform scripts or Applying the ORM Stack need to be on this group"
}

variable "use_encryption_from_oci_vault" {
  default     = false
  description = "By default, Oracle manages the keys that encrypts Kubernetes Secrets at Rest in Etcd, but you can choose a key from a vault that you have access to, if you want greater control over the key's lifecycle and how it's used"
}

# Looking for image_id
# oci compute pic listing list --all | jq -r -c '.data[] | select(."publisher-name" | test ("Ctrl IQ, Inc."))'
# oci compute pic version list --listing-id <listing-id> | jq -r '.data[]."listing-resource-id"'
# OR (command with cluster image)
# oci ce node-pool-options get --node-pool-option-id ocid1.cluster.oc1.eu-frankfurt-1.aaaaaaaayzfbvr7o3f5f6c77s7ie4236rcoklvqplju3hvgr2cmeixxndtja --region eu-frankfurt-1