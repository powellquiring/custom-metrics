terraform {
  required_version = ">= 1.0"

  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
    }
  }
}

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key to create resources"
}

variable "region" {
  default     = "us-south"
  description = "Region where to find and create resources"
}

variable "basename" {
  default     = "custom-image"
  description = "Prefix for all resources created by the template"
}

variable "existing_resource_group_name" {
  default = ""
}

locals {
  tags = [
    "basename:${var.basename}",
    lower(replace("dir:${abspath(path.root)}", "/", "_")),
  ]
}

variable "vpc_cidr" {
  default = "10.10.10.0/24"
}

provider "ibm" {
  region           = var.region
  ibmcloud_api_key = var.ibmcloud_api_key
}

#
# Create a resource group or reuse an existing one
#
resource "ibm_resource_group" "group" {
  count = var.existing_resource_group_name != "" ? 0 : 1
  name  = "${var.basename}-group"
  tags  = local.tags
}

data "ibm_resource_group" "group" {
  count = var.existing_resource_group_name != "" ? 1 : 0
  name  = var.existing_resource_group_name
}

locals {
  resource_group_id = var.existing_resource_group_name != "" ? data.ibm_resource_group.group.0.id : ibm_resource_group.group.0.id
}

resource "ibm_is_vpc" "vpc" {
  name                      = "${var.basename}-vpc"
  resource_group            = local.resource_group_id
  address_prefix_management = "manual"
  tags                      = concat(local.tags, ["vpc"])
}

resource "ibm_is_vpc_address_prefix" "subnet_prefix" {
  name = "${var.basename}-zone-1"
  zone = "${var.region}-1"
  vpc  = ibm_is_vpc.vpc.id
  cidr = var.vpc_cidr
}

resource "ibm_is_network_acl" "network_acl" {
  name           = "${var.basename}-acl"
  vpc            = ibm_is_vpc.vpc.id
  resource_group = local.resource_group_id

  rules {
    name        = "egress"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "outbound"
  }
  rules {
    name        = "ingress"
    action      = "allow"
    source      = "0.0.0.0/0"
    destination = "0.0.0.0/0"
    direction   = "inbound"
  }
}

resource "ibm_is_subnet" "subnet" {
  name            = "${var.basename}-subnet"
  vpc             = ibm_is_vpc.vpc.id
  zone            = "${var.region}-1"
  resource_group  = local.resource_group_id
  ipv4_cidr_block = ibm_is_vpc_address_prefix.subnet_prefix.cidr
  network_acl     = ibm_is_network_acl.network_acl.id
  tags            = concat(local.tags, ["vpc"])
}

resource "ibm_is_security_group" "group" {
  name           = "${var.basename}-sg"
  resource_group = local.resource_group_id
  vpc            = ibm_is_vpc.vpc.id
  tags           = concat(local.tags, ["vpc"])
}

resource "ibm_is_security_group_rule" "inbound_ssh" {
  group     = ibm_is_security_group.group.id
  direction = "inbound"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "outbound_http" {
  group     = ibm_is_security_group.group.id
  direction = "outbound"
  tcp {
    port_max = 80
    port_min = 80
  }
}

resource "ibm_is_security_group_rule" "outbound_https" {
  group     = ibm_is_security_group.group.id
  direction = "outbound"
  tcp {
    port_max = 443
    port_min = 443
  }
}

resource "ibm_is_security_group_rule" "outbound_public_monitoring" {
  group     = ibm_is_security_group.group.id
  direction = "outbound"
  tcp {
    port_max = 6443
    port_min = 6443
  }
}


resource "ibm_is_security_group_rule" "outbound_dns" {
  group     = ibm_is_security_group.group.id
  direction = "outbound"
  udp {
    port_max = 53
    port_min = 53
  }
}

resource "ibm_is_security_group_rule" "outbound_cse" {
  group     = ibm_is_security_group.group.id
  direction = "outbound"
  remote    = "166.9.0.0/16"
}

variable "ssh_key_name" {}

data "ibm_is_image" "image" {
  name = "ibm-ubuntu-20-04-3-minimal-amd64-2"
}


data "ibm_is_ssh_key" "key" {
  name = var.ssh_key_name
}

resource "ibm_is_instance" "instance" {
  name                           = var.basename
  image                          = data.ibm_is_image.image.id
  profile                        = "bx2-2x8"
  metadata_service_enabled       = true

  vpc            = ibm_is_vpc.vpc.id
  zone           = "${var.region}-1"
  keys           = [data.ibm_is_ssh_key.key.id]
  resource_group            = local.resource_group_id

  primary_network_interface {
    subnet = ibm_is_subnet.subnet.id
    security_groups = [ibm_is_security_group.group.id]
  }


  tags = local.tags
}


resource "ibm_is_floating_ip" "fip" {
  name   = var.basename
  target = ibm_is_instance.instance.primary_network_interface[0].id
}

output "hostname" {
  value = ibm_is_instance.instance.name
}

output "ip" {
  value = ibm_is_floating_ip.fip.address
}

output "ssh" {
  value = "ssh root@${ibm_is_floating_ip.fip.address}"
}
/*-----------------------------------------
--------------------------------------*/
