#!/bin/bash

# AWS AI Assistant deployment script
# Builds Python Lambda zip packages (Linux/x86_64) and applies Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-east-1"
GEN_INFERENCE_PROFILE_ID_ENV_DEFAULT="${GEN_INFERENCE_PROFILE_ID:-}"

# Resolve repo root and Terraform directory (works regardless of current working directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$REPO_ROOT/terraform"

write_frontend_config() {
    local api_url="$1"
    if [ -z "$api_url" ]; then
        print_warning "API URL not provided; skipping frontend config generation."
        return
    fi
    local cfg_dir="$REPO_ROOT/frontend/config"
    local cfg_file="$cfg_dir/config.js"
    mkdir -p "$cfg_dir"
    cat > "$cfg_file" <<EOF
window.APP_CONFIG = {
  apiEndpoint: "$api_url"
};
EOF
    print_success "Wrote frontend config to $cfg_file"
}

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists aws; then
        missing_tools+=("aws")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("docker")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("terraform")
    fi
    
    if ! command_exists jq; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Get AWS account ID
get_aws_account_id() {
    print_status "Getting AWS account ID..."
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Failed to get AWS account ID. Please check your AWS credentials."
        exit 1
    fi
    print_success "AWS Account ID: $AWS_ACCOUNT_ID"
}

# Deploy core infrastructure first (no Lambda functions yet; zips are built before full apply)
deploy_infrastructure_stage1() {
    print_status "Deploying stage 1 infrastructure (OpenSearch, S3, IAM, etc.)..."
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Target specific resources that Lambda doesn't depend on
    print_status "Creating core infrastructure (S3, OpenSearch, IAM, etc.)..."
    terraform apply -target=aws_dynamodb_table.knowledge_base \
                    -target=aws_s3_bucket.knowledge_assistant_docs \
                    -target=aws_s3_bucket_public_access_block.knowledge_assistant_docs \
                    -target=aws_s3_object.ingest_folder \
                    -target=aws_s3_object.processed_folder \
                    -target=aws_opensearchserverless_security_policy.encryption \
                    -target=aws_opensearchserverless_security_policy.network \
                    -target=aws_opensearchserverless_access_policy.data_access \
                    -target=aws_opensearchserverless_collection.kb_vector \
                    -target=aws_iam_role.doc_ingestor_role \
                    -target=aws_iam_policy.doc_ingestor_policy \
                    -target=aws_iam_role_policy_attachment.doc_ingestor_policy \
                    -target=aws_iam_role.query_processor_role \
                    -target=aws_iam_policy.query_processor_policy \
                    -target=aws_iam_role_policy_attachment.query_processor_policy \
                    -auto-approve
    
    cd - > /dev/null
}

# Deploy remaining Terraform infrastructure
deploy_terraform() {
    print_status "Deploying remaining Terraform infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Apply all resources
    print_status "Applying Terraform..."
    if [ -n "$GEN_INFERENCE_PROFILE_ID" ]; then
        print_status "Using Bedrock inference profile: $GEN_INFERENCE_PROFILE_ID"
        terraform apply -auto-approve \
            -var gen_inference_profile_id="$GEN_INFERENCE_PROFILE_ID"
    else
        print_warning "No Bedrock inference profile ID provided. Some models require it."
        terraform apply -auto-approve
    fi
    
    # Get outputs
    print_status "Getting Terraform outputs..."
    OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)
    API_GATEWAY_URL=$(terraform output -raw api_gateway_query_endpoint)
    # Also try canonical output if present (no fail if missing)
    if command -v terraform >/dev/null 2>&1; then
        if terraform output -raw http_api_ask_endpoint >/dev/null 2>&1; then
            API_GATEWAY_URL=$(terraform output -raw http_api_ask_endpoint)
        fi
    fi
    
    print_success "Terraform deployment completed"
    print_status "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"
    print_status "API Gateway URL: $API_GATEWAY_URL"
    # Generate frontend config
    write_frontend_config "$API_GATEWAY_URL"
    
    cd - > /dev/null
}

# Build a single Lambda deployment package (Linux x86_64, matches default Lambda arch)
build_lambda_zip_package() {
    local module_name="$1"
    local packages_dir="$REPO_ROOT/terraform/lambda_packages"
    local work
    work=$(mktemp -d)

    print_status "Building Lambda zip: ${module_name}..."

    cp "$REPO_ROOT/requirements.txt" "$work/"
    cp "$REPO_ROOT/terraform/lambda/${module_name}.py" "$work/"

    if ! docker run --rm --platform linux/amd64 \
        -v "$work:/var/task" \
        public.ecr.aws/lambda/python:3.11 \
        bash -c "cd /var/task && pip install -r requirements.txt -t . -q"; then
        rm -rf "$work"
        print_error "pip install failed for ${module_name}"
        exit 1
    fi

    find "$work" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    find "$work" -name "*.pyc" -delete 2>/dev/null || true

    mkdir -p "$packages_dir"
    (cd "$work" && zip -r9 "$packages_dir/${module_name}.zip" .)
    rm -rf "$work"
    print_success "Built ${packages_dir}/${module_name}.zip"
}

