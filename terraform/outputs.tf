output "oke_cluster_id" {
  value = oci_containerengine_cluster.oci_oke_cluster.id
}
output "endpoint_subnet_id" {
  value = oci_core_subnet.oke_k8s_endpoint_subnet.id
}
output "nodes_subnet_id" {
  value = oci_core_subnet.oke_nodes_subnet.id
}
output "lb_subnet_id" {
  value = oci_core_subnet.oke_lb_subnet.id
}
output "vcn_id" {
  value = oci_core_vcn.vcn.id
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

# output "selected_image" {
#   value = local.node_image
# }
