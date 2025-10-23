# lambda is faas, function that runs in the cloud when called 
# serverless, no need to manage server, just pay for execution time
# lambda expects code as a zip file

# takes all files from backend/lambdas/get_upload_url/ into zip for deployment
data "archive_file" "upload_url_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../backend/lambdas/get_upload_url"
  output_path = "${path.module}/build/get_upload_url.zip"
}

data "archive_file" "ingest_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../backend/lambdas/ingest"
  output_path = "${path.module}/build/ingest.zip"
}

data "archive_file" "query_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../backend/lambdas/query"
  output_path = "${path.module}/build/query.zip"
}

# lambda function resource
resource "aws_lambda_function" "get_upload_url" {
    function        = "${local.project_name}-get-upload-url"
    rolehandler     = aws_iam_role.lambda_exec.arn                      # iam role gives lmabda permissions
    handler         = "main.handler"                                    # tells lmabda which function to call: handler() in main.py
    runtime         = "python3.11"                                      # python ver lambda uses
    filename        = data.archive_file.upload_url_zip.output_path      # zip file that will contain code
    timeout         = 10                                                # max exec time 
    memory_size     = 256                                               # RAM allocated to fn (MB)
    architectures   = ["x86_64"]                                        # cpu architectures

    layers = [aws_lambda_layer_version.faiss_layer.arn]                 # layer linked to the lambda

    environment {
        variables = {
            BUCKET              = aws_s3_bucket.docs.bucket
            NAMESPACE           = local.namespace
            OPENAI_SECRET_ARN   = aws_secretsmanager_secret.openai_api.arn
            EMBED_MODEL         = local.embed_model
            CHAT_MODEL          = local.chat_model
        }
    }
}

resource "aws_lambda_function" "ingest" {
  function_name = "${local.project_name}-ingest"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.ingest_zip.output_path
  timeout       = 900
  memory_size   = 3072
  architectures = ["x86_64"]

  layers = [aws_lambda_layer_version.faiss_layer.arn]

  environment {
    variables = {
      BUCKET            = aws_s3_bucket.docs.bucket
      NAMESPACE         = local.namespace
      OPENAI_SECRET_ARN = aws_secretsmanager_secret.openai_api.arn
      EMBED_MODEL       = local.embed_model
      CHAT_MODEL        = local.chat_model
    }
  }
}

resource "aws_lambda_function" "query" {
  function_name = "${local.project_name}-query"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "main.handler"
  runtime       = "python3.11"
  filename      = data.archive_file.query_zip.output_path
  timeout       = 60
  memory_size   = 1024
  architectures = ["x86_64"]

  layers = [aws_lambda_layer_version.faiss_layer.arn]

  environment {
    variables = {
      BUCKET            = aws_s3_bucket.docs.bucket
      NAMESPACE         = local.namespace
      OPENAI_SECRET_ARN = aws_secretsmanager_secret.openai_api.arn
      EMBED_MODEL       = local.embed_model
      CHAT_MODEL        = local.chat_model
    }
  }
}