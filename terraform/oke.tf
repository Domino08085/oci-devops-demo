resource "tls_private_key" "public_private_key_pair" {
  algorithm = "RSA"
}

resource "oci_containerengine_cluster" "oci_oke_cluster" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.oke_kubernetes_version
  name               = "demo-oke"
  vcn_id             = oci_core_vcn.vcn.id
  type               = "BASIC_CLUSTER"

  endpoint_config {
    is_public_ip_enabled = false
    subnet_id            = oci_core_subnet.oke_k8s_endpoint_subnet.id
    nsg_ids              = []
  }

#   cluster_pod_network_options {
#     cni_type = "OCI_VCN_IP_NATIVE"
#   }

  options {
    service_lb_subnet_ids = [oci_core_subnet.oke_lb_subnet.id]

    add_ons {
      is_kubernetes_dashboard_enabled = true
      is_tiller_enabled               = true
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }

    kubernetes_network_config {
        pods_cidr     = "10.1.0.0/16"
        services_cidr = "10.2.0.0/16"
    }
  }
}

resource "oci_containerengine_node_pool" "oci_oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.oci_oke_cluster.id
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.oke_kubernetes_version
  name               = "demo-nodepool"
  node_shape         = var.node_shape

  initial_node_labels {
    key   = "key"
    value = "value"
  }

  #node_source_details {
    #image_id                = var.node_image_id == "" ? element([for source in data.oci_containerengine_node_pool_option.oci_oke_node_pool_option.sources : source.image_id if length(regexall("Oracle-Linux-${var.node_linux_version}-20[0-9]*.*", source.source_name)) > 0], 0) : var.node_image_id
    #image_id                = var.node_image_id == "" ? element([for source in local.node_pool_image_ids : source.image_id if length(regexall(local.node_image_regex, source.source_name)) > 0], 0) : var.node_image_id
  #}
    
  # OKE-specific images
  node_source_details {
    boot_volume_size_in_gbs = var.node_pool_node_source_details_boot_volume_size_in_gbs
    # check for GPU,A1 and other shapes. In future, if some other shapes or images are added, we need to modify
    image_id = var.node_image_id
    source_type = "IMAGE"
  }

  ssh_public_key = tls_private_key.public_private_key_pair.public_key_openssh

  node_config_details {

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name       
      subnet_id           = oci_core_subnet.oke_nodes_subnet.id
    }
    
    size = var.node_count

    # node_pool_pod_network_option_details {
    #     cni_type          = "OCI_VCN_IP_NATIVE"
    #     max_pods_per_node = 5
    #     pod_nsg_ids       = []
    #     pod_subnet_ids    = ""
    # }
  }

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration = "PT60M"
    is_force_delete_after_grace_duration = true
  }
}

resource "oci_artifacts_container_repository" "demo_repo" {
  compartment_id = var.compartment_ocid
  display_name   = "demo-python-app-ocir-repo"
  is_public      = false
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_node_pool_option" "np_opts" {
  node_pool_option_id  = oci_containerengine_cluster.oke.id
  compartment_id     = var.compartment_ocid
}