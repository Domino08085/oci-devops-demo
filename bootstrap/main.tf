# data "oci_objectstorage_namespace" "ns" {
#   compartment_id = var.tenancy_ocid
# }

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = var.namespace
  name           = var.tfstate_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
}

output "bucket_name"   { value = oci_objectstorage_bucket.tfstate.name }
output "bucket_region" { value = var.region }
output "namespace"     { value = var.namespace }
