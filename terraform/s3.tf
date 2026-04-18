# =============================================================================
# S3 — knowledge bucket, public access block, placeholder prefix keys
# =============================================================================

# aws_s3_bucket.knowledge_assistant_docs
resource "aws_s3_bucket" "knowledge_assistant_docs" {
  bucket = var.bucket_name

  tags = {
    Name        = "AWS Knowledge Assistant Documents"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# aws_s3_bucket_public_access_block.knowledge_assistant_docs
resource "aws_s3_bucket_public_access_block" "knowledge_assistant_docs" {
  bucket = aws_s3_bucket.knowledge_assistant_docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# aws_s3_object.ingest_folder — ensures ingest/ prefix exists
resource "aws_s3_object" "ingest_folder" {
  bucket       = aws_s3_bucket.knowledge_assistant_docs.id
  key          = "ingest/"
  content_type = "application/x-directory"
}

# aws_s3_object.processed_folder — ensures processed/ prefix exists
resource "aws_s3_object" "processed_folder" {
  bucket       = aws_s3_bucket.knowledge_assistant_docs.id
  key          = "processed/"
  content_type = "application/x-directory"
}