# Build both Lambda zip packages under terraform/lambda_packages/
build_lambda_zips() {
    build_lambda_zip_package "doc_ingestor"
    build_lambda_zip_package "query_processor"
}

# Update Lambda functions with freshly built zips
update_lambda_functions() {
    print_status "Updating Lambda functions with new deployment packages..."

    local doc_zip="$REPO_ROOT/terraform/lambda_packages/doc_ingestor.zip"
    local qry_zip="$REPO_ROOT/terraform/lambda_packages/query_processor.zip"

    if [ ! -f "$doc_zip" ] || [ ! -f "$qry_zip" ]; then
        print_error "Zip packages not found. Run build step first."
        exit 1
    fi

    local output_file
    print_status "Updating doc_ingestor Lambda function..."
    output_file=$(mktemp)
    if aws lambda update-function-code \
        --function-name aws-ai-assistant-doc-ingestor \
        --zip-file "fileb://${doc_zip}" \
        --region "$AWS_REGION" \
        --no-cli-pager \
        --output json > "$output_file" 2>&1; then
        print_success "doc_ingestor Lambda function updated successfully"
        rm -f "$output_file"
    else
        print_error "Failed to update doc_ingestor Lambda function"
        print_error "AWS CLI output:"
        cat "$output_file" >&2
        rm -f "$output_file"
        exit 1
    fi

    print_status "Updating query_processor Lambda function..."
    output_file=$(mktemp)
    if aws lambda update-function-code \
        --function-name aws-ai-assistant-query-processor \
        --zip-file "fileb://${qry_zip}" \
        --region "$AWS_REGION" \
        --no-cli-pager \
        --output json > "$output_file" 2>&1; then
        print_success "query_processor Lambda function updated successfully"
        rm -f "$output_file"
    else
        print_error "Failed to update query_processor Lambda function"
        print_error "AWS CLI output:"
        cat "$output_file" >&2
        rm -f "$output_file"
        exit 1
    fi

    print_success "All Lambda functions updated successfully"
}

# Wait for Lambda functions to be active
wait_for_lambda_functions() {
    print_status "Waiting for Lambda functions to be active..."
    
    # Wait for doc_ingestor
    print_status "Waiting for doc_ingestor to be active..."
    aws lambda wait function-active --function-name aws-ai-assistant-doc-ingestor --region $AWS_REGION
    
    # Wait for query_processor
    print_status "Waiting for query_processor to be active..."
    aws lambda wait function-active --function-name aws-ai-assistant-query-processor --region $AWS_REGION
    
    print_success "All Lambda functions are active"
}

# Initialize OpenSearch index
initialize_opensearch_index() {
    print_status "Initializing OpenSearch index..."
    
    # Create a temporary Python script to initialize the index
    cat > /tmp/init_opensearch.py << EOF
import os
import json
import boto3
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

# Configuration
OPENSEARCH_ENDPOINT = "$OPENSEARCH_ENDPOINT"
AWS_REGION = "$AWS_REGION"
INDEX_NAME = "kb_chunks"

# Setup OpenSearch client
session = boto3.Session()
credentials = session.get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, AWS_REGION, 'aoss', session_token=credentials.token)

