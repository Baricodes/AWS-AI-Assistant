# Writes the browser API URL whenever apply runs (frontend/config/config.js is gitignored).
resource "local_file" "frontend_api_config" {
  content = <<-EOT
window.APP_CONFIG = {
  apiEndpoint: "${aws_apigatewayv2_api.query_api.api_endpoint}/prod/ask"
};
EOT

  filename = "${path.module}/../frontend/config/config.js"
}
