/**
 * Setup Lambda function to export EKS control plane logs from 
 * CloudWatch to OpenSearch. This Terraform sets up the Lambda function, 
 * the execution role and the resource policy to enable CloudWatch to 
 * invoke the Lambda function. 
 *
 * Lab participants will (manually) execute the steps to enable control plane logging, 
 * which creates the appropriate log group, enable the cloudwatch subscription
 * filter and setup the necessary OpenSearch domain permissions.   
 * 
 * This split provisioning approach is used because the CloudWatch subscription 
 * filter can only be enabled AFTER the log group is created.  The log group for 
 * control plane logs is created only within the lab module as part of the 
 * lab instructions.  
 * 
 * The Lambda function is provisioned with the AWS Parmeter and Secrets Lambda extension
 * layer to facilitate caching of the SSM Parameter Store values. 
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  cw_logs_arn_prefix = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  opensearch_parameter_path = "/eksworkshop/${var.eks_cluster_id}/opensearch/host"
  lambda_function_name = "${var.eks_cluster_id}-export-to-opensearch"

  # ARNs for Lambda Extension Layer that provides caching of SSM parameter store values
  parameter_lambda_extension_arns = {
    af-south-1     = "arn:aws:lambda:af-south-1:317013901791:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-east-1      = "arn:aws:lambda:ap-east-1:768336418462:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-northeast-1 = "arn:aws:lambda:ap-northeast-1:133490724326:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-northeast-2 = "arn:aws:lambda:ap-northeast-2:738900069198:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-northeast-3 = "arn:aws:lambda:ap-northeast-3:576959938190:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-south-1     = "arn:aws:lambda:ap-south-1:176022468876:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-south-2     = "arn:aws:lambda:ap-south-2:070087711984:layer:AWS-Parameters-and-Secrets-Lambda-Extension:8",
    ap-southeast-1 = "arn:aws:lambda:ap-southeast-1:044395824272:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-southeast-2 = "arn:aws:lambda:ap-southeast-2:665172237481:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-southeast-3 = "arn:aws:lambda:ap-southeast-3:490737872127:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    ap-southeast-4 = "arn:aws:lambda:ap-southeast-4:090732460067:layer:AWS-Parameters-and-Secrets-Lambda-Extension:1",
    ca-central-1   = "arn:aws:lambda:ca-central-1:200266452380:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    cn-north-1     = "arn:aws-cn:lambda:cn-north-1:287114880934:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    cn-northwest-1 = "arn:aws-cn:lambda:cn-northwest-1:287310001119:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-central-1   = "arn:aws:lambda:eu-central-1:187925254637:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-central-2   = "arn:aws:lambda:eu-central-2:772501565639:layer:AWS-Parameters-and-Secrets-Lambda-Extension:8",
    eu-north-1     = "arn:aws:lambda:eu-north-1:427196147048:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-south-1     = "arn:aws:lambda:eu-south-1:325218067255:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-south-2     = "arn:aws:lambda:eu-south-2:524103009944:layer:AWS-Parameters-and-Secrets-Lambda-Extension:8",
    eu-west-1      = "arn:aws:lambda:eu-west-1:015030872274:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-west-2      = "arn:aws:lambda:eu-west-2:133256977650:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    eu-west-3      = "arn:aws:lambda:eu-west-3:780235371811:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    il-central-1   = "arn:aws:lambda:il-central-1:148806536434:layer:AWS-Parameters-and-Secrets-Lambda-Extension:1",
    me-south-1     = "arn:aws:lambda:me-south-1:832021897121:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    me-central-1   = "arn:aws:lambda:me-central-1:858974508948:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    sa-east-1      = "arn:aws:lambda:sa-east-1:933737806257:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-east-1      = "arn:aws:lambda:us-east-1:177933569100:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-east-2      = "arn:aws:lambda:us-east-2:590474943231:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-gov-east-1  = "arn:aws-us-gov:lambda:us-gov-east-1:129776340158:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-gov-west-1  = "arn:aws-us-gov:lambda:us-gov-west-1:127562683043:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-west-1      = "arn:aws:lambda:us-west-1:997803712105:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11",
    us-west-2      = "arn:aws:lambda:us-west-2:345057560386:layer:AWS-Parameters-and-Secrets-Lambda-Extension:11"
  }
}

# Amazon OpenSearch Serverless (AOSS) encryption policy 
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name = var.eks_cluster_id
  type = "encryption"
  policy = jsonencode(
    {
      "Rules" = [
        {
          "Resource" = ["collection/${var.eks_cluster_id}"],
          "ResourceType" = "collection"
        }
      ],
      "AWSOwnedKey" = true
    })
}

# Amazon OpenSearch Serverless (AOSS) collection
resource "aws_opensearchserverless_collection" "eks_collection" {
  name = var.eks_cluster_id
  description = "EKS Workshop collection for OpenSearch-centric observability strategy" 
  standby_replicas = "DISABLED"
  type = "TIMESERIES"
  tags = var.tags

  depends_on = [aws_opensearchserverless_security_policy.encryption_policy]
}

# AOSS network policy for public access to collections and dashboards
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name = var.eks_cluster_id
  type = "network"
  description = "Public access"
  policy = jsonencode([
    {
      "Description" = "Public access to collection and Dashboards endpoint for example collection",
      "Rules" = [
        {
          "ResourceType" = "collection",
          "Resource" = ["collection/${var.eks_cluster_id}"]
        },
        {
          "ResourceType" = "dashboard"
          "Resource" = ["collection/${var.eks_cluster_id}"]
        }
      ],
      "AllowFromPublic" = true
    }
  ])
}

# AOSS data access policy that grants current IAM user full access
resource "aws_opensearchserverless_access_policy" "full_access" {
  name = var.eks_cluster_id
  type = "data"
  description = "Full access"
  policy = jsonencode([{
    "Rules" = [
      {
        "ResourceType" = "index",
        "Resource" = ["index/${var.eks_cluster_id}/*"],
        "Permission" = ["aoss:*"]
      },
      {
        "ResourceType" = "collection",
        "Resource" = ["collection/${var.eks_cluster_id}"],
        "Permission" = ["aoss:*"]
      }
    ],
    "Principal" = [data.aws_caller_identity.current.arn]
  }])
}

# IAM Role for Service Account (IRSA) assumed my exporter pods  
# Use IRSA because FluentBit does not support Pod Identity yet
resource "aws_iam_role" "opensearch_exporter_irsa" {
  name_prefix = "${var.eks_cluster_id}-aoss-irsa-"
  description = "IRSA for OpenSearch exporter"
 
  inline_policy {
    name = "aoss-exporter-policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "aoss:*",
          "Resource": "*"  
        }
      ]
    })
  }
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": var.addon_context.eks_oidc_provider_arn
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": { 
            "${var.addon_context.eks_oidc_issuer_url}:aud": "sts.amazonaws.com" 
          }
        }
      }
    ]
  })
}

# AOSS data access policy that grants write access to:
#     1. Lambda function invokved by CloudWatch Subscription Filter (to export control plane logs)
#     2. IRSA for opensearch exporter pods 
resource "aws_opensearchserverless_access_policy" "write_access" {
  name = "${var.eks_cluster_id}-exporter"
  type = "data"
  description = "Write permissions for Observability exporters"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index",
        Resource = ["index/${var.eks_cluster_id}/*"],
        Permission = ["aoss:*"]   # TODO: Restrict access
      },
      {
        ResourceType = "collection",
        Resource = ["collection/${var.eks_cluster_id}"],
        Permission = ["aoss:*"]  # TODO: Restrict access
      }
    ],
    Principal = [aws_iam_role.opensearch_exporter_irsa.arn,
                  aws_iam_role.lambda_execution_role.arn]  
  }])
}

# Lambda execution role for OpenSearch exporter
resource "aws_iam_role" "lambda_execution_role" {
  name_prefix = "${var.eks_cluster_id}-exporter-"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })

  inline_policy {
    name = "lambda-execution-policy"
    policy = jsonencode({
      "Version" = "2012-10-17"
      "Statement" = [
        {
          "Action" = ["aoss:*"] # TODO: Restrict access
          "Effect" = "Allow"
          "Resource" = "*"
        },        
        {
          "Action" = ["ssm:GetParameter"]
          "Effect" = "Allow"
          "Resource" = aws_ssm_parameter.opensearch_host.arn
        },
        {
          "Action" = ["logs:CreateLogGroup"]
          "Effect" = "Allow"
          "Resource" = local.cw_logs_arn_prefix
        },
        {
          "Action" = ["logs:CreateLogStream", "logs:PutLogEvents"]
          "Effect" = "Allow"
          "Resource" = "${local.cw_logs_arn_prefix}:log-group:/aws/lambda/${local.lambda_function_name}:*"
        }
      ]
    })
  }
}

# Create ZIP file with Lambda code
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/logs-to-opensearch.js"
  output_path = "${path.module}/function.zip"
}

# Create Lambda function to export logs to OpenSearch
resource "aws_lambda_function" "export_to_opensearch" {
  filename = "${path.module}/function.zip"
  function_name = local.lambda_function_name
  role = aws_iam_role.lambda_execution_role.arn
  handler = "logs-to-opensearch.handler"

  # Attach Lambda Layer for AWS Parameters and Secrets Lambda Extension ARNs
  layers = [local.parameter_lambda_extension_arns[data.aws_region.current.name]]

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs20.x"

  tags = var.tags

  environment {
    variables = {
      OPENSEARCH_HOST_PARAMETER_PATH = local.opensearch_parameter_path
      OPENSEARCH_INDEX_NAME = "eks-control-plane-logs"
      SSM_PARAMETER_STORE_TTL = 300
    }
  }
}

# Enable CloudWatch Logs to invoke Lambda function that exports to OpenSearch. 
# This sets up resource-based policy for Lambda.  Note that source ARN for the EKS 
# control plane log group has not yet been created at the time of terraform apply.  
# The logs group is created later when workshop participant (manually) run the 
# step to enable EKS Control Plane Logs.  
resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = local.lambda_function_name
  principal = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn = "${local.cw_logs_arn_prefix}:log-group:/aws/eks/${var.addon_context.eks_cluster_id}/cluster:*"
}

# Store OpenSearch host in parameter store
resource "aws_ssm_parameter" "opensearch_host" {
  name = local.opensearch_parameter_path
  description = "OpenSearch domain host endpoint"
  type = "String"
  value = aws_opensearchserverless_collection.eks_collection.arn

  tags = var.tags
}