terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">=5.0.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "oci" {
  config_file_profile = "DEFAULT"
}