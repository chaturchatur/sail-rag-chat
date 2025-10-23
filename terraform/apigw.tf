# terraform/apigw.tf
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.project_name}-http-api"
  protocol_type = "HTTP"
}

# Integrations
resource "aws_apigatewayv2_integration" "upload_url" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_upload_url.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "ingest" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "query" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "route_upload_url" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.upload_url.id}"
}

resource "aws_apigatewayv2_route" "route_ingest" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /ingest"
  target    = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_apigatewayv2_route" "route_query" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.query.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to invoke Lambdas
resource "aws_lambda_permission" "apigw_upload_url" {
  statement_id  = "AllowAPIGatewayInvokeUploadURL"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_upload_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_ingest" {
  statement_id  = "AllowAPIGatewayInvokeIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_query" {
  statement_id  = "AllowAPIGatewayInvokeQuery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}