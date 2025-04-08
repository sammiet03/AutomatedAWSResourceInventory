import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    sns = boto3.client('sns')

    table = dynamodb.Table('ResourceInventory')
    sns_topic = 'arn:aws:sns:us-east-1:123456789012:InventoryReports'  # Replace with your actual ARN

    ec2 = boto3.client('ec2')
    s3 = boto3.client('s3')
    iam = boto3.client('iam')

    resources = []

    # EC2 Instances
    instances = ec2.describe_instances()
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            resources.append(f"EC2 Instance: {instance['InstanceId']}")

    # S3 Buckets
    buckets = s3.list_buckets()
    for bucket in buckets['Buckets']:
        resources.append(f"S3 Bucket: {bucket['Name']}")

    # IAM Users
    users = iam.list_users()
    for user in users['Users']:
        resources.append(f"IAM User: {user['UserName']}")

    # Save to DynamoDB
    for resource in resources:
        table.put_item(Item={
            'ResourceId': resource,
            'Timestamp': str(datetime.now())
        })

    # Send SNS Notification
    sns.publish(
        TopicArn=sns_topic,
        Subject="AWS Resource Inventory",
        Message=f"Scanned resources: {len(resources)}"
    )

    return {"status": "success", "scanned": len(resources)}
