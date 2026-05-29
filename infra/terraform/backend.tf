terraform {
  # Remote state backend configured with S3
  backend "s3" {
    bucket         = "terraform-state-cloud-project-753"
    key            = "cloud-project/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    # dynamodb_table = "terraform-locks"  # Optional: Create DynamoDB table if IAM permits
  }

  # For local development without remote state, use local backend:
  # backend "local" {
  #   path = "terraform.tfstate"
  # }
}