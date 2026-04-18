# AWS AI Assistant - Serverless Knowledge Base with RAG

A serverless AI-powered knowledge assistant built on AWS that enables document ingestion, vector search, and intelligent question-answering using Amazon Bedrock, OpenSearch Serverless, and Lambda functions.

**Quick start:** Configure AWS credentials for `us-east-1`, enable the Bedrock models listed under [Bedrock Model Access](#bedrock-model-access), run `terraform init` and `terraform apply` from `terraform/`, generate `frontend/config/config.js` from the `http_api_ask_endpoint` output ([Deploy Infrastructure](#5-deploy-infrastructure)), upload a `.txt` file to `s3://<bucket>/ingest/`, then `POST` JSON `{"question":"..."}` to that URL.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## 🎯 Overview

The AWS AI Assistant is a Retrieval-Augmented Generation (RAG) system that allows you to upload documents to S3, automatically process and index them using vector embeddings, and query them through a natural language interface. The system uses Amazon Bedrock for both embedding generation and LLM-based question answering, OpenSearch Serverless for efficient vector similarity search, and Lambda functions for serverless processing.

### Workflow/Process

1. **Document Ingestion**: Upload documents to the S3 `ingest/` folder, which triggers the `doc_ingestor` Lambda function
2. **Processing**: The Lambda function chunks the document text, generates embeddings using Amazon Bedrock Titan Embed model, and indexes chunks with metadata into OpenSearch Serverless
3. **Query Processing**: Users submit questions via the API Gateway endpoint, which triggers the `query_processor` Lambda function
4. **Answer Generation**: The query is embedded, similar document chunks are retrieved via vector search, and an answer is generated using Claude via Bedrock with the retrieved context

## 🏗️ Architecture

The system is built using a serverless architecture: each handler is a **Python 3.11 zip** artifact plus a **shared Lambda layer** for `opensearch-py` and `requests-aws4auth` (built when Terraform runs).

### Visual Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (HTML/JS)                        │
│              Static web interface for queries                │
└──────────────────────┬──────────────────────────────────────┘
                       │ HTTP
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  API Gateway (HTTP API)                     │
│              POST /prod/ask endpoint                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│          query_processor Lambda (zip + deps layer)          │
│  • Embeds query via Bedrock                                  │
│  • Vector search in OpenSearch                               │
│  • Generates answer via Bedrock Claude                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                              │
        ▼                              ▼
┌───────────────┐            ┌──────────────────┐
│   Bedrock     │            │ OpenSearch        │
│  (Embeddings  │            │ Serverless        │
│   & Claude)   │            │ (Vector Store)    │
└───────────────┘            └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    S3 Bucket                                 │
│  • ingest/ prefix (S3 events trigger ingestion)               │
│  • objects remain in place after indexing                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ S3 Event
                       ▼
┌─────────────────────────────────────────────────────────────┐
│          doc_ingestor Lambda (zip + deps layer)              │
│  • Downloads document from S3                               │
│  • Chunks text                                               │
│  • Generates embeddings via Bedrock                         │
│  • Indexes to OpenSearch                                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                              │
        ▼                              ▼
┌───────────────┐            ┌──────────────────┐
│   Bedrock     │            │ OpenSearch        │
│  (Embeddings) │            │ Serverless        │
└───────────────┘            └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                         DynamoDB                             │
│   Table provisioned (not used by current Lambda handlers)  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Document Ingestion Flow**:
   - Document uploaded to S3 `ingest/` folder triggers `doc_ingestor` Lambda
   - Lambda downloads document, chunks text into ~1200 character segments
   - Each chunk is embedded using Amazon Titan Embed Text v2 model (1024 dimensions)
   - Chunks with embeddings and metadata are indexed into OpenSearch `kb_chunks` index

2. **Query Processing Flow**:
   - User submits question via API Gateway `/ask` endpoint
   - `query_processor` Lambda embeds the question using the same embedding model
   - Vector similarity search (kNN) retrieves top 5 most relevant chunks from OpenSearch
   - Retrieved context is passed to Claude 3.5 Sonnet via Bedrock with a system prompt
   - Generated answer with source citations is returned to the user

### Components

- **S3 Bucket**: Uploads under the `ingest/` prefix trigger `doc_ingestor`; processed content is indexed in OpenSearch and the S3 object is left in place (no automatic move to another prefix)
- **doc_ingestor Lambda**: Python 3.11 zip package plus shared dependency layer; processes S3 uploads, chunks text, generates embeddings, and indexes to OpenSearch
- **query_processor Lambda**: Python 3.11 zip package plus shared dependency layer; handles user queries, vector search, and answer generation
- **OpenSearch Serverless**: Vector database for storing and searching document embeddings using kNN search
- **API Gateway**: HTTP API providing REST endpoint for querying the knowledge base
- **DynamoDB**: A table is created by Terraform for optional future use; the current `doc_ingestor` and `query_processor` code paths do not read or write it
- **Amazon Bedrock**: Provides embedding generation (Titan Embed) and text generation (Claude 3.5 Sonnet)
- **Frontend**: Static web interface for interacting with the knowledge assistant

## ✨ Features

- 🔄 **Automatic Document Processing**: Upload documents to S3 and they're automatically chunked, embedded, and indexed
- 🤖 **AI-Powered Q&A**: Ask natural language questions and get answers based on your document content
- 📧 **Vector Search**: Efficient similarity search using OpenSearch Serverless with kNN capabilities
- 📊 **Source Citations**: Answers include citations to source document chunks
- 🎯 **Serverless Architecture**: Fully serverless with Lambda, API Gateway, and managed services
- 🚀 **Terraform-Built Lambdas**: Each handler is zipped with the `archive_file` data source into `terraform/.build/`; a shared Lambda layer carries OpenSearch client libraries (installed via `pip` when Terraform plans)
- 🔒 **Secure building blocks**: IAM roles for Lambdas plus OpenSearch encryption and access policies; add API auth and stricter network rules before production

## 📦 Prerequisites

Before you begin, ensure you have the following:

### Required Tools

- **AWS CLI** (v2.x) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (>= 1.0) - [Installation Guide](https://developer.hashicorp.com/terraform/downloads)
- **Python 3** (3.9+) with **pip** - [Installation Guide](https://www.python.org/downloads/) (used when Terraform runs `plan`/`apply` to materialize the dependency layer)

### AWS Account Requirements

- An AWS account with appropriate permissions
- AWS credentials configured (via `aws configure` or environment variables)
- Access to the following AWS services:
  - Amazon S3
  - AWS Lambda
  - Amazon OpenSearch Serverless
  - Amazon API Gateway
  - Amazon DynamoDB
  - Amazon Bedrock (with model access enabled)
  - AWS IAM

### Bedrock Model Access

You need to enable access to the following Bedrock models in your AWS account:
- **Amazon Titan Embed Text v2** (`amazon.titan-embed-text-v2:0`) - for embeddings
- **Anthropic Claude 3.5 Sonnet** (`anthropic.claude-3-5-sonnet-20241022-v2:0`) - for answer generation

To enable model access:
1. Go to AWS Bedrock console
2. Navigate to "Model access" in the left sidebar
3. Enable the required models

**Note**: If using Bedrock inference profiles (for on-demand models), you may need to provide the inference profile ID during deployment.

**Tip**: If you need model info:
- Use the AWS CLI: `aws bedrock list-foundation-models`
- Query the Bedrock API programmatically
- Check AWS documentation

## 🚀 Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd AWS-AI-Assitant
```

### 2. Configure AWS Credentials

Ensure your AWS credentials are configured:

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

Or set environment variables:

```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_DEFAULT_REGION=us-east-1
```

**Note**: The project uses `us-east-1` as the AWS region. Do not set `AWS_REGION` as an environment variable as it's reserved.

### 3. Verify Prerequisites

Verify all required tools are installed:

```bash
aws --version
terraform version
python3 --version
python3 -m pip --version
```

### 4. Enable Bedrock Model Access

1. Open the [AWS Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Navigate to "Model access" in the left sidebar
3. Enable access to:
   - Amazon Titan Embed Text v2
   - Anthropic Claude 3.5 Sonnet

### 5. Deploy Infrastructure

Lambda deployment packages are produced by Terraform:

- **`doc_ingestor`** and **`query_processor`** are **Python packages** under `terraform/lambda/doc_ingestor/` and `terraform/lambda/query_processor/`, each zipped from the shared `lambda/` directory via **`archive_file`** with path excludes so only one package lands in each zip. Changing sources updates the hash and the function on apply.
- Third-party imports (`opensearch-py`, `requests-aws4auth`, `pypdf`) are packaged in a **shared Lambda layer**; `terraform plan` / `apply` runs a small helper that `pip install`s them into `terraform/lambda/.layer_content/` (Linux-compatible wheels when possible) and zips that tree with `archive_file` as `terraform/.build/lambda_deps_layer.zip`.

From the **`terraform/`** directory:

```bash
terraform init
terraform apply
# If you use a Bedrock inference profile for generation, pass:
# terraform apply -var='gen_inference_profile_id=<PROFILE_ID_OR_ARN>'
```

**Requirements**: Network access for `terraform init` (providers) and for `pip` on the machine running Terraform when the layer is installed or when `terraform/lambda/layer_requirements.txt` changes.

Write the frontend API URL (after apply):

```bash
API_URL=$(cd terraform && terraform output -raw http_api_ask_endpoint)
mkdir -p frontend/config
printf '%s\n' "window.APP_CONFIG = { apiEndpoint: \"$API_URL\" };" > frontend/config/config.js
```

The `kb_chunks` OpenSearch index is created on first Lambda run if it does not already exist.

**Note**: Initial deployment takes approximately 10-15 minutes.

To tear down: empty the S3 document bucket (including versions) if `terraform destroy` reports it is not empty, then run `terraform destroy` from `terraform/`.

## ⚙️ Configuration

### Terraform Variables

Key variables you can configure in `terraform/variables.tf`:

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for all resources | `us-east-1` |
| `bucket_name` | S3 bucket name for documents | `aws-knowledge-assistant-docs-east1-232` |
| `table_name` | DynamoDB table name | `KnowledgeBase` |
| `collection_name` | OpenSearch Serverless collection name | `kb-vector` |
| `gen_inference_profile_id` | Bedrock inference profile ID/ARN | `""` (optional) |

### Lambda Environment Variables

Terraform sets the variables below on each function. The Python handlers also read optional variables (`LOG_LEVEL`, `OPENSEARCH_REGION`, `CORS_ALLOW_ORIGIN`) that are **not** set in `terraform/lambda.tf` today; those fall back to code defaults.

**doc_ingestor Lambda** (set by Terraform):
- `BEDROCK_REGION`: Bedrock region (from `var.aws_region`)
- `EMBED_MODEL_ID`: Embedding model ID (`amazon.titan-embed-text-v2:0`)
- `OPENSEARCH_ENDPOINT`: OpenSearch Serverless collection endpoint
- `OPENSEARCH_INDEX`: Index name (`kb_chunks`)

**doc_ingestor Lambda** (optional; handler default if unset):
- `LOG_LEVEL`: Logging level (`INFO`)

**query_processor Lambda** (set by Terraform):
- `BEDROCK_REGION`: Bedrock region (from `var.aws_region`)
- `EMBED_MODEL_ID`: Embedding model ID (`amazon.titan-embed-text-v2:0`)
- `GEN_MODEL_ID`: Generation model ID (`anthropic.claude-3-5-sonnet-20241022-v2:0`)
- `GEN_INFERENCE_PROFILE_ID`: Bedrock inference profile ID or ARN (optional; empty string falls back to `GEN_MODEL_ID` in code)
- `OPENSEARCH_ENDPOINT`: OpenSearch Serverless collection endpoint
- `OPENSEARCH_INDEX`: Index name (`kb_chunks`)

**query_processor Lambda** (optional; handler default if unset):
- `OPENSEARCH_REGION`: Region used for SigV4 to OpenSearch Serverless (`us-east-1`)
- `CORS_ALLOW_ORIGIN`: Value for `Access-Control-Allow-Origin` on Lambda responses (`*`)
- `LOG_LEVEL`: Logging level (`INFO`)

HTTP API CORS is also configured on API Gateway in `terraform/api_gateway.tf` (`allow_origins = ["*"]` for `POST` and `OPTIONS` on `/ask`).

### OpenSearch Index Configuration

The OpenSearch index `kb_chunks` is configured with:
- **Embedding dimension**: 1024 (matches Titan Embed Text v2)
- **Similarity space**: Cosine similarity
- **Algorithm**: HNSW with FAISS engine
- **Compression**: 16x on-disk compression

## 🚢 Deployment

### Initial deployment

Follow **Deploy Infrastructure** (run `terraform apply` from `terraform/`, write `frontend/config/config.js`).

### Update Lambda code only

Edit `terraform/lambda/doc_ingestor/` or `terraform/lambda/query_processor/`, then from **`terraform/`**:

```bash
terraform apply
```

Terraform rebuilds the `archive_file` zips and updates the functions when the source hash changes.

### Terraform only (no code edits)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 📖 Usage

### Document Ingestion

Upload documents to the S3 bucket's `ingest/` folder to automatically trigger processing:

```bash
# Get bucket name from Terraform outputs
BUCKET_NAME=$(cd terraform && terraform output -raw s3_bucket_name)

# Upload a document
aws s3 cp your-document.txt s3://$BUCKET_NAME/ingest/your-document.txt
```

The `doc_ingestor` Lambda will automatically:
- Download the document
- Chunk the text (~1200 characters per chunk)
- Generate embeddings for each chunk
- Index chunks to OpenSearch

**Supported formats**: Plain text files (.txt). The system processes UTF-8 text content.

### Querying the Knowledge Base

#### Via API Gateway

Query the API using curl:

```bash
# Get API endpoint from Terraform outputs
API_URL=$(cd terraform && terraform output -raw http_api_ask_endpoint)

# Send a query
curl -X POST $API_URL \
  -H 'Content-Type: application/json' \
  -d '{"question": "What is AWS Lambda?"}'
```

Response format:

```json
{
  "answer": "AWS Lambda is a serverless compute service...",
  "sources": [
    {
      "snippet_index": 1,
      "text": "AWS Lambda is a...",
      "source": "s3://bucket-name/ingest/document.txt",
      "score": 0.95
    }
  ]
}
```

#### Via Web Interface

1. Open `frontend/html/index.html` in a web browser
2. The frontend automatically loads the API endpoint from `frontend/config/config.js`
3. Type your question in the input field and press Enter
4. View the answer with source citations

**Note**: Generate `frontend/config/config.js` after Terraform apply (see **Deploy Infrastructure** above), or set `apiEndpoint` manually to your API URL.

### Viewing Results

**S3 Bucket**: After ingestion, objects remain under the `ingest/` prefix:

```bash
aws s3 ls s3://$BUCKET_NAME/ingest/
```

**OpenSearch**: Query the index directly (requires AWS credentials):

```bash
# Get OpenSearch endpoint
OS_ENDPOINT=$(cd terraform && terraform output -raw opensearch_collection_endpoint)

# Use OpenSearch Dashboards (recommended)
# Access via: https://<dashboard-endpoint>
DASHBOARD_URL=$(cd terraform && terraform output -raw opensearch_dashboard_url)
```

**CloudWatch Logs**: View Lambda execution logs:

```bash
# doc_ingestor logs
aws logs tail /aws/lambda/aws-ai-assistant-doc-ingestor --follow --region us-east-1

# query_processor logs
aws logs tail /aws/lambda/aws-ai-assistant-query-processor --follow --region us-east-1
```

**DynamoDB**: Terraform creates a table (outputs: `dynamodb_table_name`), but the current Lambdas do not use it, so scans will typically be empty unless you add your own writers:

```bash
TABLE_NAME=$(cd terraform && terraform output -raw dynamodb_table_name)
aws dynamodb scan --table-name $TABLE_NAME --region us-east-1
```

### Testing the Deployment

1. **Upload a test document**:
   ```bash
   echo "AWS Lambda is a serverless compute service that runs your code in response to events." > test.txt
   aws s3 cp test.txt s3://$BUCKET_NAME/ingest/test.txt
   ```

2. **Wait for processing** (check CloudWatch logs):
   ```bash
   aws logs tail /aws/lambda/aws-ai-assistant-doc-ingestor --follow
   ```

3. **Query the knowledge base**:
   ```bash
   curl -X POST $API_URL \
     -H 'Content-Type: application/json' \
     -d '{"question": "What is AWS Lambda?"}'
   ```

**Important Note**: Allow 1-2 minutes after document upload for processing to complete before querying.

## 📁 Project Structure

```
AWS-AI-Assitant/
├── terraform/
│   ├── .build/                    # Lambda zips from archive_file (gitignored)
│   ├── main.tf                    # Terraform provider configuration
│   ├── variables.tf               # Terraform variables
│   ├── outputs.tf                 # Terraform outputs
│   ├── api_gateway.tf             # API Gateway configuration
│   ├── dynamodb.tf                # DynamoDB table
│   ├── iam.tf                     # IAM roles and policies
│   ├── lambda.tf                  # Lambda functions
│   ├── lambda_packages.tf         # archive_file + dependency layer packaging
│   ├── lambda/                    # Lambda handler source (Python)
│   │   ├── doc_ingestor/           # ingest Lambda package (handler: doc_ingestor.handler)
│   │   │   ├── __init__.py
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   ├── clients.py
│   │   │   ├── document_io.py
│   │   │   ├── bedrock_embed.py
│   │   │   ├── opensearch_index.py
│   │   │   └── logging_utils.py
│   │   ├── query_processor/       # query Lambda package (handler: query_processor.handler)
│   │   │   ├── __init__.py
│   │   │   ├── main.py
│   │   │   ├── config.py
│   │   │   ├── clients.py
│   │   │   ├── http_response.py
│   │   │   ├── bedrock_embed.py
│   │   │   ├── bedrock_generate.py
│   │   │   ├── vector_search.py
│   │   │   ├── opensearch_index.py
│   │   │   └── logging_utils.py
│   │   ├── layer_requirements.txt # Layer-only pip deps
│   │   └── install_layer_deps.py  # pip install for layer (Terraform external data source)
│   ├── opensearch.tf              # OpenSearch Serverless
│   └── s3.tf                      # S3 bucket configuration
├── config/
│   └── open_search_index.json     # OpenSearch index configuration
├── frontend/
│   ├── config/
│   │   └── config.js              # Frontend API configuration (auto-generated)
│   ├── css/
│   │   └── style.css              # Frontend styles
│   ├── html/
│   │   └── index.html             # Frontend web interface
│   └── js/
│       └── app.js                 # Frontend JavaScript
├── requirements.txt               # Optional local venv deps (boto3, opensearch-py, requests-aws4auth)
└── README.md                      # This file
```

## 🔧 Troubleshooting

### Deployment Issues

**Issue**: Terraform / `pip` fails while preparing the Lambda layer
- **Solution**: Ensure Python 3 and `pip` work on the machine running Terraform, with network access to PyPI. If manylinux wheels cannot be resolved, the helper falls back to a plain `pip install` into the layer directory.

**Issue**: Lambda fails at runtime with `No module named ...`
- **Solution**: Confirm the Lambda has the `aws-ai-assistant-lambda-deps` layer attached (see `terraform/lambda_packages.tf`). After changing `terraform/lambda/layer_requirements.txt`, run `terraform apply` so the layer is rebuilt and published.

**Issue**: Lambda function update fails
- **Solution**: Check CloudWatch Logs for import errors. Confirm `terraform apply` completed without errors for `aws_lambda_layer_version` and `aws_lambda_function`.

### Runtime Issues

**Issue**: Documents uploaded to S3 are not being processed
- **Solution**: 
  - Verify the document is in the `ingest/` folder (not root of bucket)
  - Check Lambda function logs: `aws logs tail /aws/lambda/aws-ai-assistant-doc-ingestor --follow`
  - Verify S3 event notification is configured (check Terraform `lambda.tf`)
  - Ensure Lambda function has permission to read from S3

**Issue**: Query returns "internal_error"
- **Solution**:
  - Check query_processor Lambda logs: `aws logs tail /aws/lambda/aws-ai-assistant-query-processor --follow`
  - Verify OpenSearch index exists: Check CloudWatch logs for index creation messages
  - Ensure Bedrock model access is enabled
  - Verify API Gateway endpoint is correct

**Issue**: "No 'embedding' found in model response"
- **Solution**: 
  - Verify Bedrock model access is enabled for Titan Embed Text v2
  - Check IAM permissions for Bedrock access
  - Verify the model ID in environment variables matches an enabled model

**Issue**: OpenSearch index creation fails
- **Solution**:
  - Check OpenSearch Serverless collection status in AWS console
  - Verify IAM roles have OpenSearch access policies attached
  - Check collection endpoint is correct in Lambda environment variables

### Common Fixes

**Reset OpenSearch Index**:
```bash
# Delete and recreate index (data will be lost)
# Access OpenSearch via Python script or AWS console
```

**Re-initialize Index**:
The index is created on first Lambda invocation if missing. To recreate it yourself, use the OpenSearch API or console with the mapping in `config/open_search_index.json`.

**Check Lambda Function Status**:
```bash
aws lambda get-function --function-name aws-ai-assistant-doc-ingestor --region us-east-1
aws lambda get-function --function-name aws-ai-assistant-query-processor --region us-east-1
```

**Verify Bedrock Model Access**:
```bash
aws bedrock list-foundation-models --region us-east-1 --query 'modelSummaries[?contains(modelId, `titan-embed`) || contains(modelId, `claude`)].modelId'
```

## 🔒 Security

### Best Practices

- **IAM Roles**: Lambda functions use least-privilege IAM roles with specific permissions for S3, OpenSearch, Bedrock, and DynamoDB access
- **OpenSearch Security**: OpenSearch Serverless uses encryption policies and network policies to secure data at rest and in transit
- **API Gateway**: HTTP API enables CORS for browser calls; there is **no API authorizer** in the default Terraform stack—the `/ask` route is open to anyone who can reach the invoke URL. Restrict access (API keys, JWT, IAM authorizer, WAF, private integration, etc.) before production use.
- **S3 Bucket**: S3 bucket has public access blocked and uses IAM-based access control
- **Secrets Management**: No hardcoded credentials; all authentication uses IAM roles and AWS credentials
- **Deployment packages**: Lambda handlers are zipped by Terraform (`archive_file`); shared dependencies ship in a Lambda layer built with `pip` during `terraform plan` / `apply`
- **Network**: OpenSearch Serverless uses encryption and data-access policies; the included network policy allows **public** access to the collection (`AllowFromPublic = true` in `terraform/opensearch.tf`). Tighten this if your compliance model requires private-only access.

### IAM Permissions Required

The deployment requires IAM permissions to create and manage:
- Lambda functions and their execution roles
- S3 buckets and objects
- OpenSearch Serverless collections, security policies, and access policies
- API Gateway HTTP APIs
- DynamoDB tables
- CloudWatch Logs groups

### Data Privacy

- Documents stored in S3 are private and accessible only via IAM roles
- Embeddings and document chunks in OpenSearch are encrypted at rest
- All API communication uses HTTPS
- No user data is stored outside of AWS services

---

**Note**: This is a serverless application that incurs AWS costs based on usage. Monitor your AWS billing dashboard and set up cost alerts as needed.
