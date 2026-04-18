data "external" "lambda_layer_deps" {
  program = [
    "env",
    "MODULE_ROOT=${path.module}",
    "python3",
    "${path.module}/lambda/install_layer_deps.py",
  ]

  query = {
    hash = filesha256("${path.module}/lambda/layer_requirements.txt")
  }
}

data "archive_file" "lambda_deps_layer_zip" {
  depends_on = [data.external.lambda_layer_deps]

  type        = "zip"
  source_dir  = "${path.module}/lambda/.layer_content"
  output_path = "${path.module}/.build/lambda_deps_layer.zip"
}

data "archive_file" "doc_ingestor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/doc_ingestor.zip"
  excludes = [
    "query_processor",
    "whitepaper_scheduler.py",
    "layer_requirements.txt",
    "install_layer_deps.py",
    ".layer_content",
    "**/__pycache__/**",
  ]
}

data "archive_file" "query_processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.build/query_processor.zip"
  excludes = [
    "doc_ingestor",
    "whitepaper_scheduler.py",
    "layer_requirements.txt",
    "install_layer_deps.py",
    ".layer_content",
    "**/__pycache__/**",
  ]
}

data "archive_file" "whitepaper_scheduler_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/whitepaper_scheduler.py"
  output_path = "${path.module}/.build/whitepaper_scheduler.zip"
}

resource "aws_lambda_layer_version" "lambda_deps" {
  layer_name               = "aws-ai-assistant-lambda-deps"
  filename                 = data.archive_file.lambda_deps_layer_zip.output_path
  source_code_hash         = data.archive_file.lambda_deps_layer_zip.output_base64sha256
  compatible_runtimes      = ["python3.11"]
  compatible_architectures = ["x86_64"]
}
