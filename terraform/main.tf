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

  lifecycle {
    precondition {
      condition     = local.image_id != null
      error_message = "Nie udało się wybrać obrazu dla node poola (lista sources pusta)."
    }
  }

  node_source_details {
        source_type = "IMAGE"
        image_id = local.image_id
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
  is_arm     = strcontains(var.node_shape, ".A1.")
  arch_token = local.is_arm ? "aarch64" : "x86_64"

  candidate_sources = [
    for s in data.oci_containerengine_node_pool_option.np_opts.sources :
    s
    if s.source_type == "IMAGE" && (
      strcontains(lower(s.source_name), local.arch_token) ||
      # czasem w nazwach ARM nie ma "aarch64", więc drugi warunek awaryjny:
      (local.is_arm && strcontains(lower(s.source_name), "a1"))
    )
  ]

  image_id = (
    length(local.candidate_sources) > 0 ?
      local.candidate_sources[0].image_id :
      (
        length(data.oci_containerengine_node_pool_option.np_opts.sources) > 0 ?
          data.oci_containerengine_node_pool_option.np_opts.sources[0].image_id :
          null
      )
  )
}

output "np_sources_names" {
  value = [for s in data.oci_containerengine_node_pool_option.np_opts.sources : s.source_name]
}

output "picked_image_id" {
  value = local.image_id
}
