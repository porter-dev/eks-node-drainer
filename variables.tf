variable "aws_region" {
  type = string
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable cluster_endpoint {
    type = string
}

variable cluster_ca_data {
    type = string
}

variable "asg_arns" {
    type = list(string)
}

variable "asg_names" {
    type = list(string)
}

variable "release_tag" {
    type = string
}