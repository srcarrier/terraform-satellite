variable "sshkey_pub" {}
variable "resource_group" { default = "default" }
variable "location_name" { default = "satellite-location" }
variable "vpc_name" { default = "vpc-satellite" }
variable "sshkey_name" { default = "sshkey-satellite" }
variable "instance_template_name" { default = "vsi-template-satellite" }
variable "vsi_profile" { default = "bx2d-4x16" }
variable "instance_group_name" { default = "instance-group-satellite"}
variable "instance_count" { default = 6 }
variable "cluster_name" { default = "roks-satellite"}

// Location Zones
locals {
  location_zones = ["${var.region}-1", "${var.region}-2", "${var.region}-3"]
}

// Resource group create
data "ibm_resource_group" "group" {
    name = var.resource_group
}

// VPC
resource "ibm_is_vpc" "vpc" {
  name            = var.vpc_name
  resource_group  = data.ibm_resource_group.group.id
}

// Satellite location
resource "ibm_satellite_location" "satellite-location" {
  location          = var.location_name
  zones             = local.location_zones
  managed_from      = "wdc" // TODO use map to figure this out based on region
  resource_group_id = data.ibm_resource_group.group.id
}

// Public gateway for each zone
resource "ibm_is_public_gateway" "gateways" {
  count = length(local.location_zones)
  name  = "gateway-${count.index+1}"
  vpc   = ibm_is_vpc.vpc.id
  zone  = local.location_zones[count.index]
  resource_group = data.ibm_resource_group.group.id
}

// Subnet for each zone
resource "ibm_is_subnet" "subnets" {
  count                     = length(local.location_zones)
  name                      = "subnet-${count.index+1}"
  vpc                       = ibm_is_vpc.vpc.id
  zone                      = local.location_zones[count.index]
  total_ipv4_address_count  = "256"
  public_gateway            = ibm_is_public_gateway.gateways[count.index].id
  resource_group = data.ibm_resource_group.group.id
}

// SSH key
resource "ibm_is_ssh_key" "pub" {
  name       = var.sshkey_name
  public_key = var.sshkey_pub
  resource_group = data.ibm_resource_group.group.id
}

// Instance template
resource "ibm_is_instance_template" "instance_template" {
  name                      = var.instance_template_name
  image                     = "r006-c51d1db2-834a-45da-a807-4b59243857ec"
  metadata_service_enabled  = true
  profile                   = var.vsi_profile

  primary_network_interface {
    name    = "eth0"
    subnet  = ibm_is_subnet.subnets[0].id
  }

  vpc  = ibm_is_vpc.vpc.id
  user_data = data.ibm_satellite_attach_host_script.attach_host.host_script
  zone = local.location_zones[0]
  keys = [ibm_is_ssh_key.pub.id]
  resource_group = data.ibm_resource_group.group.id

  boot_volume {
    name                             = "boot-volume-satellite"
    delete_volume_on_instance_delete = true
  }
  volume_attachments {
    delete_volume_on_instance_delete = true
    name                             = "volume-attach-satellite"
    volume_prototype {
      iops     = 1000
      profile  = "custom"
      capacity = 100
    }
  }
  depends_on = [
    ibm_satellite_location.satellite-location,
    ibm_is_ssh_key.pub
  ]
}

// Instance group
resource "ibm_is_instance_group" "instance_group" {
  name              = var.instance_group_name
  instance_template = ibm_is_instance_template.instance_template.id
  instance_count    = var.instance_count
  subnets           = [ibm_is_subnet.subnets[0].id, ibm_is_subnet.subnets[1].id, ibm_is_subnet.subnets[2].id]
  resource_group    = data.ibm_resource_group.group.id

  //User can configure timeouts
  timeouts {
    create = "15m"
    delete = "15m"
    update = "10m"
  }
}

// Custom host attach script
data "ibm_satellite_attach_host_script" "attach_host" {
  location      = ibm_satellite_location.satellite-location.id
  //host_provider = "ibm"
  // TODO add secondary user
  custom_script = <<EOF
subscription-manager refresh
subscription-manager repos --enable rhel-server-rhscl-7-rpms
subscription-manager repos --enable rhel-7-server-optional-rpms
subscription-manager repos --enable rhel-7-server-rh-common-rpms
subscription-manager repos --enable rhel-7-server-supplementary-rpms
subscription-manager repos --enable rhel-7-server-extras-rpms
EOF
  depends_on = [
    ibm_satellite_location.satellite-location
  ]
}

// Satellite location info (e.g. available hosts)
data "ibm_satellite_location" "location_info" {
  location    = ibm_satellite_location.satellite-location.id
  depends_on  = [
    ibm_satellite_location.satellite-location
  ]
}

data "ibm_is_instances" "vms" {
  instance_group = ibm_is_instance_group.instance_group.id
}

resource "ibm_satellite_host" "assign_hosts" {
  for_each    = toset(local.location_zones)
  location    = ibm_satellite_location.satellite-location.id
  host_id     = data.ibm_is_instances.vms.instances[index(data.ibm_is_instances.vms.instances.*.zone, each.key)].name
  zone        = each.key
  depends_on  = [
    ibm_is_instance_group.instance_group
  ]
}

resource "ibm_satellite_cluster" "create_cluster" {
    name                   = var.cluster_name
    location               = data.ibm_satellite_location.location_info.id
    enable_config_admin    = true
    kube_version           = "4.10_openshift" // TODO make configurable
    resource_group_id      = data.ibm_resource_group.group.id
    wait_for_worker_update = true
    //zones                  = local.location_zones
    dynamic "zones" {
        for_each = data.ibm_satellite_location.location_info.zones
        content {
            id  = zones.value
        }
    }
    depends_on  = [
      ibm_is_instance_group.instance_group
    ]
}

resource "ibm_satellite_cluster_worker_pool" "create_worker_pool" {
    name               = "roks-wp-satellite"
    cluster            = ibm_satellite_cluster.create_cluster.id
    worker_count       = 1
    resource_group_id  = data.ibm_resource_group.group.id
    dynamic "zones" {
        for_each = data.ibm_satellite_location.location_info.zones
        content {
              id  = zones.value
        }
      }
    host_labels        = ["os:RHEL7"]
    depends_on = [
      ibm_satellite_cluster.create_cluster
    ]
}
