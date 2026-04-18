# =============================================================================
# Frontend build artifact — config.js with API endpoint from API Gateway
# =============================================================================

# local_file.frontend_api_config — ../frontend/config/config.js
resource "local_file" "frontend_api_config" {
  content = <<-EOT
window.APP_CONFIG = {
  apiEndpoint: "${aws_apigatewayv2_api.query_api.api_endpoint}/prod/ask"
};
EOT

  filename = "${path.module}/../frontend/config/config.js"
}
