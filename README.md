## Overview

This Terraform script will provision a simple ROKS (OpenShift) cluster in an IBM Cloud Satellite location running in IBM Cloud VPC.

## Prerequisites
### 1. Make sure the desired `resource_group` exists before running Terraform.
```
View available resource groups
% ibmcloud resource groups

Create a new one if you'd like
% ibmcloud resource group-create <NAME>
```
### 2. Create an ssh key in the desired region and resource group

```
Currently targeted region
% ibmcloud target

Switch to new region
% ibmcloud target -r <REGION>

List keys
% ibmcloud is keys

Create a new key if necessary
% ibmcloud is keyc <KEY-NAME> @~/.ssh/id_rsa.pub --resource-group-name <GROUP-NAME>
```

### 3. Define the requisite host image ID

The host ID should match the flavor of host defined in the `host_os` var.

RHCOS requires use of a custom image in IBM Cloud VPC. See the following for instructions: https://cloud.ibm.com/docs/satellite?topic=satellite-ibm#ibm-host-attach

```
View list of available hosts in currently targeted region
% ibmcloud is images
```

### 4. Define the api key Terraform will use to provision IBM Cloud Satellite resources as an environment variable

Use of an environment variable here reduces the likelihood of inadvertently publishing your api key.

```
% export TF_VAR_ibmcloud_api_key=<YOUR-API-KEY>
```