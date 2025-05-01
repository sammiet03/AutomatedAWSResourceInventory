import boto3
import os
import json
from datetime import datetime

# Custom encoder to handle datetime objects in JSON
class DateTimeEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super(DateTimeEncoder, self).default(obj)

print("[DEBUG] Lambda loaded")

def lambda_handler(event, context):
    print("[DEBUG] Lambda handler started")

    region = os.environ.get("AWS_REGION", "us-east-1")
    table_name = os.environ.get("DYNAMODB_TABLE")
    sns_topic_arn = os.environ.get("SNS_TOPIC_ARN")

    # AWS Clients
    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)

    ec2 = boto3.client("ec2", region_name=region)
    s3 = boto3.client("s3", region_name=region)
    iam = boto3.client("iam", region_name=region)
    r53 = boto3.client("route53", region_name=region)
    cloudfront = boto3.client("cloudfront", region_name=region)
    acm = boto3.client("acm", region_name=region)
    lambda_client = boto3.client("lambda", region_name=region)
    apigateway = boto3.client("apigateway", region_name=region)
    sns = boto3.client("sns", region_name=region)

    resources = []

    try:
        # EC2
        instances = ec2.describe_instances()
        for r in instances["Reservations"]:
            for i in r["Instances"]:
                resources.append({
                    "ResourceId": i["InstanceId"],
                    "Type": "EC2",
                    "Details": json.dumps(i, cls=DateTimeEncoder)
                })

        # S3
        buckets = s3.list_buckets()
        for b in buckets["Buckets"]:
            resources.append({
                "ResourceId": b["Name"],
                "Type": "S3",
                "Details": json.dumps(b, cls=DateTimeEncoder)
            })

        # IAM
        users = iam.list_users()
        for u in users["Users"]:
            resources.append({
                "ResourceId": u["UserName"],
                "Type": "IAM",
                "Details": json.dumps(u, cls=DateTimeEncoder)
            })

        # Route 53
        zones = r53.list_hosted_zones()
        for z in zones["HostedZones"]:
            resources.append({
                "ResourceId": z["Id"],
                "Type": "Route53",
                "Details": json.dumps(z, cls=DateTimeEncoder)
            })

        # CloudFront
        distributions = cloudfront.list_distributions()
        for d in distributions.get("DistributionList", {}).get("Items", []):
            resources.append({
                "ResourceId": d["Id"],
                "Type": "CloudFront",
                "Details": json.dumps(d, cls=DateTimeEncoder)
            })

        # ACM
        certs = acm.list_certificates()
        for cert in certs["CertificateSummaryList"]:
            resources.append({
                "ResourceId": cert["CertificateArn"],
                "Type": "ACM",
                "Details": json.dumps(cert, cls=DateTimeEncoder)
            })

        # Lambda Functions
        functions = lambda_client.list_functions()
        for f in functions["Functions"]:
            resources.append({
                "ResourceId": f["FunctionName"],
                "Type": "Lambda",
                "Details": json.dumps(f, cls=DateTimeEncoder)
            })

        # API Gateway
        apis = apigateway.get_rest_apis()
        for api in apis["items"]:
            resources.append({
                "ResourceId": api["id"],
                "Type": "APIGateway",
                "Details": json.dumps(api, cls=DateTimeEncoder)
            })

        # Write to DynamoDB
        for res in resources:
            table.put_item(Item={
                "ResourceId": res["ResourceId"],
                "Type": res["Type"],
                "Details": res["Details"],
                "Timestamp": datetime.utcnow().isoformat()
            })

        # SNS Notification
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject="Daily AWS Resource Inventory Report",
            Message=f"✅ Inventory scan completed. Resources scanned: {len(resources)}.\nTimestamp: {datetime.utcnow().isoformat()}"
        )

        return {
            "status": "success",
            "resources_scanned": len(resources)
        }

    except Exception as e:
        print(f"[ERROR] {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }
