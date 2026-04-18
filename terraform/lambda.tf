resource "aws_lambda_function" "doc_ingestor" {
  function_name    = "aws-ai-assistant-doc-ingestor"
  role             = aws_iam_role.doc_ingestor_role.arn
  filename         = data.archive_file.doc_ingestor_zip.output_path
  source_code_hash = data.archive_file.doc_ingestor_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_deps.arn]
  handler          = "doc_ingestor.handler"
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

resource "aws_lambda_function" "query_processor" {
  function_name    = "aws-ai-assistant-query-processor"
  role             = aws_iam_role.query_processor_role.arn
  filename         = data.archive_file.query_processor_zip.output_path
  source_code_hash = data.archive_file.query_processor_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_deps.arn]
  handler          = "query_processor.handler"
  runtime          = "python3.11"
  architectures    = ["x86_64"]

  timeout     = 60
  memory_size = 512

  environment {
    variables = {
      BEDROCK_REGION           = var.aws_region
      OPENSEARCH_ENDPOINT      = aws_opensearchserverless_collection.kb_vector.collection_endpoint
      OPENSEARCH_INDEX         = "kb_chunks"
      EMBED_MODEL_ID           = "amazon.titan-embed-text-v2:0"
      GEN_MODEL_ID             = "anthropic.claude-3-5-sonnet-20241022-v2:0"
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

resource "aws_s3_bucket_notification" "doc_ingestor_trigger" {
  bucket = aws_s3_bucket.knowledge_assistant_docs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.doc_ingestor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "ingest/"
  }

  depends_on = [aws_lambda_permission.allow_s3_doc_ingestor]
}

resource "aws_lambda_permission" "allow_s3_doc_ingestor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.doc_ingestor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.knowledge_assistant_docs.arn
}
