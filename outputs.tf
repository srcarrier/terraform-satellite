
output "region_location" {
    value = var.region_locations[var.region]
    description = "Region location setting"
}

output "host_labels" {
    value = ibm_satellite_cluster.create.host_labels
    description = "Cluster host labels"
}

output "location_name" {
    value = data.ibm_satellite_location.location_info.location
    description = "Satellite location name"
}