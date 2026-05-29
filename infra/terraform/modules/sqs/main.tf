# SQS Queue for Product Events (Standard)
resource "aws_sqs_queue" "product_events_dlq" {
  name                      = "${local.queue_name_prefix}-product-events-dlq"
  message_retention_seconds = 1209600 # 14 days
  tags                      = var.tags
}

resource "aws_sqs_queue" "product_events" {
  name                       = "${local.queue_name_prefix}-product-events"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.product_events_dlq.arn
    maxReceiveCount     = var.max_receive_count_before_dlq
  })

  tags = var.tags
}

# SQS Queue for Product Events (FIFO) - for ordered processing
resource "aws_sqs_queue" "product_events_fifo" {
  name                        = "${local.queue_name_prefix}-product-events.fifo"
  fifo_queue                  = true
  content_based_deduplication = true

  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  tags = var.tags
}

# IAM Policy for EC2 to access SQS
resource "aws_iam_policy" "sqs_access" {
  name        = "${local.queue_name_prefix}-sqs-access-policy"
  description = "Allows EC2 instance to send/receive messages from SQS queues"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.product_events.arn,
          aws_sqs_queue.product_events_dlq.arn,
          aws_sqs_queue.product_events_fifo.arn
        ]
      }
    ]
  })

  tags = var.tags
}

# Locals for naming consistency
locals {
  queue_name_prefix = "${var.environment}-${var.project_name}"
}

