terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Table
resource "aws_dynamodb_table" "resource_inventory" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ResourceId"

  attribute {
    name = "ResourceId"
    type = "S"
  }
}

# SNS Topic
resource "aws_sns_topic" "inventory_reports" {
  name = var.sns_topic_name
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = var.lambda_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach AWS Lambda basic execution role for CloudWatch logging
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach S3 Read-Only Access Policy
resource "aws_iam_role_policy_attachment" "lambda_s3_read_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Custom Inline Policy for S3 Bucket Creation
resource "aws_iam_policy" "lambda_s3_create" {
  name        = "LambdaS3CreatePolicy"
  description = "Policy to allow Lambda to create and read S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-resource-inventory-lambda-project",
          "arn:aws:s3:::aws-resource-inventory-lambda-project/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_create_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_create.arn
}

resource "aws_lambda_function" "inventory_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"  # Change from python3.11 to python3.9

  # S3 location of the Lambda zip file
  s3_bucket = "aws-resource-inventory-lambda-project"  # Replace with your bucket name
  s3_key    = "lambda_function.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table
      SNS_TOPIC_ARN  = aws_sns_topic.inventory_reports.arn
    }
  }

  tags = {
    Name = "AWS Resource Inventory Lambda"
  }
}



# CloudWatch Event Rule
resource "aws_cloudwatch_event_rule" "daily_inventory" {
  name                = "DailyInventoryTrigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.daily_inventory.name
  arn  = aws_lambda_function.inventory_lambda.arn
}
