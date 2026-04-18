# AWS AI Assistant - Serverless Knowledge Base with RAG

A serverless AI-powered knowledge assistant built on AWS that enables document ingestion, vector search, and intelligent question-answering using Amazon Bedrock, OpenSearch Serverless, and Lambda functions.

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

The system is built using a serverless architecture with containerized Lambda functions for scalability and flexibility.

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
│          query_processor Lambda (Container)                  │
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
│  • ingest/ folder (triggers ingestion)                      │
│  • processed/ folder (completed documents)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ S3 Event
                       ▼
┌─────────────────────────────────────────────────────────────┐
│          doc_ingestor Lambda (Container)                     │
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
│                    DynamoDB                                  │
│          Knowledge base metadata storage                     │
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

- **S3 Bucket**: Stores documents in `ingest/` folder (triggers processing) and `processed/` folder (completed documents)
- **doc_ingestor Lambda**: Zip deployment package (Python 3.11) that processes S3 uploads, chunks text, generates embeddings, and indexes to OpenSearch
- **query_processor Lambda**: Zip deployment package (Python 3.11) that handles user queries, performs vector search, and generates answers
- **OpenSearch Serverless**: Vector database for storing and searching document embeddings using kNN search
- **API Gateway**: HTTP API providing REST endpoint for querying the knowledge base
- **DynamoDB**: Stores knowledge base metadata and document information
- **Amazon Bedrock**: Provides embedding generation (Titan Embed) and text generation (Claude 3.5 Sonnet)
- **Frontend**: Static web interface for interacting with the knowledge assistant

## ✨ Features

- 🔄 **Automatic Document Processing**: Upload documents to S3 and they're automatically chunked, embedded, and indexed
- 🤖 **AI-Powered Q&A**: Ask natural language questions and get answers based on your document content
- 📧 **Vector Search**: Efficient similarity search using OpenSearch Serverless with kNN capabilities
- 📊 **Source Citations**: Answers include citations to source document chunks
- 🎯 **Serverless Architecture**: Fully serverless with Lambda, API Gateway, and managed services
- 🚀 **Zip-Based Lambdas**: Lambda functions use Python zip bundles; Docker is only used locally to install Linux-compatible dependencies
- 🔒 **Secure**: Uses IAM roles, OpenSearch Serverless security policies, and VPC endpoints

## 📦 Prerequisites

Before you begin, ensure you have the following:

### Required Tools

