# Automated AWS Resource Inventory

### ✅ **Step-by-Step Approach:**

**1. Infrastructure Setup with Terraform:**
- **Terraform modules:** Create or reuse existing Terraform modules for:
  - **AWS Lambda** (Python/Boto3 runtime)
  - **IAM Roles/Policies** (minimum permissions: `ec2:Describe*`, `s3:List*`, `iam:Get*`, `dynamodb:PutItem`)
  - **DynamoDB Table** (for inventory storage)
  - **CloudWatch Events (EventBridge)** for scheduling Lambda functions daily
  - **SNS Topics** for report notifications

Example Terraform snippet (simplified):

```hcl
resource "aws_dynamodb_table" "resource_inventory" {
  name         = "ResourceInventory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ResourceId"

  attribute {
    name = "ResourceId"
    type = "S"
  }
}

resource "aws_lambda_function" "inventory_lambda" {
  function_name = "ResourceInventoryLambda"
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn

  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "DailyInventoryTrigger"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.inventory_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

resource "aws_sns_topic" "inventory_reports" {
  name = "InventoryReports"
}
```

---

**2. Develop Lambda Function (Python + Boto3):**
- Scan resources (EC2, S3, IAM)
- Store scan results in DynamoDB
- Generate and send reports via SNS

Sample Lambda Function (`lambda_function.py`):

```python
import boto3
import json
import datetime

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    sns = boto3.client('sns')
    table = dynamodb.Table('ResourceInventory')
    
    ec2_client = boto3.client('ec2')
    s3_client = boto3.client('s3')
    iam_client = boto3.client('iam')

    # Scan EC2 Instances
    instances = ec2_client.describe_instances()
    ec2_resources = [
        {'ResourceId': i['InstanceId'], 'Type': 'EC2', 'Details': json.dumps(i)}
        for r in instances['Reservations'] for i in r['Instances']
    ]

    # Scan S3 Buckets
    buckets = s3_client.list_buckets()
    s3_resources = [
        {'ResourceId': b['Name'], 'Type': 'S3', 'Details': json.dumps(b)}
        for b in buckets['Buckets']
    ]

    # Scan IAM Users
    users = iam_client.list_users()
    iam_resources = [
        {'ResourceId': u['UserName'], 'Type': 'IAM', 'Details': json.dumps(u)}
        for u in users['Users']
    ]

    # Consolidate all resources
    all_resources = ec2_resources + s3_resources + iam_resources

    # Write to DynamoDB
    for resource in all_resources:
        table.put_item(Item={
            'ResourceId': resource['ResourceId'],
            'Type': resource['Type'],
            'Details': resource['Details'],
            'Timestamp': datetime.datetime.utcnow().isoformat()
        })

    # SNS Notification
    sns.publish(
        TopicArn='arn:aws:sns:region:account_id:InventoryReports',
        Subject='Daily AWS Inventory Report',
        Message=f"Inventory scan completed. Total resources scanned: {len(all_resources)}."
    )

    return {'status': 'success', 'scanned': len(all_resources)}
```

---

**3. Integrating with Existing AWS Project:**
- Ensure consistent use of existing **Route 53, ACM, and API Gateway** for domain management and secure HTTPS connections, if any dashboards or API access is needed.
- Configure existing **CloudFront** if you're planning to visualize the inventory data or serve reports publicly.

---

**4. Automation & Deployment:**
- Automate Lambda packaging and deployment (`zip` and Terraform deploy via CI/CD tools such as **GitHub Actions** or **AWS CodePipeline**).
- Integrate with existing Terraform codebase (add as module or standalone `.tf` files).

---

**5. Monitoring and Alerts:**
- Utilize **CloudWatch Alarms** to alert on Lambda failures or errors in resource scans.
- **SNS alerts** ensure real-time visibility.

---

### ✅ **Final Result:**
You will have an integrated solution that:

- Automatically scans AWS resources daily.
- Stores inventory data in DynamoDB for fast retrieval and analysis.
- Sends automated real-time inventory reports via SNS.
- Ensures infrastructure reproducibility and consistency through Terraform.

This structured approach enables maintainable, secure, and efficient AWS resource inventory management, aligned with your existing infrastructure.