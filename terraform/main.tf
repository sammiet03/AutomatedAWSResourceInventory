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

# DynamoDB Table for storing AWS resource inventory
resource "aws_dynamodb_table" "resource_inventory" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ResourceId"

  attribute {
    name = "ResourceId"
    type = "S"
  }

  tags = {
    Name        = "AWS Resource Inventory"
    Environment = "Production"
  }
}

# SNS Topic for sending inventory reports
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

# IAM Role Attachments
resource "aws_iam_role_policy_attachment" "lambda_admin_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns_publish" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_full_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Lambda Function
resource "aws_lambda_function" "inventory_lambda" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 512

  s3_bucket = "aws-resource-inventory-lambda-project"
  s3_key    = "lambda_function.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table
      SNS_TOPIC_ARN  = aws_sns_topic.inventory_reports.arn
    }
  }

  tags = {
    Name        = "AWS Resource Inventory Lambda"
    Environment = "Production"
  }
}

# CloudWatch Permissions and Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_inventory.arn
}

resource "aws_cloudwatch_event_rule" "daily_inventory" {
  name                = "DailyInventoryTrigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_inventory.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.inventory_lambda.arn
}

# Explicitly create the log group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 3

  tags = {
    Environment = "Production"
  }
}
