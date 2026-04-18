"""Shared AWS / OpenSearch clients (module import initializes once per runtime)."""

import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

from doc_ingestor import config

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name=config.BEDROCK_REGION)

session = boto3.Session()
credentials = session.get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    config.BEDROCK_REGION,
    "aoss",
    session_token=credentials.token,
)

os_client = OpenSearch(
    hosts=[{"host": config.OPENSEARCH_ENDPOINT.replace("https://", ""), "port": 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
)
