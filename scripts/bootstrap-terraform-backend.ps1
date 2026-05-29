# Bootstrap Script for AWS Infrastructure
# This script sets up the necessary AWS resources for Terraform remote state

# =============================================================================
# CONFIGURATION
# =============================================================================

$PROJECT_NAME = "cloud-project"
$REGION = "eu-central-1"
$PROFILE = "default"  # AWS profile to use (change if needed)

$S3_BUCKET_NAME = "terraform-state-$PROJECT_NAME-$(Get-Random -Maximum 10000)"
$DYNAMODB_TABLE = "terraform-locks"

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Test-AWSCredentials {
    try {
        $identity = aws sts get-caller-identity --profile $PROFILE 2>&1
        if ($?) {
            Write-Host "✅ AWS credentials valid" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ AWS credentials invalid or not configured" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Error checking AWS credentials: $_" -ForegroundColor Red
        return $false
    }
}

function Create-S3Bucket {
    param([string]$BucketName)

    Write-Host "Creating S3 bucket: $BucketName" -ForegroundColor Yellow

    try {
        # Create bucketin appropriate region
        if ($REGION -eq "us-central-1") {
            aws s3 create-bucket `
                --bucket $BucketName `
                --region $REGION `
                --profile $PROFILE
        }
        else {
            aws s3 create-bucket `
                --bucket $BucketName `
                --region $REGION `
                --create-bucket-configuration LocationConstraint=$REGION `
                --profile $PROFILE
        }

        Write-Host "✅ S3 bucket created: $BucketName" -ForegroundColor Green

        # Enable versioning
        Write-Host "Enabling versioning on bucket..." -ForegroundColor Yellow
        aws s3api put-bucket-versioning `
            --bucket $BucketName `
            --versioning-configuration Status=Enabled `
            --region $REGION `
            --profile $PROFILE

        Write-Host "✅ Versioning enabled" -ForegroundColor Green

        # Enable encryption
        Write-Host "Enabling encryption on bucket..." -ForegroundColor Yellow
        aws s3api put-bucket-encryption `
            --bucket $BucketName `
            --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}' `
            --region $REGION `
            --profile $PROFILE

        Write-Host "✅ Encryption enabled" -ForegroundColor Green

        return $true
    }
    catch {
        Write-Host "❌ Error creating S3 bucket: $_" -ForegroundColor Red
        return $false
    }
}

function Create-DynamoDBTable {
    param([string]$TableName)

    Write-Host "Creating DynamoDB table: $TableName" -ForegroundColor Yellow

    try {
        aws dynamodb create-table `
            --table-name $TableName `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 `
            --region $REGION `
            --profile $PROFILE

        Write-Host "✅ DynamoDB table created: $TableName" -ForegroundColor Green

        # Wait for table to be created
        Write-Host "Waiting for table to be active..." -ForegroundColor Yellow
        aws dynamodb wait table-exists `
            --table-name $TableName `
            --region $REGION `
            --profile $PROFILE

        Write-Host "✅ Table is active" -ForegroundColor Green

        return $true
    }
    catch {
        Write-Host "❌ Error creating DynamoDB table: $_" -ForegroundColor Red
        return $false
    }
}

function Update-Tfrraform-Backend {
    param([string]$BucketName)

    Write-Host "Updating backend.tf with bucket name..." -ForegroundColor Yellow

    $BackendFile = "infra\terraform\backend.tf"

    if (-Not (Test-Path $BackendFile)) {
        Write-Host "❌ backend.tf not found at $BackendFile" -ForegroundColor Red
        return $false
    }

    # Uncomment and update the backend configuration
    $BackendContent = @"
terraform {
  backend "s3" {
    bucket         = "$BucketName"
    key            = "cloud-project/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$DYNAMODB_TABLE"
    encrypt        = true
  }
}
"@

    Set-Content -Path $BackendFile -Value $BackendContent
    Write-Host "✅ backend.tf updated" -ForegroundColor Green
    return $true
}

# =============================================================================
# MAIN
# =============================================================================

Write-Header "🚀 AWS Terraform Backend Bootstrap"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Project Name: $PROJECT_NAME"
Write-Host "  Region: $REGION"
Write-Host "  Profile: $PROFILE"
Write-Host "  S3 Bucket: $S3_BUCKET_NAME"
Write-Host "  DynamoDB Table: $DYNAMODB_TABLE"

# Check AWS credentials
if (-Not (Test-AWSCredentials)) {
    Write-Host "`n❌ Please configure AWS credentials first:" -ForegroundColor Red
    Write-Host "  aws configure --profile $PROFILE"
    exit 1
}

# Create S3 bucket
if (-Not (Create-S3Bucket -BucketName $S3_BUCKET_NAME)) {
    exit 1
}

# Create DynamoDB table
if (-Not (Create-DynamoDBTable -TableName $DYNAMODB_TABLE)) {
    exit 1
}

# Update Terraform backend configuration
if (-Not (Update-Terraform-Backend -BucketName $S3_BUCKET_NAME)) {
    exit 1
}

Write-Header "✅ Bootstrap Complete!"

Write-Host "Next steps:" -ForegroundColor Green
Write-Host "1. Go to infra/terraform directory:"
Write-Host "   cd infra\terraform"
Write-Host ""
Write-Host "2. Re-initialize Terraform with new backend:"
Write-Host "   terraform init -input=false -reconfigure"
Write-Host ""
Write-Host "3. Run plan to confirm everything works:"
Write-Host "   terraform plan"
Write-Host ""
Write-Host "Note: If you already have local state (terraform.tfstate), you'll need to migrate it:"
Write-Host "   terraform init -input=false -reconfigure -migrate-state"

Write-Host "`n💾 Backup your terraform.tfstate locally before migrating!" -ForegroundColor Yellow

