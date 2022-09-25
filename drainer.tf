resource "aws_autoscaling_lifecycle_hook" "ec2_instance_terminating" {
  count = length(var.asg_names)

  autoscaling_group_name = var.asg_names[count.index]

  name                 = "${var.cluster_name}-terminating"
  lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  heartbeat_timeout    = 300
  default_result       = "ABANDON"
}

resource "aws_iam_user" "asg_node_drainer" {
  name = "eks-node-drainer-${var.cluster_name}"
}

resource "aws_iam_access_key" "asg_node_drainer" {
  user = aws_iam_user.asg_node_drainer.name
}

resource "aws_iam_policy" "asg_node_drainer" {
  count = length(var.asg_arns)

  name        = "asg-node-drainer-${var.asg_names[count.index]}"
  description = "Lambda function policy for responding to ASG EC2 instance termination events, in order to drain EKS nodes."

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:CompleteLifecycleAction"
            ],
            "Resource": "${var.asg_arns[count.index]}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "asg_node_drainer" {
  name = "asg-node-drainer-${var.cluster_name}"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "asg_node_drainer" {
  count = length(aws_iam_policy.asg_node_drainer)

  role       = aws_iam_role.asg_node_drainer.name
  policy_arn = aws_iam_policy.asg_node_drainer[count.index].arn
}

resource "aws_cloudwatch_event_rule" "asg_node_drainer" {
  name          = "asg-node-drainer-${var.cluster_name}"
  description   = "Trigger a lambda function when an instance terminates in an ASG"
  event_pattern = <<EOF
{
  "source": ["aws.autoscaling"],
  "detail-type": ["EC2 Instance-terminate Lifecycle Action"],
  "detail": {
    "AutoScalingGroupName": ${jsonencode(var.asg_names)}
  }
}
EOF
}

data "github_release" "porter_node_drainer" {
  repository  = "porter-node-drainer"
  owner       = "porter-dev"
  retrieve_by = "latest"
}

resource "null_resource" "download_node_drainer" {
  // always download the node drainer
  triggers = {
    timestamp = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<CREATE
mkdir -p ${path.module}/files
curl -L https://github.com/porter-dev/porter-node-drainer/releases/download/${data.github_release.porter_node_drainer.release_tag}/porter_node_drainer_Linux_x86_64.zip -o ${path.module}/files/porter_node_drainer.zip
unzip ${path.module}/files/porter_node_drainer.zip -d ${path.module}/files
    CREATE
  }
}

data "archive_file" "lambda_zip" {
  depends_on = [
    null_resource.download_node_drainer
  ]

  type = "zip"

  source_file = "${path.module}/files/porter-node-drainer"
  output_path = "${path.module}/files/porter_node_drainer.zip"
}

resource "aws_lambda_function" "lambda_function_asg_node_drainer" {
  function_name = "${var.cluster_name}-node-drainer"
  publish       = false
  role          = aws_iam_role.asg_node_drainer.arn

  handler          = "porter-node-drainer"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  filename         = data.archive_file.lambda_zip.output_path
  runtime          = "go1.x"
  memory_size      = 1024
  timeout          = 300

  ephemeral_storage {
    size = 512
  }

  environment {
    variables = {
      EKS_AWS_ACCESS_KEY_ID     = aws_iam_access_key.asg_node_drainer.id
      EKS_AWS_SECRET_ACCESS_KEY = aws_iam_access_key.asg_node_drainer.secret
      EKS_AWS_REGION            = var.aws_region
      EKS_AWS_CLUSTER_ID        = var.cluster_name
      EKS_CLUSTER_SERVER        = var.cluster_endpoint
      EKS_CA_DATA               = base64decode(var.cluster_ca_data)
    }
  }
}

resource "aws_lambda_permission" "allow_asg_node_drainer_eventbridge_trigger" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function_asg_node_drainer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_node_drainer.arn
}


resource "aws_cloudwatch_event_target" "asg_node_drainer" {
  rule = aws_cloudwatch_event_rule.asg_node_drainer.name

  arn = aws_lambda_function.lambda_function_asg_node_drainer.arn
}