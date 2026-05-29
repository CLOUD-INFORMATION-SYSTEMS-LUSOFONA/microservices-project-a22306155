output "product_events_queue_url" {
  description = "URL of the product events SQS queue (Standard)"
  value       = aws_sqs_queue.product_events.url
}

output "product_events_queue_arn" {
  description = "ARN of the product events SQS queue (Standard)"
  value       = aws_sqs_queue.product_events.arn
}

output "product_events_dlq_url" {
  description = "URL of the product events Dead Letter Queue"
  value       = aws_sqs_queue.product_events_dlq.url
}

output "product_events_dlq_arn" {
  description = "ARN of the product events Dead Letter Queue"
  value       = aws_sqs_queue.product_events_dlq.arn
}

output "product_events_fifo_queue_url" {
  description = "URL of the product events SQS queue (FIFO)"
  value       = aws_sqs_queue.product_events_fifo.url
}

output "product_events_fifo_queue_arn" {
  description = "ARN of the product events SQS queue (FIFO)"
  value       = aws_sqs_queue.product_events_fifo.arn
}

output "sqs_access_policy_arn" {
  description = "ARN of the IAM policy for SQS access"
  value       = aws_iam_policy.sqs_access.arn
}

