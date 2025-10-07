resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "tfstate-bucket"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
}

data "oci_objectstorage_namespace" "ns" {}