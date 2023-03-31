variable "ibmcloud_api_key" {
    type = string
    description = "IBM Cloud API key used to provision Satellite resources"
    sensitive = true
}

variable "region" {
    type = string
    description = "Region used to deploy Satellite resources"
    default = "us-east"
}

variable "resource_group" { 
    type = string
    default = "default" 
    description = "Pre-existing resource group to provision Satellite resources"
}

variable "location_name" { 
    type = string
    default = "satellite-location" 
    description = "Name of the Satellite Location"
}

variable "vpc_name" { 
    type = string
    default = "vpc-satellite" 
    description = "Name of the VPC"
}

variable "sshkey_name" { default = "sshkey-satellite" }
variable "instance_template_name" { default = "vsi-template-satellite" }
variable "vsi_profile" { default = "bx2d-8x32" }
variable "instance_group_name" { default = "instance-group-satellite" }
variable "instance_count" { 
    type = number
    default = 6
    description = "Number of hosts to provision via instance group"
}
variable "cluster_name" { default = "roks-satellite" }
variable "host_image_id" {}
variable "host_os" { 
    type = string
    description = "Satellite host operating system: RHEL8 or RHCOS"
    default = "RHCOS" 
}
variable "kube_version" { default = "4.11_openshift" }

variable "region_locations" {
  type = map(string)
  default = {
    "us-east" = "wdc"
    "us-south" = "dal"
    "au-syd" = "syd"
    "jp-tok" = "tok"
    "jp-osa" = "osa"
    "ca-tor" = "tor"
    "eu-de" = "fra"
    "eu-gb" = "lon"
    "br-sao" = "sao"
  }
}

// Custom RHEL host scripts
variable "custom_scripts" {
    default = {
        "RHEL8" = {
            "script" = <<EOF
useradd admin
usermod -aG wheel admin
mkdir /home/admin/.ssh
cp .ssh/authorized_keys /home/admin/.ssh/
chown admin:admin /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/
subscription-manager refresh
subscription-manager release --set=8
subscription-manager repos --disable='*eus*'
subscription-manager repos --enable rhel-8-for-x86_64-appstream-rpms
subscription-manager repos --enable rhel-8-for-x86_64-baseos-rpms
EOF
        }
        "RHCOS" = {
            "script" = null
        }
    }
}
