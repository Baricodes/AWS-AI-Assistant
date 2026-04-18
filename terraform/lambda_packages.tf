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
  type             = "zip"
  source_file      = "${path.module}/lambda/doc_ingestor.py"
  output_path      = "${path.module}/.build/doc_ingestor.zip"
  output_file_mode = "0644"
}

data "archive_file" "query_processor_zip" {
  type             = "zip"
  source_file      = "${path.module}/lambda/query_processor.py"
  output_path      = "${path.module}/.build/query_processor.zip"
  output_file_mode = "0644"
}

resource "aws_lambda_layer_version" "lambda_deps" {
  layer_name               = "aws-ai-assistant-lambda-deps"
  filename                 = data.archive_file.lambda_deps_layer_zip.output_path
  source_code_hash         = data.archive_file.lambda_deps_layer_zip.output_base64sha256
  compatible_runtimes      = ["python3.11"]
  compatible_architectures = ["x86_64"]
}
