# =============================================================================
# Lambda packaging: source file sets, zips, shared layer (pip deps)
# =============================================================================

# -----------------------------------------------------------------------------
# Locals — which paths to include in function zip archives
# -----------------------------------------------------------------------------
locals {
  lambda_src_root = "${path.module}/lambda"

  doc_ingestor_rel_paths = toset([
    for f in fileset("${local.lambda_src_root}/doc_ingestor", "**") : f
    if !can(regex("__pycache__/", f)) && !can(regex("\\.pyc$", f))
  ])

  query_processor_rel_paths = toset([
    for f in fileset("${local.lambda_src_root}/query_processor", "**") : f
    if !can(regex("__pycache__/", f)) && !can(regex("\\.pyc$", f))
  ])

  common_rel_paths = toset([
    for f in fileset("${local.lambda_src_root}/common", "**") : f
    if !can(regex("__pycache__/", f)) && !can(regex("\\.pyc$", f))
  ])
}

# -----------------------------------------------------------------------------
# Layer: pip install into .layer_content, then zip for aws_lambda_layer_version
# -----------------------------------------------------------------------------
# null_resource.lambda_layer_deps — installs lambda/layer_requirements.txt
resource "null_resource" "lambda_layer_deps" {
  triggers = {
    requirements = filemd5("${path.module}/lambda/layer_requirements.txt")
  }

  provisioner "local-exec" {
    command = "pip install -r ${path.module}/lambda/layer_requirements.txt -t ${path.module}/lambda/.layer_content/python --upgrade"
  }
}

# data.archive_file.lambda_deps_layer_zip — .build/lambda_deps_layer.zip
data "archive_file" "lambda_deps_layer_zip" {
  depends_on = [null_resource.lambda_layer_deps]

  type        = "zip"
  source_dir  = "${path.module}/lambda/.layer_content"
  output_path = "${path.module}/.build/lambda_deps_layer.zip"
}

# -----------------------------------------------------------------------------
# Function bundles — doc_ingestor, query_processor, whitepaper_scheduler
# -----------------------------------------------------------------------------
# data.archive_file.doc_ingestor_zip — doc_ingestor + common
data "archive_file" "doc_ingestor_zip" {
  type        = "zip"
  output_path = "${path.module}/.build/doc_ingestor.zip"

  dynamic "source" {
    for_each = local.doc_ingestor_rel_paths
    content {
      content  = file("${local.lambda_src_root}/doc_ingestor/${source.value}")
      filename = "doc_ingestor/${source.value}"
    }
  }

  dynamic "source" {
    for_each = local.common_rel_paths
    content {
      content  = file("${local.lambda_src_root}/common/${source.value}")
      filename = "common/${source.value}"
    }
  }
}

# data.archive_file.query_processor_zip — query_processor + common
data "archive_file" "query_processor_zip" {
  type        = "zip"
  output_path = "${path.module}/.build/query_processor.zip"

  dynamic "source" {
    for_each = local.query_processor_rel_paths
    content {
      content  = file("${local.lambda_src_root}/query_processor/${source.value}")
      filename = "query_processor/${source.value}"
    }
  }

  dynamic "source" {
    for_each = local.common_rel_paths
    content {
      content  = file("${local.lambda_src_root}/common/${source.value}")
      filename = "common/${source.value}"
    }
  }
}

# data.archive_file.whitepaper_scheduler_zip — single-file handler
data "archive_file" "whitepaper_scheduler_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/whitepaper_scheduler.py"
  output_path = "${path.module}/.build/whitepaper_scheduler.zip"
}

# aws_lambda_layer_version.lambda_deps — shared Python dependencies layer
resource "aws_lambda_layer_version" "lambda_deps" {
  layer_name               = "aws-ai-assistant-lambda-deps"
  filename                 = data.archive_file.lambda_deps_layer_zip.output_path
  source_code_hash         = filebase64sha256(data.archive_file.lambda_deps_layer_zip.output_path)
  compatible_runtimes      = ["python3.11"]
  compatible_architectures = ["x86_64"]
}
