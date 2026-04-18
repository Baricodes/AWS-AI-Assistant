"""Shared AWS Bedrock and OpenSearch clients (initialized once per runtime)."""

import boto3
from botocore.config import Config as BotoConfig
from opensearchpy import AWSV4SignerAuth, OpenSearch, RequestsHttpConnection

from query_processor import config

bedrock = boto3.client(
    "bedrock-runtime",
    region_name=config.BEDROCK_REGION,
    config=BotoConfig(
        connect_timeout=3,
        read_timeout=25,
        retries={"max_attempts": 3, "mode": "standard"},
    ),
)

session = boto3.Session(region_name=config.OS_REGION)
creds = session.get_credentials()
awsauth = AWSV4SignerAuth(creds, "aoss", region=config.OS_REGION)

os_client = OpenSearch(
    hosts=[{"host": config.ENDPOINT.replace("https://", ""), "port": 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
)
