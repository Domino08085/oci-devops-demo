# VCN
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "demo-vcn"
  cidr_block     = "10.0.0.0/16"
}

resource "oci_core_subnet" "subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "demo-subnet"
  prohibit_public_ip_on_vnic = false
}

# OKE cluster
resource "oci_containerengine_cluster" "oke" {
  name            = "demo-oke"
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.vcn.id
  kubernetes_version = var.oke_kubernetes_version
}

# Node Pool
resource "oci_containerengine_node_pool" "np" {
  name           = "demo-nodepool"
  cluster_id     = oci_containerengine_cluster.oke.id
  compartment_id = var.compartment_ocid
  node_shape     = var.node_shape

  node_config_details {
    size = var.node_count
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
      subnet_id           = oci_core_subnet.subnet.id
    }
  }
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}
