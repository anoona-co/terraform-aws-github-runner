resource "aws_kms_grant" "scale_down" {
  count             = var.encryption.encrypt ? 1 : 0
  name              = "${var.environment}-scale-down"
  key_id            = var.encryption.kms_key_id
  grantee_principal = aws_iam_role.scale_down.arn
  operations        = ["Decrypt"]

  constraints {
    encryption_context_equals = {
      Environment = var.environment
    }
  }
}

resource "aws_lambda_function" "scale_down" {
  filename         = local.lambda_zip
  source_code_hash = filebase64sha256(local.lambda_zip)
  function_name    = "${var.environment}-scale-down"
  role             = aws_iam_role.scale_down.arn
  handler          = "index.scaleDown"
  runtime          = "nodejs12.x"
  timeout          = var.lambda_timeout_scale_down
  tags             = local.tags

  environment {
    variables = {
      ENVIRONMENT                     = var.environment
      KMS_KEY_ID                      = var.encryption.kms_key_id
      ENABLE_ORGANIZATION_RUNNERS     = var.enable_organization_runners
      MINIMUM_RUNNING_TIME_IN_MINUTES = var.minimum_running_time_in_minutes
      GITHUB_APP_KEY_BASE64           = local.github_app_key_base64
      GITHUB_APP_ID                   = var.github_app.id
      GITHUB_APP_CLIENT_ID            = var.github_app.client_id
      GITHUB_APP_CLIENT_SECRET        = local.github_app_client_secret
    }
  }
}

resource "aws_cloudwatch_event_rule" "scale_down" {
  schedule_expression = var.scale_down_schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "scale_down" {
  rule = aws_cloudwatch_event_rule.scale_down.name
  arn  = aws_lambda_function.scale_down.arn
}

resource "aws_lambda_permission" "scale_down" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_down.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down.arn
}

resource "aws_iam_role" "scale_down" {
  name                 = "${var.environment}-action-scale-down-lambda-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role_policy.json
  path                 = local.role_path
  permissions_boundary = var.role_permissions_boundary
  tags                 = local.tags
}

resource "aws_iam_role_policy" "scale_down" {
  name   = "${var.environment}-lambda-scale-down-policy"
  role   = aws_iam_role.scale_down.name
  policy = templatefile("${path.module}/policies/lambda-scale-down.json", {})
}

resource "aws_iam_role_policy" "scale_down_logging" {
  name   = "${var.environment}-lambda-logging"
  role   = aws_iam_role.scale_down.name
  policy = templatefile("${path.module}/policies/lambda-cloudwatch.json", {})
}



