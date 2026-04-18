# =============================================================================
# Input variables
# =============================================================================

# Core / region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Storage
variable "bucket_name" {
  description = "Globally unique S3 bucket name for knowledge assistant documents (set in terraform.tfvars; see terraform.tfvars.example)."
  type        = string
}

# OpenSearch Serverless
variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection"
  type        = string
  default     = "kb-vector"
}

# Amazon Bedrock (query generation)
variable "gen_inference_profile_id" {
  description = "Bedrock inference profile ID or ARN for generation (use an active regional profile, e.g. Claude Sonnet 4). If empty, code falls back to GEN_MODEL_ID."
  type        = string
  default     = "us.anthropic.claude-sonnet-4-20250514-v1:0"
}
