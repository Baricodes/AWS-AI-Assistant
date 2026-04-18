# =============================================================================
# IAM — Lambda execution roles, inline policies, attachments
# =============================================================================

# -----------------------------------------------------------------------------
# doc_ingestor — logs, S3 read, AOSS, Titan embed
# -----------------------------------------------------------------------------
# aws_iam_role.doc_ingestor_role
resource "aws_iam_role" "doc_ingestor_role" {
  name = "aws-ai-assistant-doc-ingestor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "AWS AI Assistant Doc Ingestor Role"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# aws_iam_policy.doc_ingestor_policy
resource "aws_iam_policy" "doc_ingestor_policy" {
  name        = "aws-ai-assistant-doc-ingestor-policy"
  description = "Policy for doc_ingestor Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.knowledge_assistant_docs.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.kb_vector.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      }
    ]
  })
}

# aws_iam_role_policy_attachment.doc_ingestor_policy
resource "aws_iam_role_policy_attachment" "doc_ingestor_policy" {
  role       = aws_iam_role.doc_ingestor_role.name
  policy_arn = aws_iam_policy.doc_ingestor_policy.arn
}

# -----------------------------------------------------------------------------
# query_processor — logs, AOSS, Bedrock embed + Claude, inference profiles
# -----------------------------------------------------------------------------
# aws_iam_role.query_processor_role
resource "aws_iam_role" "query_processor_role" {
  name = "aws-ai-assistant-query-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "AWS AI Assistant Query Processor Role"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# aws_iam_policy.query_processor_policy
resource "aws_iam_policy" "query_processor_policy" {
  name        = "aws-ai-assistant-query-processor-policy"
  description = "Policy for query_processor Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = aws_opensearchserverless_collection.kb_vector.arn
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-7-sonnet-20250219-v1:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-7-sonnet-20250219-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-20250514-v1:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-20250514-v1:0"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}:*:inference-profile/*",
          "arn:aws:bedrock:*:*:inference-profile/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe",
          "aws-marketplace:Unsubscribe"
        ]
        Resource = "*"
        Condition = {
          "ForAllValues:StringEquals" = {
            "aws-marketplace:ProductId" = [
              "prod-cx7ovbu5wex7g",
              "prod-4dlfvry4v5hbi",
              "prod-4pmewlybdftbs"
            ]
          }
        }
      }
    ]
  })
}

# aws_iam_role_policy_attachment.query_processor_policy
resource "aws_iam_role_policy_attachment" "query_processor_policy" {
  role       = aws_iam_role.query_processor_role.name
  policy_arn = aws_iam_policy.query_processor_policy.arn
}

# -----------------------------------------------------------------------------
# whitepaper_scheduler — logs, S3 ingest/ prefix read-write
# -----------------------------------------------------------------------------
# aws_iam_role.whitepaper_scheduler_role
resource "aws_iam_role" "whitepaper_scheduler_role" {
  name = "aws-ai-assistant-whitepaper-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "AWS AI Assistant Whitepaper Scheduler Role"
    Environment = "production"
    Project     = "aws-knowledge-assistant"
  }
}

# aws_iam_policy.whitepaper_scheduler_policy
resource "aws_iam_policy" "whitepaper_scheduler_policy" {
  name        = "aws-ai-assistant-whitepaper-scheduler-policy"
  description = "Policy for weekly whitepaper fetch Lambda (S3 GetObject/HeadObject, PutObject on ingest/)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:HeadObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.knowledge_assistant_docs.arn}/ingest/*",
          aws_s3_bucket.knowledge_assistant_docs.arn
        ]
      }
    ]
  })
}

# aws_iam_role_policy_attachment.whitepaper_scheduler_policy
resource "aws_iam_role_policy_attachment" "whitepaper_scheduler_policy" {
  role       = aws_iam_role.whitepaper_scheduler_role.name
  policy_arn = aws_iam_policy.whitepaper_scheduler_policy.arn
}
