
// Location Zones
locals {
  location_zones = ["${var.region}-1", "${var.region}-2", "${var.region}-3"]
}

// Resource group create
data "ibm_resource_group" "group" {
    name = var.resource_group
}

resource "random_string" "str" {
  length  = 5
  special = false
  upper   = false
}

// VPC
resource "ibm_is_vpc" "vpc" {
  name            = var.vpc_name
  resource_group  = data.ibm_resource_group.group.id
}

// Satellite location
resource "ibm_satellite_location" "satellite-location" {
  location          = "${var.location_name}-${random_string.str.result}"
  zones             = local.location_zones
  managed_from      = var.region_locations[var.region]
  resource_group_id = data.ibm_resource_group.group.id
  coreos_enabled    = true // Always create coreos-enabled location
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
data "ibm_is_ssh_key" "pub" {
  name       = var.sshkey_name
}

// Instance template
resource "ibm_is_instance_template" "instance_template" {
  name                      = var.instance_template_name
  image                     = var.host_image_id
  metadata_service {
    enabled = true
  }
  profile                   = var.vsi_profile

  primary_network_interface {
    name    = "eth0"
    subnet  = ibm_is_subnet.subnets[0].id
  }

  vpc  = ibm_is_vpc.vpc.id
  user_data = data.ibm_satellite_attach_host_script.attach_host.host_script
  zone = local.location_zones[0]
  keys = [data.ibm_is_ssh_key.pub.id]
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
    data.ibm_is_ssh_key.pub
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
  custom_script = var.custom_scripts[var.host_os].script
  coreos_host = var.host_os == "RHCOS" ? true : null
  host_provider = var.host_os == "RHCOS" ? "ibm" : null
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

// Assign control plane hosts
resource "ibm_satellite_host" "assign_hosts" {
  for_each    = toset(local.location_zones)
  location    = ibm_satellite_location.satellite-location.id
  host_id     = data.ibm_is_instances.vms.instances[index(data.ibm_is_instances.vms.instances.*.zone, each.key)].name
  zone        = each.key
  depends_on  = [
    ibm_is_instance_group.instance_group
  ]
}

resource "ibm_satellite_cluster" "create" {
    name                   = var.cluster_name
    location               = data.ibm_satellite_location.location_info.id
    enable_config_admin    = true
    kube_version           = var.kube_version
    operating_system       = var.host_os
    host_labels            = (["os:${var.host_os}"])
    resource_group_id      = data.ibm_resource_group.group.id
    wait_for_worker_update = true
    dynamic "zones" {
        for_each = data.ibm_satellite_location.location_info.zones
        content {
            id  = zones.value
        }
    }
    worker_count           = 1 
    depends_on  = [
      ibm_is_instance_group.instance_group
    ]
}
