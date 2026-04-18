# =============================================================================
# Lambda functions and triggers (doc ingest, query API, whitepaper schedule)
# =============================================================================

# -----------------------------------------------------------------------------
# aws_lambda_function.doc_ingestor — embed and index S3 uploads under ingest/
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "doc_ingestor" {
  function_name    = "aws-ai-assistant-doc-ingestor"
  role             = aws_iam_role.doc_ingestor_role.arn
  filename         = data.archive_file.doc_ingestor_zip.output_path
  source_code_hash = data.archive_file.doc_ingestor_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_deps.arn]
  handler          = "doc_ingestor.main.handler"
  runtime          = "python3.11"
  architectures    = ["x86_64"]

  timeout     = 300
  memory_size = 512

  environment {
    variables = {
      BEDROCK_REGION      = var.aws_region
      OPENSEARCH_ENDPOINT = aws_opensearchserverless_collection.kb_vector.collection_endpoint
      OPENSEARCH_INDEX    = "kb_chunks"
      EMBED_MODEL_ID      = "amazon.titan-embed-text-v2:0"
    }
  }

  depends_on = [
    aws_opensearchserverless_collection.kb_vector
  ]

  tags = {
    Name        = "AWS AI Assistant Doc Ingestor"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# -----------------------------------------------------------------------------
# aws_lambda_function.query_processor — RAG query handler for API Gateway /ask
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "query_processor" {
  function_name    = "aws-ai-assistant-query-processor"
  role             = aws_iam_role.query_processor_role.arn
  filename         = data.archive_file.query_processor_zip.output_path
  source_code_hash = data.archive_file.query_processor_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_deps.arn]
  handler          = "query_processor.main.handler"
  runtime          = "python3.11"
  architectures    = ["x86_64"]

  timeout     = 60
  memory_size = 512

  environment {
    variables = {
      BEDROCK_REGION           = var.aws_region
      OPENSEARCH_REGION        = var.aws_region
      OPENSEARCH_ENDPOINT      = aws_opensearchserverless_collection.kb_vector.collection_endpoint
      OPENSEARCH_INDEX         = "kb_chunks"
      EMBED_MODEL_ID           = "amazon.titan-embed-text-v2:0"
      GEN_MODEL_ID             = "anthropic.claude-sonnet-4-20250514-v1:0"
      GEN_INFERENCE_PROFILE_ID = var.gen_inference_profile_id
    }
  }

  depends_on = [
    aws_opensearchserverless_collection.kb_vector
  ]

  tags = {
    Name        = "AWS AI Assistant Query Processor"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# -----------------------------------------------------------------------------
# S3 → Lambda: invoke doc_ingestor on new objects (ingest/ prefix)
# -----------------------------------------------------------------------------
# aws_s3_bucket_notification.doc_ingestor_trigger
resource "aws_s3_bucket_notification" "doc_ingestor_trigger" {
  bucket = aws_s3_bucket.knowledge_assistant_docs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.doc_ingestor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "ingest/"
  }

  depends_on = [aws_lambda_permission.allow_s3_doc_ingestor]
}

# aws_lambda_permission.allow_s3_doc_ingestor — S3 may invoke doc_ingestor
resource "aws_lambda_permission" "allow_s3_doc_ingestor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.doc_ingestor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.knowledge_assistant_docs.arn
}

# -----------------------------------------------------------------------------
# aws_lambda_function.whitepaper_scheduler — weekly fetch into S3 ingest/
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "whitepaper_scheduler" {
  function_name    = "aws-ai-assistant-whitepaper-scheduler"
  role             = aws_iam_role.whitepaper_scheduler_role.arn
  filename         = data.archive_file.whitepaper_scheduler_zip.output_path
  source_code_hash = data.archive_file.whitepaper_scheduler_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_deps.arn]
  handler          = "whitepaper_scheduler.handler"
  runtime          = "python3.11"
  architectures    = ["x86_64"]

  timeout     = 120
  memory_size = 256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.knowledge_assistant_docs.id
    }
  }

  tags = {
    Name        = "AWS AI Assistant Whitepaper Scheduler"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# -----------------------------------------------------------------------------
# EventBridge → Lambda: Sunday 00:00 UTC whitepaper_scheduler
# -----------------------------------------------------------------------------
# aws_cloudwatch_event_rule.whitepaper_scheduler_weekly
resource "aws_cloudwatch_event_rule" "whitepaper_scheduler_weekly" {
  name                = "aws-ai-assistant-whitepaper-weekly"
  description         = "Trigger whitepaper_scheduler every Sunday at 00:00 UTC"
  schedule_expression = "cron(0 0 ? * SUN *)"
}

# aws_cloudwatch_event_target.whitepaper_scheduler
resource "aws_cloudwatch_event_target" "whitepaper_scheduler" {
  rule      = aws_cloudwatch_event_rule.whitepaper_scheduler_weekly.name
  target_id = "WhitepaperSchedulerLambda"
  arn       = aws_lambda_function.whitepaper_scheduler.arn

  depends_on = [aws_lambda_permission.allow_eventbridge_whitepaper_scheduler]
}

# aws_lambda_permission.allow_eventbridge_whitepaper_scheduler
resource "aws_lambda_permission" "allow_eventbridge_whitepaper_scheduler" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.whitepaper_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.whitepaper_scheduler_weekly.arn
}
