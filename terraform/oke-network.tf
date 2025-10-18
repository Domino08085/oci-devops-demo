# VCN
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "OKE-VCN"
  cidr_block     = lookup(var.network_cidrs, "VCN-CIDR")
  dns_label      = "oke"
}

resource "oci_core_subnet" "oke_k8s_endpoint_subnet" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.vcn.id
  cidr_block          = lookup(var.network_cidrs, "ENDPOINT-SUBNET-REGIONAL-CIDR")
  display_name        = "oke-k8s-endpoint-subnet"
  dns_label           = "okek8sn"
  prohibit_public_ip_on_vnic = false
  route_table_id              = oci_core_route_table.oke_public_route_table.id
  dhcp_options_id            =  oci_core_vcn.vcn.default_dhcp_options_id
  security_list_ids           = [oci_core_security_list.oke_endpoint_security_list.id]
}

resource "oci_core_subnet" "oke_nodes_subnet" {
  cidr_block                 = lookup(var.network_cidrs, "SUBNET-REGIONAL-CIDR")
  compartment_id             = var.compartment_ocid
  display_name               = "oke-nodes-subnet-${random_string.deploy_id.result}"
  dns_label                  = "okenodesn${random_string.deploy_id.result}"
  vcn_id                     = oci_core_vcn.vcn.id
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.oke_private_route_table.id
  dhcp_options_id            = oci_core_vcn.vcn.default_dhcp_options_id
  security_list_ids          = [oci_core_security_list.oke_nodes_security_list.id]
}

resource "oci_core_subnet" "oke_lb_subnet" {
  cidr_block                 = lookup(var.network_cidrs, "LB-SUBNET-REGIONAL-CIDR")
  compartment_id             = var.compartment_ocid
  display_name               = "oke-lb-subnet-${random_string.deploy_id.result}"
  dns_label                  = "okelbsn${random_string.deploy_id.result}"
  vcn_id                     = oci_core_vcn.vcn.id
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.oke_public_route_table.id
  dhcp_options_id            = oci_core_vcn.vcn.default_dhcp_options_id
  security_list_ids          = [oci_core_security_list.oke_lb_security_list.id]
}

resource "oci_core_route_table" "oke_public_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "oke-public-route-table-${random_string.deploy_id.result}"

  route_rules {
    description       = "Traffic to/from internet"
    destination       = lookup(var.network_cidrs, "ALL-CIDR")
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oke_internet_gateway.id
  }
}

resource "oci_core_route_table" "oke_private_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "oke-private-route-table-${random_string.deploy_id.result}"

  # default to Internet via NAT
  route_rules {
    description       = "Traffic to the internet"
    destination       = lookup(var.network_cidrs, "ALL-CIDR")
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.oke_nat_gateway.id
  }

  # traffic to Oracle Services Network via Service Gateway
  route_rules {
    description       = "Traffic to OCI services"
    destination       = lookup(data.oci_core_services.all_services.services[0], "cidr_block")
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.oke_service_gateway[0].id
  }
}

resource "oci_core_nat_gateway" "oke_nat_gateway" {
  block_traffic  = "false"
  compartment_id = var.compartment_ocid
  display_name   = "oke-nat-gateway-${random_string.deploy_id.result}"
  vcn_id         = oci_core_vcn.vcn.id
}

resource "oci_core_internet_gateway" "oke_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-internet-gateway-${random_string.deploy_id.result}"
  enabled        = true
  vcn_id         = oci_core_vcn.vcn.id
}

resource "oci_core_service_gateway" "oke_service_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "oke-service-gateway-${random_string.deploy_id.result}"
  vcn_id         = oci_core_vcn.vcn.id
  services {
    service_id = lookup(data.oci_core_services.all_services.services[0], "id")
  }
}