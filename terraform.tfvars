// Required input variables
ibmcloud_api_key = "<API_KEY_HERE>"
sshkey_pub = "<PUB_KEY_HERE>"

// Optional defaulted input variables
region = "us-east" // default to "us-south" if omitted
instance_count = 6 // Includes 3 CP hosts, defaults to 6 if omitted
resource_group = "satellite" // defaults to "default" if omitted
//location_name = "" // defaults to "satellite-location" if omitted
//vpc_name = "" // defaults to "vpc-satellite" if omitted
//sshkey_name = "" // defaults to "sshkey-satellite" if omitted
//instance_template_name = "" // defaults to "vsi-template-satellite" if omitted
//instance_group_name = "" // defaults to "instance-group-satellite" if omitted
//vsi_profile = "" // defaults to "bx2d-4x16" if omitted
//cluster_name = "" // defaults to "roks-satellite"