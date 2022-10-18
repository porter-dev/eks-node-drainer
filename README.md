# eks-node-drainer
This repo stores TF definitions for deploying our node drainage components on a Porter-provisioned cluster.

## Prerequisites

1. You'll need Terraform 1.1.8 for this - you can find installation instructions for your preferred platform here: [https://learn.hashicorp.com/tutorials/terraform/install-cli](https://learn.hashicorp.com/tutorials/terraform/install-cli).

2. Console access to AWS, in order to retrieve configuration values needed to apply the node drainer to your cluster.

3. The appropriate `ClusterRole` and `ClusterRoleBinding` applied on your cluster - see the upgrade manual for more information.

3. This repo itself, cloned locally.

## Configuration

First, `cd` over into the repo, and create a copy of the `terraform.tfvars.template` file - name it `terraform.tfvars`. The next step is to assign values to the variables mentioned in this file:

```
aws_region = ""
aws_access_key = ""
aws_secret_key = ""
cluster_name = ""
cluster_endpoint = ""
cluster_ca_data = ""
asg_arns=["", "", ""]
asg_names=["", "", ""]
```

The values for the `cluster_name`, `cluster_endpoint` and `cluster_ca_data` variables can be found on the cluster detail page for your cluster, on the AWS EKS dashboard. The values for `asg_arns` and `asg_names` can be found on the EC2 Autoscaling dashboard in the EC2 console; you'll just need to ensure that you paste the exact ARNs and names for the right autoscaling groups powering your cluster - your cluster's name will be part of the appropriate autoscaling groups' names. You'll also need to ensure that you fill the name of an ASG in the same order as its ARN, between these two arrays.

## Apply

We recommend you create a new workspace, especially if you intend to apply this on multiple Porter clusters: `terraform workspace new <WORKSPACE_NAME>`. Run `terraform plan` to get a glimpse of what will be added, and then run `terraform apply`. Note that if you intend to use this for multiple clusters, you'll also need to delete the `files/` directory that gets created during every Terraform apply run, after a successful run.

