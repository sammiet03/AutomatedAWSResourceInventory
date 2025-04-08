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
  description = "Lambda function name"
  default     = "ResourceInventoryLambda"
}

variable "lambda_role_name" {
  description = "IAM role for Lambda execution"
  default     = "LambdaResourceInventoryRole"
}
