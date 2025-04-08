variable "aws_region" {
  description = "AWS region for resources"
  default     = "us-east-1"
}

variable "dynamodb_table" {
  description = "DynamoDB table name"
  default     = "ResourceInventory"
}

variable "sns_topic_name" {
  description = "SNS topic for inventory reports"
  default     = "InventoryReports"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  default     = "ResourceInventoryLambda"
}

variable "lambda_role_name" {
  description = "Name of the IAM role for Lambda"
  default     = "lambda_inventory_role"
}

variable "s3_bucket_name" {
  description = "S3 bucket where Lambda zip is stored"
  type        = string
}