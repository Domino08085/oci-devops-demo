# VCN
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "demo-vcn"
  cidr_block     = "10.0.0.0/16"
}

# Internet Gateway (Access to and from the internet)
resource "oci_core_internet_gateway" "ig" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "demo-oke-ig"
}

# Private Subnet for Node Pool (with NAT Gateway)
resource "oci_core_subnet" "subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "demo-subnet"
  prohibit_public_ip_on_vnic = false
  route_table_id              = oci_core_route_table.node_route_table.id
  security_list_ids           = [oci_core_security_list.oke_nodes_sl.id]
}

# NAT Gateway (for outbound internet from private subnet)
resource "oci_core_nat_gateway" "nat_gw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "demo-nat-gw"
}

# Route Table for Private Subnet (redirect traffic to NAT)
resource "oci_core_route_table" "node_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "demo-node-rt"

  route_rules {
    destination        = "0.0.0.0/0"
    network_entity_id  = oci_core_nat_gateway.nat_gw.id
    description        = "Route to NAT Gateway for internet access"
  }
}

# Security lists for OKE nodes
resource "oci_core_security_list" "oke_nodes_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "oke-nodes-sl"
  
  # Ingress: SSH (22) with VCN
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "10.0.0.0/16" # VCN CIDR
    tcp_options {
      min = 22
      max = 22
    }
  }
  
  # Egress: All traffic to anywhere
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# OKE cluster
resource "oci_containerengine_cluster" "oke" {
  name            = "demo-oke"
  compartment_id  = var.compartment_ocid
  vcn_id          = oci_core_vcn.vcn.id
  kubernetes_version = var.oke_kubernetes_version

  options {
    kubernetes_network_config {
      pods_cidr    = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
  }
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

    freeform_tags = {
      "oke-nodepool-tag" = "demo-nodepool-${oci_containerengine_cluster.oke.name}"
    }

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

# Dynamic Group for OKE Nodes (based on tag)
resource "oci_identity_dynamic_group" "oke_nodes_dg" {
  compartment_id = var.tenancy_ocid
  name           = "OKE_Nodes_Demo_DG"
  description    = "Dynamic Group for OKE worker nodes in demo cluster"
  # Rule to match instances with the specific tag
  matching_rule  = "All {instance.freeformtags[\"oke-nodepool-tag\"] = 'demo-nodepool-${oci_containerengine_cluster.oke.name}'}"
}

# Policy for OKE Nodes (grant necessary permissions)
resource "oci_identity_policy" "oke_nodes_policy" {
  compartment_id = var.compartment_ocid
  name           = "OKE-Node-Policy-Demo"
  description    = "Grants OKE worker nodes necessary permissions."
  statements = [
    # Permission to use VCN resources
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to use virtual-network-family in compartment id ${var.compartment_ocid}",
    # Permissions for compute and storage (for PV/PVC)
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to manage instance-family in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to manage volume-family in compartment id ${var.compartment_ocid}",
    # Permissions for Load Balancers management
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to manage load-balancers in compartment id ${var.compartment_ocid}",
    # Permission to access OCI Registry (OCIR)
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to read repos in tenancy",
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes_dg.name} to inspect secrets in compartment id ${var.compartment_ocid}"
  ]
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