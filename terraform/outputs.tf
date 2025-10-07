output "oke_cluster_id" {
  value = oci_containerengine_cluster.oke.id
}
output "subnet_id" {
  value = oci_core_subnet.subnet.id
}
output "vcn_id" {
  value = oci_core_virtual_cloud_network.vcn.id
}
