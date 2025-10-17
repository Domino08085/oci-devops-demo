resource "oci_identity_dynamic_group" "oke_nodes_dg" {
  name           = "oke-cluster-dg-${random_string.deploy_id.result}"
  description    = "Cluster Dynamic Group"
  compartment_id = var.tenancy_ocid
  matching_rule  = "ANY {ALL {instance.compartment.id = '${var.compartment_ocid}'},ALL {resource.type = 'cluster', resource.compartment.id = '${var.compartment_ocid}'}}"
}
resource "oci_identity_policy" "oke_compartment_policies" {
  name           = "oke-cluster-compartment-policies-${random_string.deploy_id.result}"
  description    = "OKE Cluster Compartment Policies"
  compartment_id = var.compartment_ocid
  statements     = local.oke_compartment_statements

  depends_on = [oci_identity_dynamic_group.oke_nodes_dg]
}
resource "oci_identity_policy" "kms_compartment_policies" {
  name           = "kms-compartment-policies-${random_string.deploy_id.result}"
  description    = "KMS Compartment Policies"
  compartment_id = var.compartment_ocid
  statements     = local.kms_compartment_statements

  depends_on = [oci_identity_dynamic_group.oke_nodes_dg]
}

resource "oci_identity_policy" "oke_tenancy_policies" {
  name           = "oke-cluster-tenancy-policies-${random_string.deploy_id.result}"
  description    = "OKE Cluster Tenancy Policies"
  compartment_id = var.tenancy_ocid
  statements     = local.oke_tenancy_statements

  depends_on = [oci_identity_dynamic_group.oke_nodes_dg]
}

locals {
  oke_tenancy_statements = concat(
    local.oci_grafana_metrics_statements
  )
  oke_compartment_statements = concat(
    local.oci_grafana_logs_statements,
    var.use_encryption_from_oci_vault ? local.allow_oke_use_oci_vault_keys_statements : []
    #var.cluster_autoscaler_enabled ? local.cluster_autoscaler_statements : []
  )
  kms_compartment_statements = concat(
    local.allow_group_manage_vault_keys_statements
  )
}

locals {
  oke_nodes_dg     = oci_identity_dynamic_group.oke_nodes_dg.name
  oci_vault_key_id = "void"
  #var.use_encryption_from_oci_vault ? (var.create_new_encryption_key ? oci_kms_key.mushop_key[0].id : var.existent_encryption_key_id) : "void"
  oci_grafana_metrics_statements = [
    "Allow dynamic-group ${local.oke_nodes_dg} to read metrics in tenancy",
    "Allow dynamic-group ${local.oke_nodes_dg} to read compartments in tenancy"
  ]
  oci_grafana_logs_statements = [
    "Allow dynamic-group ${local.oke_nodes_dg} to read log-groups in compartment id ${var.compartment_ocid}",
    "Allow dynamic-group ${local.oke_nodes_dg} to read log-content in compartment id ${var.compartment_ocid}"
  ]
  # cluster_autoscaler_statements = [
  #   "Allow dynamic-group ${local.oke_nodes_dg} to manage cluster-node-pools in compartment id ${var.compartment_ocid}",
  #   "Allow dynamic-group ${local.oke_nodes_dg} to manage instance-family in compartment id ${var.compartment_ocid}",
  #   "Allow dynamic-group ${local.oke_nodes_dg} to use subnets in compartment id ${var.compartment_ocid}",
  #   "Allow dynamic-group ${local.oke_nodes_dg} to read virtual-network-family in compartment id ${var.compartment_ocid}",
  #   "Allow dynamic-group ${local.oke_nodes_dg} to use vnics in compartment id ${var.compartment_ocid}",
  #   "Allow dynamic-group ${local.oke_nodes_dg} to inspect compartments in compartment id ${var.compartment_ocid}"
  # ]
  allow_oke_use_oci_vault_keys_statements = [
    "Allow service oke to use vaults in compartment id ${var.compartment_ocid}",
    "Allow service oke to use keys in compartment id ${var.compartment_ocid} where target.key.id = '${local.oci_vault_key_id}'",
    "Allow dynamic-group ${local.oke_nodes_dg} to use keys in compartment id ${var.compartment_ocid} where target.key.id = '${local.oci_vault_key_id}'"
  ]
  allow_group_manage_vault_keys_statements = [
    "Allow group ${var.user_admin_group_for_vault_policy} to manage vaults in compartment id ${var.compartment_ocid}",
    "Allow group ${var.user_admin_group_for_vault_policy} to manage keys in compartment id ${var.compartment_ocid}",
    "Allow group ${var.user_admin_group_for_vault_policy} to use key-delegate in compartment id ${var.compartment_ocid}"
  ]
}