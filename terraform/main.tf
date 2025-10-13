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
  kubernetes_version = var.oke_kubernetes_version

  dynamic "node_shape_config" {
    for_each = strcontains(var.node_shape, ".Flex") ? [1] : []
    content {
      ocpus         = var.node_ocpus        
      memory_in_gbs = var.node_memory_gbs   
    }
  }

  node_config_details {
    size = var.node_count
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
      subnet_id           = oci_core_subnet.subnet.id
    }
  }

  node_source_details {
        source_type = "IMAGE"
        image_id = var.node_image_id # local.node_image_id
        boot_volume_size_in_gbs = var.node_pool_node_source_details_boot_volume_size_in_gbs
  }
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_node_pool_option" "np_opts" {
  node_pool_option_id  = oci_containerengine_cluster.oke.id
  compartment_id     = var.compartment_ocid
}

locals {
  matching_images = [
    for s in data.oci_containerengine_node_pool_option.np_opts.sources :
    s
    if s.source_type == "IMAGE" &&
       strcontains(lower(s.source_name), "oracle-linux-8") &&
       !strcontains(lower(s.source_name), "aarch64")
  ]

  node_image = length(local.matching_images) > 0 ? local.matching_images[0] : null

  node_image_id = local.node_image != null ? local.node_image.image_id : null
}

output "available_oke_images" {
  value = [for s in data.oci_containerengine_node_pool_option.np_opts.sources : {
    name = s.source_name
    id   = s.image_id
  }]
}

output "debug_images" {
  value = [for s in data.oci_containerengine_node_pool_option.np_opts.sources : s.source_name]
}

output "selected_image" {
  value = local.node_image
}