os_client = OpenSearch(
    hosts=[{'host': OPENSEARCH_ENDPOINT.replace('https://',''), 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection
)

# Index mapping from the config file
index_mapping = {
    "settings": {
        "index.knn": True
    },
    "mappings": {
        "properties": {
            "embedding": {
                "type": "knn_vector",
                "dimension": 1024,
                "space_type": "cosinesimil",
                "mode": "on_disk",
                "compression_level": "16x",
                "method": {
                    "name": "hnsw",
                    "engine": "faiss",
                    "parameters": {
                        "m": 16,
                        "ef_construction": 100
                    }
                }
            },
            "chunk_text": {"type": "text"},
            "doc_id": {"type": "keyword"},
            "chunk_id": {"type": "integer"},
            "title": {"type": "text"},
            "section": {"type": "text"},
            "source": {"type": "keyword"},
            "s3_key": {"type": "keyword"},
            "url": {"type": "keyword"},
            "tags": {"type": "keyword"},
            "token_count": {"type": "integer"},
            "created_at": {"type": "date"},
            "updated_at": {"type": "date"}
        }
    }
}

try:
    # Check if index exists
    if os_client.indices.exists(index=INDEX_NAME):
        print(f"Index {INDEX_NAME} already exists")
    else:
        # Create the index
        os_client.indices.create(index=INDEX_NAME, body=index_mapping)
        print(f"Successfully created index {INDEX_NAME}")
except Exception as e:
    print(f"Error creating index: {e}")
    exit(1)
EOF

    # Install required Python packages
    print_status "Installing required Python packages..."
    pip3 install opensearch-py requests-aws4auth boto3 --quiet --no-warn-script-location
    
    # Run the initialization script
    python3 /tmp/init_opensearch.py
    
    # Clean up
    rm /tmp/init_opensearch.py
    
    print_success "OpenSearch index initialized successfully"
}

# Display deployment summary
display_summary() {
    print_success "Deployment completed successfully!"
    echo
    print_status "Deployment Summary:"
    echo "===================="
    echo "• OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"
    echo "• API Gateway URL: $API_GATEWAY_URL"
    echo
    print_status "Test the deployment:"
    echo "• Upload a document to S3 bucket 'aws-knowledge-assistant-docs-east1-232' in the 'ingest/' folder"
    echo "• Query the API: curl -X POST $API_GATEWAY_URL -H 'Content-Type: application/json' -d '{\"question\": \"Your question here\"}'"
    echo
    print_status "Lambda Functions:"
    echo "• doc_ingestor: aws-ai-assistant-doc-ingestor"
    echo "• query_processor: aws-ai-assistant-query-processor"
}

# Parse command-line arguments
parse_arguments() {
    UPDATE_MODE=false
    GEN_INFERENCE_PROFILE_ID_ARG=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update)
                UPDATE_MODE=true
                shift
                ;;
            --gen-inference-profile-id)
                GEN_INFERENCE_PROFILE_ID_ARG="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Usage: $0 [--update] [--gen-inference-profile-id <PROFILE_ID_OR_ARN>]"
                echo "  --update: Skip Terraform deployment and only update Lambda functions"
                echo "  --gen-inference-profile-id: Bedrock inference profile ID/ARN for generation"
                exit 1
                ;;
        esac
    done

    # Determine effective inference profile ID (arg takes precedence over env)
    if [ -n "$GEN_INFERENCE_PROFILE_ID_ARG" ]; then
        GEN_INFERENCE_PROFILE_ID="$GEN_INFERENCE_PROFILE_ID_ARG"
    else
        GEN_INFERENCE_PROFILE_ID="$GEN_INFERENCE_PROFILE_ID_ENV_DEFAULT"
    fi
}

# Deploy infrastructure (Terraform + Lambda updates)
deploy_infrastructure() {
    if [ "$UPDATE_MODE" = false ]; then
        deploy_infrastructure_stage1
        build_lambda_zips
        deploy_terraform
    else
        print_status "Update mode: Skipping Terraform deployment"
        # Get existing outputs from Terraform state
        cd "$TERRAFORM_DIR"
        print_status "Reading existing Terraform outputs..."
        OPENSEARCH_ENDPOINT=$(terraform output -raw opensearch_collection_endpoint)
        API_GATEWAY_URL=$(terraform output -raw api_gateway_query_endpoint)
        if terraform output -raw http_api_ask_endpoint >/dev/null 2>&1; then
            API_GATEWAY_URL=$(terraform output -raw http_api_ask_endpoint)
        fi

        print_status "OpenSearch Endpoint: $OPENSEARCH_ENDPOINT"
        print_status "API Gateway URL: $API_GATEWAY_URL"
        write_frontend_config "$API_GATEWAY_URL"
        cd - > /dev/null
    fi
}

# Main execution
main() {
    print_status "Starting AWS AI Assistant deployment"
    echo "=============================================================="
    
    parse_arguments "$@"
    
    check_prerequisites
    
    if [ "$UPDATE_MODE" = true ]; then
        print_warning "Running in UPDATE MODE - will skip Terraform and only update Lambda functions"
    fi
    
    get_aws_account_id
    deploy_infrastructure
    
    if [ "$UPDATE_MODE" = true ]; then
        build_lambda_zips
        update_lambda_functions
        wait_for_lambda_functions
    else
        print_status "Lambda functions were deployed with Terraform using the built zip packages"
    fi
    
    if [ "$UPDATE_MODE" = false ]; then
        initialize_opensearch_index
    fi
    
    display_summary
}

# Run main function
main "$@"
