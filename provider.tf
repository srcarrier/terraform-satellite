variable "ibmcloud_api_key" {}
variable "region" {
    default = "us-south"
}

provider "ibm" {
    ibmcloud_api_key   = var.ibmcloud_api_key
    region = var.region
}
