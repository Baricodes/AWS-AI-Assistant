import os

import boto3
import requests
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]


def already_ingested(bucket, key):
    try:
        s3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in ("404", "403"):
            return False
        raise


WHITEPAPERS = [
    {
        "url": "https://docs.aws.amazon.com/wellarchitected/latest/framework/wellarchitected-framework.pdf",
        "name": "well-architected-framework.pdf",
    },
    {
        "url": "https://d1.awsstatic.com/whitepapers/aws-overview.pdf",
        "name": "aws-overview.pdf",
    },
    {
        "url": "https://docs.aws.amazon.com/whitepapers/latest/aws-security-best-practices/aws-security-best-practices.pdf",
        "name": "aws-security-best-practices.pdf",
    },
]


def handler(event, context):
    results = []
    for paper in WHITEPAPERS:
        try:
            s3_key = f"ingest/whitepapers/{paper['name']}"
            if already_ingested(BUCKET, s3_key):
                print(f"Skipping {paper['name']} - already ingested")
                continue

            print(f"Fetching {paper['name']} from {paper['url']}")
            response = requests.get(paper["url"], timeout=30)
            response.raise_for_status()

            s3.put_object(
                Bucket=BUCKET,
                Key=s3_key,
                Body=response.content,
                ContentType="application/pdf",
            )
            print(f"Uploaded {paper['name']} to s3://{BUCKET}/{s3_key}")
            results.append({"paper": paper["name"], "status": "success"})

        except Exception as e:
            print(f"Failed to fetch {paper['name']}: {e}")
            results.append(
                {"paper": paper["name"], "status": "failed", "error": str(e)}
            )

    return {"processed": results}