- **AWS CLI** (v2.x) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Docker** (latest) - [Installation Guide](https://docs.docker.com/get-docker/)
- **Terraform** (>= 1.0) - [Installation Guide](https://developer.hashicorp.com/terraform/downloads)
- **jq** (latest) - [Installation Guide](https://stedolan.github.io/jq/download/)
- **Python 3** (3.9+) - [Installation Guide](https://www.python.org/downloads/)

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
docker --version
terraform version
jq --version
python3 --version
```

### 4. Enable Bedrock Model Access

1. Open the [AWS Bedrock Console](https://console.aws.amazon.com/bedrock/)
2. Navigate to "Model access" in the left sidebar
3. Enable access to:
   - Amazon Titan Embed Text v2
   - Anthropic Claude 3.5 Sonnet

### 5. Deploy Infrastructure

Run the deployment script from the project root:

```bash
cd scripts
./deploy.sh
```

For initial deployment with a Bedrock inference profile (if using on-demand models):

```bash
./deploy.sh --gen-inference-profile-id <PROFILE_ID_OR_ARN>
```

The deployment script will:
1. Check prerequisites
2. Deploy stage-1 Terraform (S3, OpenSearch, IAM, etc.)
3. Build Lambda zip packages (`terraform/lambda_packages/*.zip`) using Docker to install Linux dependencies
4. Apply full Terraform (Lambda functions, API Gateway, etc.)
5. Initialize OpenSearch index
6. Generate frontend configuration

**Note**: Initial deployment takes approximately 10-15 minutes.

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

The Lambda functions use the following environment variables (configured via Terraform):

**doc_ingestor Lambda**:
- `BEDROCK_REGION`: AWS region for Bedrock (default: `us-east-1`)
- `EMBED_MODEL_ID`: Embedding model ID (default: `amazon.titan-embed-text-v2:0`)
- `OPENSEARCH_ENDPOINT`: OpenSearch Serverless collection endpoint
- `OPENSEARCH_INDEX`: Index name (default: `kb_chunks`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

**query_processor Lambda**:
- `BEDROCK_REGION`: AWS region for Bedrock (default: `us-east-1`)
- `OPENSEARCH_REGION`: AWS region for OpenSearch (default: `us-east-1`)
- `EMBED_MODEL_ID`: Embedding model ID (default: `amazon.titan-embed-text-v2:0`)
- `GEN_MODEL_ID`: Generation model ID (default: `anthropic.claude-3-5-sonnet-20241022-v2:0`)
- `GEN_INFERENCE_PROFILE_ID`: Bedrock inference profile ID (optional, for on-demand models)
- `OPENSEARCH_ENDPOINT`: OpenSearch Serverless collection endpoint
- `OPENSEARCH_INDEX`: Index name (default: `kb_chunks`)
- `CORS_ALLOW_ORIGIN`: CORS allowed origin (default: `*`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

### OpenSearch Index Configuration

The OpenSearch index `kb_chunks` is configured with:
- **Embedding dimension**: 1024 (matches Titan Embed Text v2)
- **Similarity space**: Cosine similarity
- **Algorithm**: HNSW with FAISS engine
- **Compression**: 16x on-disk compression

## 🚢 Deployment

### Initial Deployment

Run the deployment script from the project root:

```bash
cd scripts
./deploy.sh
```

This script will:
1. Deploy foundational infrastructure (S3, OpenSearch, IAM roles)
2. Build Lambda zip packages under `terraform/lambda_packages/`
3. Deploy remaining infrastructure (Lambda functions, API Gateway)
4. Initialize OpenSearch index with proper mappings
5. Generate frontend configuration file

### Update Deployment

To update Lambda functions with new code without redeploying infrastructure:

```bash
cd scripts
./deploy.sh --update
```

This skips Terraform deployment and only:
1. Rebuilds Lambda zip packages
2. Updates existing Lambda function code from those zips
3. Waits for functions to become active

### Deployment Options

The deployment script supports several options:

```bash
# Standard deployment
./deploy.sh

# Update mode (skip Terraform, only update Lambdas)
./deploy.sh --update

# Deploy with Bedrock inference profile
./deploy.sh --gen-inference-profile-id <PROFILE_ID_OR_ARN>

# Combine options
./deploy.sh --update --gen-inference-profile-id <PROFILE_ID_OR_ARN>
```

### Manual Deployment (Alternative)

The deployment script builds `terraform/lambda_packages/*.zip` before applying Terraform; **Docker must be running** for that step so dependencies install for Amazon Linux (`linux/amd64`).

To apply only Terraform after those zips already exist:

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

**Note**: The frontend config file is automatically generated during deployment. If you need to update it manually:

```bash
# Update frontend/config/config.js with your API Gateway URL
```

### Viewing Results

**S3 Bucket**: Check the `ingest/` folder for uploaded documents and `processed/` folder for completed processing:

```bash
aws s3 ls s3://$BUCKET_NAME/ingest/
aws s3 ls s3://$BUCKET_NAME/processed/
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

**DynamoDB**: Check knowledge base metadata:

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
├── scripts/
│   ├── deploy.sh                  # Main deployment script
│   └── destroy.sh                 # Teardown script
├── terraform/
│   ├── main.tf                    # Terraform provider configuration
│   ├── variables.tf               # Terraform variables
│   ├── outputs.tf                 # Terraform outputs
│   ├── api_gateway.tf             # API Gateway configuration
│   ├── dynamodb.tf                # DynamoDB table
│   ├── iam.tf                     # IAM roles and policies
│   ├── lambda.tf                  # Lambda functions
│   ├── lambda/                    # Lambda handler source (Python)
│   │   ├── doc_ingestor.py
│   │   └── query_processor.py
│   ├── lambda_packages/           # Built zip bundles (.zip gitignored; created by deploy.sh)
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
├── requirements.txt               # Python dependencies
├── README.md                      # This file
└── READ_ME_FRAMEWORK.md          # README framework template
```

## 🔧 Troubleshooting

### Deployment Issues

**Issue**: Terraform fails because `lambda_packages/*.zip` is missing
- **Solution**: Run `./deploy.sh` from `scripts` so it builds the zips before `terraform apply`. Docker must be running for the pip install step.

**Issue**: Lambda fails at runtime with `No module named ...`
- **Solution**: Rebuild zips on a machine with Docker available (`./deploy.sh --update`) so dependencies are installed for Amazon Linux, not your local OS.

**Issue**: Lambda function update fails
- **Solution**: Confirm `aws lambda update-function-code` completed and check CloudWatch Logs for import errors. Verify the zip was built with the same runtime/architecture as Lambda (the deploy script targets `linux/amd64` to match default Lambda architecture).

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
The deployment script automatically creates the index. To manually recreate:
```bash
cd scripts
# The initialize_opensearch_index function in deploy.sh can be run separately
```

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
- **API Gateway**: HTTP API uses IAM authentication and CORS configuration (configurable via environment variables)
- **S3 Bucket**: S3 bucket has public access blocked and uses IAM-based access control
- **Secrets Management**: No hardcoded credentials; all authentication uses IAM roles and AWS credentials
- **Deployment packages**: Lambda code is uploaded as zip bundles; build locally with Docker for Linux-compatible wheels
- **Network Security**: OpenSearch Serverless uses VPC endpoints and network policies for secure access

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
