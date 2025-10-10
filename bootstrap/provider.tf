terraform {
  required_version = ">= 1.4.0"
  required_providers {
    oci = { 
      source = "oracle/oci"
      version = ">=5.0.0" }
  }
}
provider "oci" {
  #config_file_profile = "DEFAULT"
  region           = var.region
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = var.private_key_pem
}
