# =============================================================================
# OpenSearch Serverless — VECTORSEARCH collection (kb-vector) and policies
# =============================================================================

# -----------------------------------------------------------------------------
# Security policies — encryption, network (public), data access (IAM principals)
# -----------------------------------------------------------------------------
# aws_opensearchserverless_security_policy.encryption
resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.collection_name}-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.collection_name}"
        ]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

# aws_opensearchserverless_security_policy.network
resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.collection_name}-network"
  type = "network"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.collection_name}"
          ]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])
}

# aws_opensearchserverless_access_policy.data_access — collection + index rules
resource "aws_opensearchserverless_access_policy" "data_access" {
  name = "${var.collection_name}-data-access"
  type = "data"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.collection_name}"
          ]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems"
          ]
          ResourceType = "collection"
        },
        {
          Resource = [
            "index/${var.collection_name}/*"
          ]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument"
          ]
          ResourceType = "index"
        }
      ]
      Principal = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  ])
}

# -----------------------------------------------------------------------------
# Data source — current AWS account (used in access policy principals)
# -----------------------------------------------------------------------------
# data.aws_caller_identity.current
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# Collection — VECTORSEARCH; depends on policies above
# -----------------------------------------------------------------------------
# aws_opensearchserverless_collection.kb_vector
resource "aws_opensearchserverless_collection" "kb_vector" {
  name = var.collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data_access
  ]
}
