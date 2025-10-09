data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = var.tfstate_bucket_name
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  # tu ewentualnie: freeform_tags, lifecycle rules przez separate resource
}

output "bucket_name"   { value = oci_objectstorage_bucket.tfstate.name }
output "bucket_region" { value = var.region }
output "namespace"     { value = data.oci_objectstorage_namespace.ns.namespace }
