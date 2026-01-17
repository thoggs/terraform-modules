#!/bin/bash
set -e

# Disable AWS CLI pager
export AWS_PAGER=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

print_header() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id=*)
      PROJECT_ID="${1#*=}"
      shift
      ;;
    --region=*)
      REGION="${1#*=}"
      shift
      ;;
    --service-name=*)
      SERVICE_NAME="${1#*=}"
      shift
      ;;
    --github-repo=*)
      GITHUB_REPO="${1#*=}"
      shift
      ;;
    --billing-account=*)
      BILLING_ACCOUNT="${1#*=}"
      shift
      ;;
    --terraform-modules-repo=*)
      TERRAFORM_MODULES_REPO="${1#*=}"
      shift
      ;;
    --output-dir=*)
      OUTPUT_DIR="${1#*=}"
      shift
      ;;
    --create-project)
      CREATE_PROJECT=true
      shift
      ;;
    --skip-terraform)
      SKIP_TERRAFORM=true
      shift
      ;;
    --yes|-y)
      AUTO_APPROVE=true
      shift
      ;;
    --custom-domain=*)
      CUSTOM_DOMAIN="${1#*=}"
      shift
      ;;
    --provider=*)
      PROVIDER="${1#*=}"
      shift
      ;;
    --env-file=*)
      ENV_FILE="${1#*=}"
      shift
      ;;
    --project-type=*)
      PROJECT_TYPE="${1#*=}"
      shift
      ;;
    --storage-bucket=*)
      STORAGE_BUCKET="${1#*=}"
      shift
      ;;
    --container-port=*)
      CONTAINER_PORT="${1#*=}"
      shift
      ;;
    --health-check-path=*)
      HEALTH_CHECK_PATH="${1#*=}"
      shift
      ;;
    --registry-name=*)
      REGISTRY_NAME="${1#*=}"
      shift
      ;;
    --tf-state-bucket=*)
      TF_STATE_BUCKET="${1#*=}"
      shift
      ;;
    --vpc-network=*)
      VPC_NETWORK="${1#*=}"
      shift
      ;;
    --vpc-subnetwork=*)
      VPC_SUBNETWORK="${1#*=}"
      shift
      ;;
    --aws-account-id=*)
      AWS_ACCOUNT_ID="${1#*=}"
      shift
      ;;
    --vpc-id=*)
      VPC_ID="${1#*=}"
      shift
      ;;
    --public-subnet-ids=*)
      PUBLIC_SUBNET_IDS="${1#*=}"
      shift
      ;;
    --private-subnet-ids=*)
      PRIVATE_SUBNET_IDS="${1#*=}"
      shift
      ;;
    --rds-instance=*)
      RDS_INSTANCE="${1#*=}"
      shift
      ;;
    --certificate-arn=*)
      CERTIFICATE_ARN="${1#*=}"
      shift
      ;;
    --fargate-public-ip)
      FARGATE_PUBLIC_IP=true
      shift
      ;;
    --create-rds)
      CREATE_RDS=true
      shift
      ;;
    --rds-database=*)
      RDS_DATABASE="${1#*=}"
      shift
      ;;
    --rds-username=*)
      RDS_USERNAME="${1#*=}"
      shift
      ;;
    --rds-password=*)
      RDS_PASSWORD="${1#*=}"
      shift
      ;;
    --create-valkey)
      CREATE_VALKEY=true
      shift
      ;;
    --cpu-arch=*)
      CPU_ARCH="${1#*=}"
      shift
      ;;
    --org-name=*)
      ORG_NAME="${1#*=}"
      shift
      ;;
    --dockerhub-username=*)
      DOCKERHUB_USERNAME="${1#*=}"
      shift
      ;;
    --dockerhub-token=*)
      DOCKERHUB_TOKEN="${1#*=}"
      shift
      ;;
    --github-token=*)
      GITHUB_TOKEN="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: ./bootstrap.sh [options]"
      echo ""
      echo "Common Options:"
      echo "  --provider=PROVIDER        Cloud provider: gcp (default), aws"
      echo "  --service-name=NAME        Service name (required)"
      echo "  --github-repo=REPO         GitHub repo owner/repo (required)"
      echo "  --terraform-modules-repo=REPO  Terraform modules repo (default: thoggs/terraform-modules)"
      echo "  --output-dir=PATH          Output directory for generated files (default: current dir)"
      echo "  --skip-terraform           Skip terraform init/plan/apply"
      echo "  --yes, -y                  Auto-approve all prompts (skip confirmations)"
      echo "  --env-file=PATH            Environment file to process (auto-detects .env.production)"
      echo "  --project-type=TYPE        Project type (required): nodejs, laravel-api, laravel-ssr, java-maven, java-gradle, docker-only"
      echo "  --container-port=PORT      Container port (default: 3000 for nodejs, 80 for laravel, 8080 for java)"
      echo "  --health-check-path=PATH   Health check endpoint (default: /api/health for nodejs, /up for laravel)"
      echo "  --tf-state-bucket=NAME     Bucket name for Terraform state"
      echo "  --help                     Show this help"
      echo ""
      echo "GCP Options:"
      echo "  --project-id=ID            GCP Project ID (required for GCP)"
      echo "  --region=REGION            GCP Region (default: us-central1)"
      echo "  --billing-account=ID       Billing account ID (required if --create-project)"
      echo "  --create-project           Create new GCP project"
      echo "  --custom-domain=DOMAIN     Custom domain for Cloud Run (e.g., app.example.com)"
      echo "  --storage-bucket=NAME      GCS bucket name for application storage"
      echo "  --registry-name=NAME       Artifact Registry name (default: same as service-name)"
      echo "  --vpc-network=NAME         VPC network for Direct VPC Egress"
      echo "  --vpc-subnetwork=NAME      VPC subnetwork for Direct VPC Egress"
      echo ""
      echo "AWS Options:"
      echo "  --org-name=NAME            Organization name for bucket naming (e.g., codesumn)"
      echo "  --aws-account-id=ID        AWS Account ID (auto-detected if not provided)"
      echo "  --region=REGION            AWS Region (default: us-east-1)"
      echo "  --vpc-id=ID                VPC ID for ECS deployment (required for AWS)"
      echo "  --public-subnet-ids=IDS    Comma-separated public subnet IDs for ALB (required for AWS)"
      echo "  --private-subnet-ids=IDS   Comma-separated private subnet IDs for ECS tasks (required for AWS)"
      echo "  --rds-instance=ENDPOINT    RDS endpoint for database connection (optional)"
      echo "  --certificate-arn=ARN      ACM certificate ARN for HTTPS (optional)"
      echo "  --storage-bucket=NAME      S3 bucket name for application storage"
      echo "  --fargate-public-ip        Assign public IP to Fargate tasks (for outbound internet access)"
      echo "  --cpu-arch=ARCH            CPU architecture: arm64 (default), amd64"
      echo "  --create-rds               Create RDS PostgreSQL instance"
      echo "  --rds-database=NAME        Database name (default: from env DB_DATABASE or 'app')"
      echo "  --rds-username=USER        Database username (default: from env DB_USERNAME or 'postgres')"
      echo "  --rds-password=PASS        Database password (default: from env DB_PASSWORD)"
      echo "  --create-valkey            Create ElastiCache Valkey (Redis-compatible, 20% cheaper)"
      echo "  --dockerhub-username=USER  Docker Hub username (avoids rate limiting in CI)"
      echo "  --dockerhub-token=TOKEN    Docker Hub access token (avoids rate limiting in CI)"
      echo "  --github-token=TOKEN       GitHub PAT for CodeBuild webhooks (PRs to develop)"
      echo ""
      echo "Project types:"
      echo "  nodejs       - Node.js project (yarn/npm build before Docker)"
      echo "  laravel-api  - Laravel API only (composer install, no frontend build)"
      echo "  laravel-ssr  - Laravel with Inertia SSR (composer + yarn build)"
      echo "  java-maven   - Java project with Maven (mvn package before Docker)"
      echo "  java-gradle  - Java project with Gradle (./gradlew build before Docker)"
      echo "  docker-only  - Multi-stage Dockerfile handles everything"
      echo ""
      echo "GCP Example:"
      echo "  ./bootstrap.sh \\"
      echo "    --provider=gcp \\"
      echo "    --project-id=my-project \\"
      echo "    --service-name=my-app \\"
      echo "    --github-repo=myuser/my-app \\"
      echo "    --project-type=laravel-ssr \\"
      echo "    --output-dir=/path/to/my-app"
      echo ""
      echo "AWS Example:"
      echo "  ./bootstrap.sh \\"
      echo "    --provider=aws \\"
      echo "    --service-name=my-app \\"
      echo "    --github-repo=myuser/my-app \\"
      echo "    --project-type=laravel-ssr \\"
      echo "    --vpc-id=vpc-0123456789abcdef0 \\"
      echo "    --public-subnet-ids=subnet-abc123,subnet-def456 \\"
      echo "    --private-subnet-ids=subnet-ghi789,subnet-jkl012 \\"
      echo "    --output-dir=/path/to/my-app"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set defaults
PROVIDER="${PROVIDER:-gcp}"
REGION="${REGION:-us-central1}"
TERRAFORM_MODULES_REPO="${TERRAFORM_MODULES_REPO:-thoggs/terraform-modules}"
OUTPUT_DIR="${OUTPUT_DIR:-.}"
REGISTRY_NAME="${REGISTRY_NAME:-$SERVICE_NAME}"

# Validate provider
case "$PROVIDER" in
  gcp|aws)
    ;;
  azure)
    log_error "Provider '$PROVIDER' is not implemented yet."
    log_info "Azure support coming soon!"
    exit 1
    ;;
  *)
    log_error "Unknown provider: $PROVIDER. Supported: gcp, aws"
    exit 1
    ;;
esac

# Set provider-specific defaults
if [[ "$PROVIDER" == "aws" ]]; then
  REGION="${REGION:-us-east-1}"
  CPU_ARCH="${CPU_ARCH:-arm64}"
fi

# Validate common required arguments
if [[ -z "$SERVICE_NAME" ]]; then
  log_error "Missing required argument: --service-name"
  exit 1
fi

if [[ -z "$GITHUB_REPO" ]]; then
  log_error "Missing required argument: --github-repo"
  exit 1
fi

if [[ -z "$PROJECT_TYPE" ]]; then
  log_error "Missing required argument: --project-type"
  log_info "Options: nodejs, laravel-api, laravel-ssr, java-maven, java-gradle, docker-only"
  exit 1
fi

# Validate provider-specific required arguments
if [[ "$PROVIDER" == "gcp" ]]; then
  if [[ -z "$PROJECT_ID" ]]; then
    log_error "Missing required argument: --project-id (required for GCP)"
    exit 1
  fi
elif [[ "$PROVIDER" == "aws" ]]; then
  if [[ -z "$VPC_ID" ]]; then
    log_error "Missing required argument: --vpc-id (required for AWS)"
    exit 1
  fi
  if [[ -z "$PUBLIC_SUBNET_IDS" ]]; then
    log_error "Missing required argument: --public-subnet-ids (required for AWS)"
    exit 1
  fi
  if [[ -z "$PRIVATE_SUBNET_IDS" ]]; then
    log_error "Missing required argument: --private-subnet-ids (required for AWS)"
    exit 1
  fi
fi

case "$PROJECT_TYPE" in
  nodejs|laravel-api|laravel-ssr|java-maven|java-gradle|docker-only)
    ;;
  *)
    log_error "Invalid project type: $PROJECT_TYPE"
    log_info "Options: nodejs, laravel-api, laravel-ssr, java-maven, java-gradle, docker-only"
    exit 1
    ;;
esac

# Set defaults based on project type
case "$PROJECT_TYPE" in
  nodejs)
    CONTAINER_PORT="${CONTAINER_PORT:-3000}"
    HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/api/health}"
    ;;
  laravel-api|laravel-ssr)
    CONTAINER_PORT="${CONTAINER_PORT:-80}"
    HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/up}"
    ;;
  java-maven|java-gradle)
    CONTAINER_PORT="${CONTAINER_PORT:-8080}"
    HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/actuator/health}"
    ;;
  docker-only)
    CONTAINER_PORT="${CONTAINER_PORT:-8080}"
    HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/health}"
    ;;
esac

if [[ "$CREATE_PROJECT" == "true" && -z "$BILLING_ACCOUNT" ]]; then
  log_error "Missing required argument: --billing-account (required when using --create-project)"
  exit 1
fi

# Directory paths
WORKFLOWS_DIR="$OUTPUT_DIR/.github/workflows"

# Provider-specific setup
if [[ "$PROVIDER" == "gcp" ]]; then
  STATE_BUCKET="${TF_STATE_BUCKET:-${PROJECT_ID}-tfstate}"
  INFRA_DIR="$OUTPUT_DIR/infra/gcp"
elif [[ "$PROVIDER" == "aws" ]]; then
  INFRA_DIR="$OUTPUT_DIR/infra/aws"
fi

# ============================================================================
# AWS PROVIDER FLOW
# ============================================================================
if [[ "$PROVIDER" == "aws" ]]; then
  print_header "AWS ECS Fargate Bootstrap"

  echo "Configuration:"
  echo "  Provider:         $PROVIDER"
  echo "  Region:           $REGION"
  echo "  Service Name:     $SERVICE_NAME"
  echo "  GitHub Repo:      $GITHUB_REPO"
  echo "  Modules Repo:     $TERRAFORM_MODULES_REPO"
  echo "  Output Dir:       $OUTPUT_DIR"
  echo "  Project Type:     $PROJECT_TYPE"
  echo "  VPC ID:           $VPC_ID"
  echo "  Public Subnets:   $PUBLIC_SUBNET_IDS"
  echo "  Private Subnets:  $PRIVATE_SUBNET_IDS"
  if [[ -n "$RDS_INSTANCE" ]]; then
    echo "  RDS Instance:     $RDS_INSTANCE"
  fi
  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    echo "  Custom Domain:    $CUSTOM_DOMAIN"
  fi
  if [[ -n "$CERTIFICATE_ARN" ]]; then
    echo "  Certificate ARN:  $CERTIFICATE_ARN"
  fi
  if [[ -n "$STORAGE_BUCKET" ]]; then
    echo "  S3 Bucket:        $STORAGE_BUCKET"
  fi
  echo ""

  # Check AWS authentication
  print_header "Step 1: Checking AWS Authentication"

  if ! aws sts get-caller-identity &>/dev/null; then
    log_error "Not authenticated to AWS. Please configure credentials:"
    log_info "  aws configure"
    log_info "  OR export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    exit 1
  fi
  log_success "AWS authenticated"

  # Auto-detect AWS Account ID if not provided
  if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_success "Auto-detected AWS Account ID: $AWS_ACCOUNT_ID"
  fi

  # Set state bucket name for AWS (prefer org-name over account ID)
  if [[ -n "$ORG_NAME" ]]; then
    STATE_BUCKET="${TF_STATE_BUCKET:-${SERVICE_NAME}-${ORG_NAME}-tfstate}"
  else
    STATE_BUCKET="${TF_STATE_BUCKET:-${SERVICE_NAME}-${AWS_ACCOUNT_ID}-tfstate}"
  fi

  echo ""
  echo "  AWS Account ID:   $AWS_ACCOUNT_ID"
  if [[ -n "$ORG_NAME" ]]; then
    echo "  Org Name:         $ORG_NAME"
  fi
  echo "  State Bucket:     $STATE_BUCKET"
  echo ""

  # Create S3 state bucket
  print_header "Step 2: Creating Terraform State Bucket"

  if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    log_warn "Bucket $STATE_BUCKET already exists"
  else
    log_info "Creating S3 bucket: $STATE_BUCKET"
    if [[ "$REGION" == "us-east-1" ]]; then
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION"
    else
      aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    fi

    # Enable versioning for state files
    aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
      --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
      --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

    # Block public access
    aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
      --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'

    log_success "S3 bucket created with versioning and encryption"
  fi

  # Create ACM certificate if custom domain is provided but no certificate ARN
  if [[ -n "$CUSTOM_DOMAIN" && -z "$CERTIFICATE_ARN" ]]; then
    print_header "Step 2.5: Creating ACM Certificate"

    # Check if certificate already exists for this domain
    EXISTING_CERT=$(aws acm list-certificates --region "$REGION" \
      --query "CertificateSummaryList[?DomainName=='$CUSTOM_DOMAIN'].CertificateArn" \
      --output text 2>/dev/null || echo "")

    if [[ -n "$EXISTING_CERT" && "$EXISTING_CERT" != "None" ]]; then
      CERTIFICATE_ARN="$EXISTING_CERT"
      log_success "Found existing certificate: $CERTIFICATE_ARN"

      # Check if it's issued
      CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERTIFICATE_ARN" --region "$REGION" \
        --query 'Certificate.Status' --output text)

      if [[ "$CERT_STATUS" == "ISSUED" ]]; then
        log_success "Certificate is already issued and valid"
      elif [[ "$CERT_STATUS" == "PENDING_VALIDATION" ]]; then
        log_warn "Certificate is pending validation"
      fi
    else
      log_info "Requesting new ACM certificate for: $CUSTOM_DOMAIN"

      # Request certificate
      CERTIFICATE_ARN=$(aws acm request-certificate \
        --domain-name "$CUSTOM_DOMAIN" \
        --validation-method DNS \
        --region "$REGION" \
        --query 'CertificateArn' \
        --output text)

      log_success "Certificate requested: $CERTIFICATE_ARN"

      # Wait a moment for AWS to generate validation records
      sleep 5
    fi

    # Get validation record
    CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERTIFICATE_ARN" --region "$REGION" \
      --query 'Certificate.Status' --output text)

    if [[ "$CERT_STATUS" != "ISSUED" ]]; then
      log_info "Getting DNS validation record..."

      VALIDATION_RECORD=$(aws acm describe-certificate \
        --certificate-arn "$CERTIFICATE_ARN" \
        --region "$REGION" \
        --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
        --output json 2>/dev/null || echo "{}")

      VALIDATION_NAME=$(echo "$VALIDATION_RECORD" | grep -o '"Name"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)
      VALIDATION_VALUE=$(echo "$VALIDATION_RECORD" | grep -o '"Value"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4)

      if [[ -n "$VALIDATION_NAME" && -n "$VALIDATION_VALUE" ]]; then
        echo ""
        echo "┌────────────────────────────────────────────────────────────────────┐"
        echo "│  Add this DNS record to validate your certificate:                 │"
        echo "├────────────────────────────────────────────────────────────────────┤"
        echo "│                                                                    │"
        echo "│  Type:   CNAME                                                     │"
        echo "│  Name:   $VALIDATION_NAME"
        echo "│  Value:  $VALIDATION_VALUE"
        echo "│                                                                    │"
        echo "│  Add this record in your DNS provider (Cloudflare, Route53, etc.) │"
        echo "│                                                                    │"
        echo "└────────────────────────────────────────────────────────────────────┘"
        echo ""

        # Check if running interactively (terminal) or non-interactively (web app/CI)
        WAIT_FOR_CERT="false"

        if [[ -t 0 ]]; then
          # Interactive mode - ask user if they want to wait
          if [[ "$AUTO_APPROVE" != "true" ]]; then
            read -p "Wait for certificate validation? (y/n) " -n 1 -r < /dev/tty
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              WAIT_FOR_CERT="true"
            fi
          fi
        else
          # Non-interactive mode (web app) - don't wait
          log_info "Non-interactive mode: skipping certificate validation wait"
        fi

        if [[ "$WAIT_FOR_CERT" == "true" ]]; then
          log_info "Waiting for certificate validation (this may take 1-5 minutes)..."

          WAIT_TIME=0
          MAX_WAIT=300  # 5 minutes

          while [[ $WAIT_TIME -lt $MAX_WAIT ]]; do
            CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERTIFICATE_ARN" --region "$REGION" \
              --query 'Certificate.Status' --output text)

            if [[ "$CERT_STATUS" == "ISSUED" ]]; then
              log_success "Certificate validated and issued!"
              break
            elif [[ "$CERT_STATUS" == "FAILED" ]]; then
              log_error "Certificate validation failed"
              exit 1
            fi

            echo -n "."
            sleep 10
            WAIT_TIME=$((WAIT_TIME + 10))
          done
          echo ""
        fi

        # Check final status
        CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERTIFICATE_ARN" --region "$REGION" \
          --query 'Certificate.Status' --output text)

        if [[ "$CERT_STATUS" != "ISSUED" ]]; then
          log_warn "Certificate not yet validated (status: $CERT_STATUS)"
          log_info "Continuing with HTTP only. HTTPS will be enabled after validation."
          log_info ""
          log_info "After adding the DNS record and validation completes, run:"
          log_info "  cd $INFRA_DIR && terraform apply -var-file=terraform.tfvars"
          log_info ""
          log_info "Check certificate status:"
          log_info "  aws acm describe-certificate --certificate-arn $CERTIFICATE_ARN --region $REGION --query 'Certificate.Status'"
          # Clear certificate ARN so ALB is created with HTTP only
          CERTIFICATE_ARN=""
        fi
      else
        log_warn "Could not retrieve validation record. Check AWS console."
        CERTIFICATE_ARN=""
      fi
    fi

    if [[ -n "$CERTIFICATE_ARN" ]]; then
      log_success "Certificate ARN: $CERTIFICATE_ARN"
    fi
  fi

  # Final check: if we have a custom domain but no certificate ARN, check for ISSUED certificate
  # This handles the case where bootstrap was run before and cert was pending, but is now issued
  if [[ -n "$CUSTOM_DOMAIN" && -z "$CERTIFICATE_ARN" ]]; then
    log_info "Checking for existing ISSUED certificate for $CUSTOM_DOMAIN..."
    ISSUED_CERT=$(aws acm list-certificates --region "$REGION" \
      --certificate-statuses ISSUED \
      --query "CertificateSummaryList[?DomainName=='$CUSTOM_DOMAIN'].CertificateArn" \
      --output text 2>/dev/null || echo "")

    if [[ -n "$ISSUED_CERT" && "$ISSUED_CERT" != "None" ]]; then
      CERTIFICATE_ARN="$ISSUED_CERT"
      log_success "Found ISSUED certificate: $CERTIFICATE_ARN"
    fi
  fi

  # Create ECR repository and push initial image
  print_header "Step 3: Creating ECR Repository & Pushing Initial Image"

  ECR_REPO_NAME="ecr-${SERVICE_NAME}"
  ECR_REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}"

  # Create ECR repository if it doesn't exist
  if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" &>/dev/null; then
    log_info "Creating ECR repository: $ECR_REPO_NAME"
    aws ecr create-repository \
      --repository-name "$ECR_REPO_NAME" \
      --region "$REGION" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256
    log_success "ECR repository created"

    # Set lifecycle policy to keep only 1 image
    log_info "Setting lifecycle policy..."
    aws ecr put-lifecycle-policy \
      --repository-name "$ECR_REPO_NAME" \
      --region "$REGION" \
      --lifecycle-policy-text '{
        "rules": [
          {
            "rulePriority": 1,
            "description": "Delete untagged images immediately",
            "selection": {
              "tagStatus": "untagged",
              "countType": "sinceImagePushed",
              "countUnit": "days",
              "countNumber": 1
            },
            "action": {
              "type": "expire"
            }
          },
          {
            "rulePriority": 2,
            "description": "Keep only 1 tagged image",
            "selection": {
              "tagStatus": "tagged",
              "tagPrefixList": ["latest"],
              "countType": "imageCountMoreThan",
              "countNumber": 1
            },
            "action": {
              "type": "expire"
            }
          },
          {
            "rulePriority": 3,
            "description": "Keep only 1 commit-tagged image",
            "selection": {
              "tagStatus": "any",
              "countType": "imageCountMoreThan",
              "countNumber": 2
            },
            "action": {
              "type": "expire"
            }
          }
        ]
      }'
    log_success "Lifecycle policy configured (keeps only 1 image)"
  else
    log_warn "ECR repository $ECR_REPO_NAME already exists"
  fi

  # Configure Docker authentication for ECR
  log_info "Configuring Docker authentication for ECR..."
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
  log_success "Docker configured for ECR"

  # Build and push initial image if Dockerfile exists
  if [[ -f "$OUTPUT_DIR/Dockerfile" ]]; then
    cd "$OUTPUT_DIR"
    case "$PROJECT_TYPE" in
      nodejs)
        log_info "Building Node.js application..."
        if command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
          yarn install --immutable 2>/dev/null || yarn install
          yarn build
        elif command -v npm &>/dev/null; then
          npm ci 2>/dev/null || npm install
          npm run build
        fi
        log_success "Node.js application built"
        ;;
      laravel-api)
        log_info "Building Laravel API application..."
        log_success "Laravel API ready (composer install runs inside Docker)"
        ;;
      laravel-ssr)
        log_info "Building Laravel SSR application..."
        if command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
          yarn install --immutable 2>/dev/null || yarn install
          yarn build
        elif command -v npm &>/dev/null; then
          npm ci 2>/dev/null || npm install
          npm run build
        fi
        log_success "Laravel SSR application built (composer install runs inside Docker)"
        ;;
      java-maven)
        log_info "Building Java application with Maven..."
        mvn package -DskipTests
        log_success "Maven build completed"
        ;;
      java-gradle)
        log_info "Building Java application with Gradle..."
        ./gradlew build -x test
        log_success "Gradle build completed"
        ;;
      docker-only)
        log_info "Skipping application build (docker-only mode)"
        ;;
    esac
    cd - > /dev/null

    log_info "Building Docker image (linux/amd64,linux/arm64)..."

    IMAGE_NAME="$ECR_REPO_URI:latest"
    if docker buildx version &>/dev/null; then
      docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch 2>/dev/null || true
      docker buildx build --platform linux/amd64,linux/arm64 -t "$IMAGE_NAME" "$OUTPUT_DIR" --push
    else
      docker build -t "$IMAGE_NAME" "$OUTPUT_DIR"
      log_info "Pushing image to ECR..."
      docker push "$IMAGE_NAME"
    fi

    log_success "Image pushed: $IMAGE_NAME"
  else
    log_warn "No Dockerfile found in $OUTPUT_DIR - skipping image build"
    log_warn "You'll need to build and push the image manually before terraform apply"
  fi

  # Process environment variables
  ENV_VARS_TF=""
  SECRET_ENV_VARS_TF=""

  # Auto-detect env file if --env-file not specified
  if [[ -z "$ENV_FILE" ]]; then
    case "$PROJECT_TYPE" in
      laravel-api|laravel-ssr)
        if [[ -f "$OUTPUT_DIR/.env.production" ]]; then
          ENV_FILE="$OUTPUT_DIR/.env.production"
        fi
        ;;
      *)
        if [[ -f "$OUTPUT_DIR/.env.local" ]]; then
          ENV_FILE="$OUTPUT_DIR/.env.local"
        fi
        ;;
    esac
  fi

  if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    print_header "Step 4: Processing Environment Variables"

    log_info "Reading environment file: $ENV_FILE"
    echo ""
    echo "┌────────────────────────────────────────────────────────────────────┐"
    echo "│  Annotation syntax:                                                │"
    echo "│    # @secret    → AWS Secrets Manager (runtime)                    │"
    echo "│    # @build     → GitHub Variables (build-time)                    │"
    echo "│    # @public    → ECS env vars (runtime, default)                  │"
    if [[ "$PROJECT_TYPE" == "nodejs" ]]; then
    echo "│    NEXT_PUBLIC_* without tag → auto-detected as @build             │"
    fi
    echo "└────────────────────────────────────────────────────────────────────┘"
    echo ""

    # Use temp files instead of associative arrays (bash 3.x compatibility)
    ENV_KEYS_FILE=$(mktemp)
    ENV_VALUES_FILE=$(mktemp)
    SECRET_KEYS_FILE=$(mktemp)
    SECRET_VALUES_FILE=$(mktemp)
    BUILD_KEYS_FILE=$(mktemp)
    BUILD_VALUES_FILE=$(mktemp)
    trap "rm -f $ENV_KEYS_FILE $ENV_VALUES_FILE $SECRET_KEYS_FILE $SECRET_VALUES_FILE $BUILD_KEYS_FILE $BUILD_VALUES_FILE" EXIT

    next_marker=""
    env_count=0
    secret_count=0
    build_count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" ]] && continue

      if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@secret ]]; then
        next_marker="secret"
        continue
      elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@build ]]; then
        next_marker="build"
        continue
      elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@public ]]; then
        next_marker="public"
        continue
      fi

      [[ "$line" =~ ^[[:space:]]*# ]] && continue

      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"

        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"

        if [[ "$next_marker" == "secret" ]]; then
          echo "$key" >> "$SECRET_KEYS_FILE"
          echo "$value" >> "$SECRET_VALUES_FILE"
          ((secret_count++))
        elif [[ "$next_marker" == "build" ]] || { [[ "$PROJECT_TYPE" == "nodejs" ]] && [[ "$key" == NEXT_PUBLIC_* ]]; }; then
          echo "$key" >> "$BUILD_KEYS_FILE"
          echo "$value" >> "$BUILD_VALUES_FILE"
          ((build_count++))
        else
          echo "$key" >> "$ENV_KEYS_FILE"
          echo "$value" >> "$ENV_VALUES_FILE"
          ((env_count++))
        fi

        # Capture DB_DATABASE, DB_USERNAME, DB_PASSWORD for RDS
        if [[ "$key" == "DB_DATABASE" ]]; then
          DB_DATABASE="$value"
        fi
        if [[ "$key" == "DB_USERNAME" ]]; then
          DB_USERNAME="$value"
        fi
        if [[ "$key" == "DB_PASSWORD" ]]; then
          DB_PASSWORD="$value"
        fi

        # Auto-detect S3 bucket from AWS_BUCKET
        if [[ "$key" == "AWS_BUCKET" && -n "$value" ]]; then
          if [[ -z "$STORAGE_BUCKET" ]]; then
            STORAGE_BUCKET="$value"
          fi
        fi

        next_marker=""
      fi
    done < "$ENV_FILE"

    # Display grouped by type
    if [[ $secret_count -gt 0 ]]; then
      echo ""
      echo -e "${RED}Secrets - AWS Secrets Manager ($secret_count):${NC}"
      while IFS= read -r key; do
        echo "  • $key"
      done < "$SECRET_KEYS_FILE"
    fi

    if [[ $build_count -gt 0 ]]; then
      echo ""
      echo -e "${YELLOW}Build-time Variables - GitHub Variables ($build_count):${NC}"
      while IFS= read -r key; do
        echo "  • $key"
      done < "$BUILD_KEYS_FILE"
    fi

    if [[ $env_count -gt 0 ]]; then
      echo ""
      echo -e "${GREEN}Runtime Variables - ECS Task Definition ($env_count):${NC}"
      while IFS= read -r key; do
        echo "  • $key"
      done < "$ENV_KEYS_FILE"
    fi

    if [[ -n "$STORAGE_BUCKET" ]]; then
      echo ""
      echo -e "${BLUE}S3 Storage Bucket (auto-detected from AWS_BUCKET):${NC}"
      echo "  • $STORAGE_BUCKET"

      # Create storage bucket if it doesn't exist
      if ! aws s3api head-bucket --bucket "$STORAGE_BUCKET" 2>/dev/null; then
        log_info "Creating S3 storage bucket: $STORAGE_BUCKET"
        if [[ "$REGION" == "us-east-1" ]]; then
          aws s3api create-bucket --bucket "$STORAGE_BUCKET" --region "$REGION"
        else
          aws s3api create-bucket --bucket "$STORAGE_BUCKET" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
        fi
        aws s3api put-bucket-encryption --bucket "$STORAGE_BUCKET" \
          --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
        aws s3api put-public-access-block --bucket "$STORAGE_BUCKET" \
          --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
        log_success "Storage bucket created with encryption"
      fi
    fi

    echo ""

    if [[ $secret_count -gt 0 ]] || [[ $build_count -gt 0 ]]; then
      if [[ "$AUTO_APPROVE" != "true" ]]; then
        read -p "Continue with this classification? (y/n) " -n 1 -r < /dev/tty
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          log_warn "Aborted. Please update your .env file with @secret/@public markers and try again."
          exit 1
        fi
      fi
    fi

    if [[ $secret_count -gt 0 ]]; then
      log_info "Preparing secrets configuration (Terraform managed)..."
      SECRET_KEYS_LIST=""
      while IFS= read -r key; do
        SECRET_KEYS_LIST+="$key "
      done < "$SECRET_KEYS_FILE"
      log_success "Secrets will be managed by Terraform via GitHub Secrets"
      log_info "Secret keys: $SECRET_KEYS_LIST"
    fi

    # Build terraform env_vars
    ALL_KEYS_FILE=$(mktemp)
    ALL_VALUES_FILE=$(mktemp)
    cat "$ENV_KEYS_FILE" "$SECRET_KEYS_FILE" "$BUILD_KEYS_FILE" > "$ALL_KEYS_FILE" 2>/dev/null || true
    cat "$ENV_VALUES_FILE" "$SECRET_VALUES_FILE" "$BUILD_VALUES_FILE" > "$ALL_VALUES_FILE" 2>/dev/null || true

    resolve_env_refs() {
      local value="$1"
      local resolved="$value"
      while [[ "$resolved" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value=""
        local line_num=1
        while IFS= read -r k; do
          if [[ "$k" == "$var_name" ]]; then
            var_value=$(sed -n "${line_num}p" "$ALL_VALUES_FILE")
            break
          fi
          ((line_num++))
        done < "$ALL_KEYS_FILE"
        resolved="${resolved/\$\{$var_name\}/$var_value}"
      done
      echo "$resolved"
    }

    ENV_VARS_TF="  NODE_ENV = \"production\"\n"
    if [[ $env_count -gt 0 ]]; then
      while IFS= read -r key && IFS= read -r value <&3; do
        resolved_value=$(resolve_env_refs "$value")
        escaped_value=$(echo "$resolved_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
        ENV_VARS_TF+="  $key = \"$escaped_value\"\n"
      done < "$ENV_KEYS_FILE" 3< "$ENV_VALUES_FILE"
    fi

    rm -f "$ALL_KEYS_FILE" "$ALL_VALUES_FILE"

    if [[ "$PROJECT_TYPE" == "laravel-api" ]] || [[ "$PROJECT_TYPE" == "laravel-ssr" ]]; then
      if ! grep -q "^  LOG_STACK = " <<< "$ENV_VARS_TF"; then
        log_info "Adding cloud-native logging defaults for Laravel..."
        ENV_VARS_TF+="  LOG_STACK = \"stderr\"\n"
        log_success "Set LOG_STACK=stderr (required for container environments)"
      fi
    fi

    log_success "Environment variables processed"
  else
    ENV_VARS_TF="  NODE_ENV = \"production\""

    if [[ "$PROJECT_TYPE" == "laravel-api" ]] || [[ "$PROJECT_TYPE" == "laravel-ssr" ]]; then
      ENV_VARS_TF+="\n  LOG_STACK = \"stderr\""
    fi

    log_info "No env file found, using defaults"
  fi

  # Create directory structure
  print_header "Step 5: Creating Project Structure"

  mkdir -p "$INFRA_DIR"
  mkdir -p "$WORKFLOWS_DIR"
  log_success "Created directories: infra/aws/, .github/workflows/"

  # Convert subnet IDs to Terraform list format
  PUBLIC_SUBNET_TF=$(echo "$PUBLIC_SUBNET_IDS" | sed 's/,/", "/g' | sed 's/^/"/; s/$/"/')
  PRIVATE_SUBNET_TF=$(echo "$PRIVATE_SUBNET_IDS" | sed 's/,/", "/g' | sed 's/^/"/; s/$/"/')

  # Sanitize RDS password (AWS RDS doesn't allow: / @ " space)
  FINAL_RDS_PASSWORD="${RDS_PASSWORD:-${DB_PASSWORD:-}}"
  if [[ -n "$FINAL_RDS_PASSWORD" ]]; then
    SANITIZED_PASSWORD=$(echo "$FINAL_RDS_PASSWORD" | tr -d '/@"\ ')
    if [[ "$SANITIZED_PASSWORD" != "$FINAL_RDS_PASSWORD" ]]; then
      log_warn "RDS password contained invalid characters (/ @ \" space) - they were removed"
      FINAL_RDS_PASSWORD="$SANITIZED_PASSWORD"
    fi
  fi

  # Generate random password if empty or if CREATE_RDS is enabled without password
  if [[ "$CREATE_RDS" == "true" && -z "$FINAL_RDS_PASSWORD" ]]; then
    log_info "Generating secure random password for RDS..."
    FINAL_RDS_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9!#$%^&*()_+-=[]{}|;:,.<>?' < /dev/urandom | head -c 32)
    log_success "Random password generated (32 chars, alphanumeric + safe special chars)"
  fi

  # Update DB_PASSWORD in secrets file to match RDS password (if changed or generated)
  if [[ "$CREATE_RDS" == "true" && -n "$FINAL_RDS_PASSWORD" && -f "$SECRET_KEYS_FILE" ]]; then
    # Find DB_PASSWORD line number in secrets files
    DB_PASS_LINE=$(grep -n "^DB_PASSWORD$" "$SECRET_KEYS_FILE" 2>/dev/null | cut -d: -f1 || echo "")
    if [[ -n "$DB_PASS_LINE" ]]; then
      # Update the password value in SECRET_VALUES_FILE
      sed -i '' "${DB_PASS_LINE}s/.*/${FINAL_RDS_PASSWORD}/" "$SECRET_VALUES_FILE" 2>/dev/null || \
        sed -i "${DB_PASS_LINE}s/.*/${FINAL_RDS_PASSWORD}/" "$SECRET_VALUES_FILE"
      log_info "Updated DB_PASSWORD in secrets to match RDS password"
    else
      # DB_PASSWORD not in secrets, add it
      echo "DB_PASSWORD" >> "$SECRET_KEYS_FILE"
      echo "$FINAL_RDS_PASSWORD" >> "$SECRET_VALUES_FILE"
      log_info "Added DB_PASSWORD to secrets"
    fi
  fi

  # Sync RDS password if RDS already exists (idempotent operation)
  if [[ "$CREATE_RDS" == "true" && -n "$FINAL_RDS_PASSWORD" ]]; then
    RDS_IDENTIFIER="rds-${SERVICE_NAME}"
    if aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" --region "$REGION" &>/dev/null; then
      log_info "RDS instance '$RDS_IDENTIFIER' already exists, syncing master password..."
      if aws rds modify-db-instance \
        --db-instance-identifier "$RDS_IDENTIFIER" \
        --master-user-password "$FINAL_RDS_PASSWORD" \
        --apply-immediately \
        --region "$REGION" &>/dev/null; then
        log_success "RDS master password updated"
      else
        log_warn "Could not update RDS master password (may require manual intervention)"
      fi
    fi

    # Also update the secret in AWS Secrets Manager if it exists
    # Terraform creates secrets with lowercase and hyphens: DB_PASSWORD -> db-password
    SECRET_NAME="${SERVICE_NAME}/db-password"
    SECRET_UPDATED=false
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" &>/dev/null; then
      log_info "Updating DB_PASSWORD in AWS Secrets Manager..."
      if aws secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "$FINAL_RDS_PASSWORD" \
        --region "$REGION" &>/dev/null; then
        log_success "AWS Secrets Manager secret updated"
        SECRET_UPDATED=true
      else
        log_warn "Could not update AWS Secrets Manager secret"
      fi
    fi

    # Force ECS deployment if secrets were updated (so tasks reload the new values)
    ECS_CLUSTER="ecs-${SERVICE_NAME}"
    if [[ "$SECRET_UPDATED" == "true" ]] && aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$SERVICE_NAME" --region "$REGION" &>/dev/null; then
      log_info "Forcing ECS deployment to reload updated secrets..."
      if aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service "$SERVICE_NAME" \
        --force-new-deployment \
        --region "$REGION" &>/dev/null; then
        log_success "ECS deployment triggered"
      else
        log_warn "Could not trigger ECS deployment"
      fi
    fi
  fi

  # Extract org name from GitHub repo (owner/repo -> owner)
  ORG_NAME=$(echo "$GITHUB_REPO" | cut -d'/' -f1 | tr '[:upper:]' '[:lower:]')

  # Create terraform.tfvars for AWS
  cat > "$INFRA_DIR/terraform.tfvars" << EOF
region           = "$REGION"
service_name     = "$SERVICE_NAME"
org_name         = "$ORG_NAME"
github_repo      = "$GITHUB_REPO"

vpc_id             = "$VPC_ID"
public_subnet_ids  = [$PUBLIC_SUBNET_TF]
private_subnet_ids = [$PRIVATE_SUBNET_TF]

container_port    = $CONTAINER_PORT
health_check_path = "$HEALTH_CHECK_PATH"

ecs_cpu           = "1024"
ecs_memory        = "2048"
ecs_desired_count = 1
ecs_min_count     = 1
ecs_max_count     = 4

env_vars = {
$(echo -e "$ENV_VARS_TF")
}

# Secret keys (values are passed via -var in CI/CD from GitHub Secrets)
# Terraform creates secrets in AWS Secrets Manager with prefix: ${SERVICE_NAME}/
secret_keys = [$(if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
  first=true
  while IFS= read -r key; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo -n ", "
    fi
    echo -n "\"$key\""
  done < "$SECRET_KEYS_FILE"
fi)]

certificate_arn   = "${CERTIFICATE_ARN:-}"
s3_bucket_arns    = [$(if [[ -n "$STORAGE_BUCKET" ]]; then echo "\"arn:aws:s3:::$STORAGE_BUCKET\", \"arn:aws:s3:::$STORAGE_BUCKET/*\""; fi)]
assign_public_ip  = $(if [[ "$FARGATE_PUBLIC_IP" == "true" ]]; then echo "true"; else echo "false"; fi)

# RDS PostgreSQL (db.t4g.micro ~\$13/month)
create_rds        = $(if [[ "$CREATE_RDS" == "true" ]]; then echo "true"; else echo "false"; fi)
rds_database_name = "${RDS_DATABASE:-${DB_DATABASE:-app}}"
rds_username      = "${RDS_USERNAME:-${DB_USERNAME:-postgres}}"
rds_password      = "${FINAL_RDS_PASSWORD}"

# ElastiCache Valkey (cache.t4g.micro ~\$12/month - Redis-compatible, 20-33% cheaper)
create_valkey = $(if [[ "$CREATE_VALKEY" == "true" ]]; then echo "true"; else echo "false"; fi)

# Docker Hub credentials (optional - avoids rate limiting in CI)
dockerhub_username = "${DOCKERHUB_USERNAME:-}"
dockerhub_token    = "${DOCKERHUB_TOKEN:-}"

# GitHub token for CodeBuild webhooks (CI on PRs to develop)
github_token = "${GITHUB_TOKEN:-}"
EOF
  log_success "Created infra/aws/terraform.tfvars"

  # Create main.tf for AWS
  cat > "$INFRA_DIR/main.tf" << EOF
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  backend "s3" {
    bucket = "$STATE_BUCKET"
    key    = "terraform/state/terraform.tfstate"
    region = "$REGION"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Service   = var.service_name
    }
  }
}

locals {
  ecr_repo_name = "ecr-\${var.service_name}"
}

module "oidc_provider" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/aws/oidc-provider?ref=main"

  role_name   = "github-actions-\${var.service_name}"
  github_repo = var.github_repo

  enable_ecs_access             = true
  enable_secrets_manager_access = true
  enable_s3_access              = true
  terraform_state_bucket        = "$STATE_BUCKET"
}

module "ecr" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/aws/ecr?ref=main"

  repository_name      = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  force_delete         = true
  keep_image_count     = 1
}

# VPC data for CIDR block
data "aws_vpc" "main" {
  id = var.vpc_id
}

# RDS PostgreSQL (economical config - private subnet only)
module "rds_postgres" {
  count  = var.create_rds ? 1 : 0
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/aws/rds-postgres?ref=main"

  identifier    = "rds-\${var.service_name}"
  vpc_id        = var.vpc_id
  subnet_ids    = var.private_subnet_ids
  database_name = var.rds_database_name
  username      = var.rds_username
  password      = var.rds_password

  # Economical settings (db.t4g.micro ~\$13/month)
  instance_class        = "db.t4g.micro"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  multi_az              = false

  # Private network only
  publicly_accessible = false

  # Allow connections from VPC CIDR (ECS tasks)
  allowed_cidr_blocks = [data.aws_vpc.main.cidr_block]

  # Backup & maintenance
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Service = var.service_name
  }
}

# ElastiCache Valkey (Redis-compatible, 20-33% cheaper than Redis)
module "elasticache_valkey" {
  count  = var.create_valkey ? 1 : 0
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/aws/elasticache-valkey?ref=main"

  cluster_id = "valkey-\${var.service_name}"
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Allow connections from VPC CIDR (ECS tasks)
  allowed_cidr_blocks = [data.aws_vpc.main.cidr_block]

  # Economical settings (cache.t4g.micro ~\$12/month)
  node_type          = "cache.t4g.micro"
  num_cache_clusters = 1

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false

  tags = {
    Service = var.service_name
  }
}

# Secrets Manager - Terraform managed secrets with service prefix
resource "aws_secretsmanager_secret" "secrets" {
  for_each = toset(var.secret_keys)
  name     = "\${var.service_name}/\${lower(replace(each.value, "_", "-"))}"

  tags = {
    Service = var.service_name
    Managed = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "secrets" {
  for_each      = toset(var.secret_keys)
  secret_id     = aws_secretsmanager_secret.secrets[each.value].id
  secret_string = var.secret_values[each.value]

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Merge RDS and Valkey endpoints into env_vars when created
locals {
  rds_env_vars = var.create_rds ? {
    DB_HOST = module.rds_postgres[0].address
    DB_PORT = tostring(module.rds_postgres[0].port)
  } : {}
  valkey_env_vars = var.create_valkey ? {
    REDIS_HOST = module.elasticache_valkey[0].primary_endpoint
    REDIS_PORT = tostring(module.elasticache_valkey[0].port)
  } : {}
  final_env_vars = merge(var.env_vars, local.rds_env_vars, local.valkey_env_vars)
}

module "ecs_fargate" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/aws/ecs-fargate?ref=main"

  cluster_name = "ecs-\${var.service_name}"
  service_name = var.service_name
  image        = "\${module.ecr.repository_url}:\${var.image_tag}"

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  # Use public subnets for tasks when assign_public_ip is true (public IP requires public subnet)
  private_subnet_ids = var.assign_public_ip ? var.public_subnet_ids : var.private_subnet_ids

  container_port    = var.container_port
  health_check_path = var.health_check_path

  cpu           = var.ecs_cpu
  memory        = var.ecs_memory
  desired_count = var.ecs_desired_count
  min_count     = var.ecs_min_count
  max_count     = var.ecs_max_count

  env_vars = local.final_env_vars

  secret_env_vars = {
    for name in var.secret_keys : name => aws_secretsmanager_secret.secrets[name].arn
  }

  secret_arns    = [for s in aws_secretsmanager_secret.secrets : s.arn]
  s3_bucket_arns = var.s3_bucket_arns

  certificate_arn     = var.certificate_arn
  deletion_protection = var.deletion_protection
  assign_public_ip    = var.assign_public_ip

  depends_on = [module.ecr, module.rds_postgres, module.elasticache_valkey, aws_secretsmanager_secret_version.secrets]
}
EOF

  # Add CodeBuild CI/CD with webhooks for ARM architecture
  if [[ "$CPU_ARCH" == "arm64" ]]; then
    cat >> "$INFRA_DIR/main.tf" << 'CODEBUILD_EOF'

# =============================================================================
# CodeBuild CI (PRs to develop) & CD (push to main) with GitHub Webhooks
# =============================================================================

# Docker Hub credentials secret (avoids rate limiting)
resource "aws_secretsmanager_secret" "dockerhub" {
  count       = var.dockerhub_username != "" ? 1 : 0
  name        = "${var.service_name}/dockerhub"
  description = "Docker Hub credentials for ${var.service_name}"
}

resource "aws_secretsmanager_secret_version" "dockerhub" {
  count     = var.dockerhub_username != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.dockerhub[0].id
  secret_string = jsonencode({
    username = var.dockerhub_username
    password = var.dockerhub_token
  })
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild" {
  name = "codebuild-${var.service_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild-${var.service_name}-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          [for s in aws_secretsmanager_secret.secrets : s.arn],
          var.dockerhub_username != "" ? [aws_secretsmanager_secret.dockerhub[0].arn] : []
        )
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# CI: CodeBuild with GitHub Webhook (PRs to develop)
# =============================================================================

resource "aws_codebuild_project" "ci" {
  name          = "${var.service_name}-ci"
  description   = "CI for ${var.service_name} - runs tests on PRs to develop"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "SERVICE_NAME"
      value = var.service_name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repo}.git"
    git_clone_depth = 1
    buildspec       = "infra/aws/buildspecs/ci.yml"
    report_build_status = true
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.service_name}-ci"
      stream_name = "build"
    }
  }

  tags = {
    Service = var.service_name
    Stage   = "CI"
  }
}

# GitHub credentials for CodeBuild (required for webhooks)
resource "aws_codebuild_source_credential" "github" {
  count       = var.github_token != "" ? 1 : 0
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.github_token
}

# Webhook for CI - triggers on PRs to develop
resource "aws_codebuild_webhook" "ci" {
  count        = var.github_token != "" ? 1 : 0
  project_name = aws_codebuild_project.ci.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
    }
    filter {
      type    = "BASE_REF"
      pattern = "^refs/heads/develop$"
    }
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# Disable comment approval requirement for CI webhook (solo developers / private repos)
resource "null_resource" "ci_webhook_no_approval" {
  count = var.github_token != "" ? 1 : 0

  triggers = {
    webhook_url = aws_codebuild_webhook.ci[0].url
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws codebuild update-webhook \
        --project-name ${aws_codebuild_project.ci.name} \
        --region ${var.region} \
        --pull-request-build-policy '{"requiresCommentApproval":"DISABLED"}'
    EOT
  }

  depends_on = [aws_codebuild_webhook.ci]
}

# =============================================================================
# CD: CodeBuild with Webhook (push to main)
# =============================================================================

resource "aws_codebuild_project" "cd" {
  name          = "${var.service_name}-cd"
  description   = "CD for ${var.service_name} - builds and deploys on push to main"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "SERVICE_NAME"
      value = var.service_name
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ECR_REPOSITORY"
      value = local.ecr_repo_name
    }

    environment_variable {
      name  = "ECS_CLUSTER"
      value = "ecs-${var.service_name}"
    }

    environment_variable {
      name  = "ECS_SERVICE"
      value = var.service_name
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_repo}.git"
    git_clone_depth = 1
    buildspec       = "infra/aws/buildspecs/cd.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/${var.service_name}-cd"
      stream_name = "build"
    }
  }

  tags = {
    Service = var.service_name
    Stage   = "CD"
  }
}

# Webhook for CD - triggers on push to main
resource "aws_codebuild_webhook" "cd" {
  count        = var.github_token != "" ? 1 : 0
  project_name = aws_codebuild_project.cd.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/main$"
    }
  }

  depends_on = [aws_codebuild_source_credential.github]
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

output "codebuild_ci_url" {
  description = "CI CodeBuild URL (triggered by PRs to develop)"
  value       = "https://${var.region}.console.aws.amazon.com/codesuite/codebuild/projects/${aws_codebuild_project.ci.name}"
}

output "codebuild_cd_url" {
  description = "CD CodeBuild URL (triggered by push to main)"
  value       = "https://${var.region}.console.aws.amazon.com/codesuite/codebuild/projects/${aws_codebuild_project.cd.name}"
}
CODEBUILD_EOF
    log_success "Added CodeBuild CI and CD resources with webhooks to main.tf"

    # Create buildspecs directory
    mkdir -p "$INFRA_DIR/buildspecs"

    # Generate buildspec for CI based on project type
    case "$PROJECT_TYPE" in
      laravel-ssr)
        cat > "$INFRA_DIR/buildspecs/ci.yml" << 'CISPEC_EOF'
version: 0.2

env:
  secrets-manager:
    DOCKERHUB_USERNAME: "${SERVICE_NAME}/dockerhub:username"
    DOCKERHUB_TOKEN: "${SERVICE_NAME}/dockerhub:password"

phases:
  install:
    commands:
      - echo "Logging in to Docker Hub..."
      - |
        if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
          echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
          echo "Docker Hub login successful"
        fi

  pre_build:
    commands:
      - echo "Running CI with PHP 8.4 + Node 24 on ARM64..."
      - |
        docker run --rm -v "$CODEBUILD_SRC_DIR:/app" -w /app php:8.4-cli-alpine sh -c "
          apk add --no-cache curl git unzip nodejs=~24 linux-headers \$PHPIZE_DEPS &&
          docker-php-ext-install pcntl &&
          curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
          composer install --no-interaction --prefer-dist --optimize-autoloader &&
          node .yarn/releases/yarn-*.cjs install --immutable &&
          cp .env.example .env &&
          php artisan key:generate &&
          node .yarn/releases/yarn-*.cjs build &&
          vendor/bin/pint --test &&
          php artisan test --compact
        "

cache:
  paths:
    - '/root/.docker/**/*'
CISPEC_EOF
        ;;
      laravel-api)
        cat > "$INFRA_DIR/buildspecs/ci.yml" << 'CISPEC_EOF'
version: 0.2

env:
  secrets-manager:
    DOCKERHUB_USERNAME: "${SERVICE_NAME}/dockerhub:username"
    DOCKERHUB_TOKEN: "${SERVICE_NAME}/dockerhub:password"

phases:
  install:
    commands:
      - echo "Logging in to Docker Hub..."
      - |
        if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
          echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
          echo "Docker Hub login successful"
        fi

  pre_build:
    commands:
      - echo "Running CI with PHP 8.4 on ARM64..."
      - |
        docker run --rm -v "$CODEBUILD_SRC_DIR:/app" -w /app php:8.4-cli-alpine sh -c "
          apk add --no-cache curl git unzip linux-headers \$PHPIZE_DEPS &&
          docker-php-ext-install pcntl &&
          curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
          composer install --no-interaction --prefer-dist --optimize-autoloader &&
          cp .env.example .env &&
          php artisan key:generate &&
          vendor/bin/pint --test &&
          php artisan test --compact
        "

cache:
  paths:
    - '/root/.docker/**/*'
CISPEC_EOF
        ;;
      nodejs)
        cat > "$INFRA_DIR/buildspecs/ci.yml" << 'CISPEC_EOF'
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 20
    commands:
      - echo "Installing dependencies..."
      - corepack enable
      - yarn install --immutable

  build:
    commands:
      - echo "Running lint..."
      - yarn lint || true
      - echo "Running tests..."
      - yarn test || true
      - echo "Building..."
      - yarn build

cache:
  paths:
    - node_modules/**/*
    - .yarn/cache/**/*
CISPEC_EOF
        ;;
      *)
        cat > "$INFRA_DIR/buildspecs/ci.yml" << 'CISPEC_EOF'
version: 0.2

phases:
  build:
    commands:
      - echo "CI stage - add your test commands here"
CISPEC_EOF
        ;;
    esac
    log_success "Created infra/aws/buildspecs/ci.yml"

    # Generate buildspec for CD (common for all project types)
    cat > "$INFRA_DIR/buildspecs/cd.yml" << 'CDSPEC_EOF'
version: 0.2

env:
  secrets-manager:
    DOCKERHUB_USERNAME: "${SERVICE_NAME}/dockerhub:username"
    DOCKERHUB_TOKEN: "${SERVICE_NAME}/dockerhub:password"

phases:
  install:
    commands:
      - echo "Logging in to Docker Hub..."
      - |
        if [ -n "$DOCKERHUB_USERNAME" ] && [ -n "$DOCKERHUB_TOKEN" ]; then
          echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
          echo "Docker Hub login successful"
        fi

  pre_build:
    commands:
      - echo "Building frontend assets with PHP 8.4 + Node 24..."
      - |
        docker run --rm -v "$CODEBUILD_SRC_DIR:/app" -w /app php:8.4-cli-alpine sh -c "
          apk add --no-cache curl git unzip nodejs=~24 linux-headers \$PHPIZE_DEPS &&
          docker-php-ext-install pcntl &&
          curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer &&
          composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev &&
          node .yarn/releases/yarn-*.cjs install --immutable &&
          node .yarn/releases/yarn-*.cjs build
        "
      - echo "Logging in to Amazon ECR..."
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/$ECR_REPOSITORY
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}

  build:
    commands:
      - echo "Building Docker image..."
      - docker build -t $IMAGE_URI:$IMAGE_TAG .
      - docker tag $IMAGE_URI:$IMAGE_TAG $IMAGE_URI:latest

  post_build:
    commands:
      - echo "Pushing Docker image to ECR..."
      - docker push $IMAGE_URI:$IMAGE_TAG
      - docker push $IMAGE_URI:latest
      - echo "Updating ECS service..."
      - aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
      - echo "Deployment initiated successfully!"

cache:
  paths:
    - '/root/.docker/**/*'
    - 'vendor/**/*'
    - 'node_modules/**/*'
    - '.yarn/cache/**/*'
CDSPEC_EOF
    log_success "Created infra/aws/buildspecs/cd.yml"
  fi

  log_success "Created infra/aws/main.tf"

  # Create variables.tf for AWS
  cat > "$INFRA_DIR/variables.tf" << 'EOF'
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Service name (used for ECS service and resource naming)"
  type        = string
}

variable "org_name" {
  description = "Organization name (used for globally unique resource naming)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/up"
}

variable "ecs_cpu" {
  description = "CPU units for ECS task (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "1024"
}

variable "ecs_memory" {
  description = "Memory for ECS task in MB"
  type        = string
  default     = "2048"
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 1
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 4
}

variable "env_vars" {
  description = "Environment variables for ECS task"
  type        = map(string)
  default     = {}
}

variable "secret_keys" {
  description = "List of secret environment variable names. Used for creating Secrets Manager secrets with service_name prefix."
  type        = list(string)
  default     = []
}

variable "secret_values" {
  description = "Map of secret values (ENV_NAME => value). Values come from GitHub Secrets via -var in CI/CD."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag for ECS deployment"
  type        = string
  default     = "latest"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS (leave empty for HTTP only)"
  type        = string
  default     = ""
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs that the task can access"
  type        = list(string)
  default     = []
}

variable "deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "assign_public_ip" {
  description = "Assign public IP to Fargate tasks (for outbound internet access without NAT)"
  type        = bool
  default     = false
}

# RDS Variables
variable "create_rds" {
  description = "Create RDS PostgreSQL instance"
  type        = bool
  default     = false
}

variable "rds_database_name" {
  description = "Database name"
  type        = string
  default     = "app"
}

variable "rds_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = ""
}

# Valkey Variables
variable "create_valkey" {
  description = "Create ElastiCache Valkey instance (Redis-compatible)"
  type        = bool
  default     = false
}

# Docker Hub credentials (to avoid rate limiting)
variable "dockerhub_username" {
  description = "Docker Hub username (optional, avoids rate limiting)"
  type        = string
  default     = ""
}

variable "dockerhub_token" {
  description = "Docker Hub access token (optional, avoids rate limiting)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_token" {
  description = "GitHub PAT for CodeBuild webhooks (CI on PRs to develop)"
  type        = string
  sensitive   = true
  default     = ""
}
EOF
  log_success "Created infra/aws/variables.tf"

  # Create outputs.tf for AWS
  cat > "$INFRA_DIR/outputs.tf" << 'EOF'
output "oidc_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = module.oidc_provider.role_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs_fargate.alb_dns_name
}

output "service_url" {
  description = "Service URL"
  value       = module.ecs_fargate.service_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_fargate.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs_fargate.service_name
}

# RDS outputs (only when create_rds = true)
output "rds_endpoint" {
  description = "RDS endpoint (host:port)"
  value       = var.create_rds ? module.rds_postgres[0].endpoint : null
}

output "rds_address" {
  description = "RDS hostname"
  value       = var.create_rds ? module.rds_postgres[0].address : null
}

output "rds_database_name" {
  description = "RDS database name"
  value       = var.create_rds ? module.rds_postgres[0].database_name : null
}

# Valkey outputs (only when create_valkey = true)
output "valkey_primary_endpoint" {
  description = "Valkey primary endpoint"
  value       = var.create_valkey ? module.elasticache_valkey[0].primary_endpoint : null
}

output "valkey_reader_endpoint" {
  description = "Valkey reader endpoint"
  value       = var.create_valkey ? module.elasticache_valkey[0].reader_endpoint : null
}

output "valkey_port" {
  description = "Valkey port"
  value       = var.create_valkey ? module.elasticache_valkey[0].port : null
}

output "valkey_redis_url" {
  description = "Redis-compatible connection URL"
  value       = var.create_valkey ? module.elasticache_valkey[0].redis_url : null
}
EOF
  log_success "Created infra/aws/outputs.tf"

  # Create .gitignore for terraform
  cat > "$INFRA_DIR/.gitignore" << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
.terraform.lock.hcl
tfplan
EOF
  log_success "Created infra/aws/.gitignore"

  # Format terraform files
  log_info "Formatting terraform files..."
  terraform -chdir="$INFRA_DIR" fmt > /dev/null
  log_success "Terraform files formatted"

  # Create GitHub workflows for AWS (only for amd64 - ARM uses CodeBuild webhooks)
  print_header "Step 6: Creating GitHub Workflows"

  if [[ "$CPU_ARCH" == "arm64" ]]; then
    log_info "ARM64 architecture selected - skipping GitHub Actions workflows"
    log_info "CI/CD will run on AWS CodeBuild with GitHub webhooks for native ARM64 builds"
    log_success "CodeBuild CI/CD configured in main.tf"
  else
    # Generate build steps based on project type (same as GCP)
    case "$PROJECT_TYPE" in
    nodejs)
      CI_BUILD_STEPS="      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Cache Next.js build
        uses: actions/cache@v5
        with:
          path: \${{ github.workspace }}/.next/cache
          key: \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-\${{ hashFiles('**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx', '**/*.css', '**/*.scss') }}
          restore-keys: |
            \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-

      - name: Install dependencies
        run: yarn install --immutable

      - name: Build application
        run: yarn build
        env:
          NODE_ENV: production"
      CI_BUILD_NAME="Build & Validate"
      ;;
    java-maven)
      CI_BUILD_STEPS="      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Build with Maven
        run: mvn package -DskipTests"
      CI_BUILD_NAME="Build & Validate"
      ;;
    java-gradle)
      CI_BUILD_STEPS="      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: gradle

      - name: Build with Gradle
        run: ./gradlew build -x test"
      CI_BUILD_NAME="Build & Validate"
      ;;
    laravel-api)
      CI_BUILD_STEPS="      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Prepare Laravel
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Run Pint (code style)
        run: vendor/bin/pint --test

      - name: Run tests
        run: php artisan test --compact
        env:
          APP_ENV: testing"
      CI_BUILD_NAME="Build & Test"
      ;;
    laravel-ssr)
      CI_BUILD_STEPS="      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install PHP dependencies
        run: composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Prepare Laravel
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Install Node.js dependencies
        run: yarn install --immutable

      - name: Build frontend assets
        run: yarn build

      - name: Run Pint (code style)
        run: vendor/bin/pint --test

      - name: Run tests
        run: php artisan test --compact
        env:
          APP_ENV: testing"
      CI_BUILD_NAME="Build & Test"
      ;;
    docker-only)
      CI_BUILD_STEPS="      - name: Build Docker image (validation)
        run: docker build -t test-build ."
      CI_BUILD_NAME="Build & Validate"
      ;;
  esac

  # Create CI workflow (same for all providers)
  CI_CONTENT="name: CI

on:
  pull_request:
    branches:
      - develop
      - main
    paths-ignore:
      - '*.md'

permissions:
  contents: read
  pull-requests: read

jobs:
  build:
    name: $CI_BUILD_NAME
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

$CI_BUILD_STEPS
"

  echo -e "$CI_CONTENT" > "$WORKFLOWS_DIR/ci.yml"
  log_success "Created .github/workflows/ci.yml"

  # Build env vars string for CD workflow (build-time variables)
  CD_BUILD_ENV_VARS="          NODE_ENV: production"
  if [[ -f "$BUILD_KEYS_FILE" ]] && [[ -s "$BUILD_KEYS_FILE" ]]; then
    while IFS= read -r key; do
      CD_BUILD_ENV_VARS+="\n          $key: \${{ vars.$key }}"
    done < "$BUILD_KEYS_FILE"
  fi

  # Generate CD build steps
  case "$PROJECT_TYPE" in
    nodejs)
      CD_BUILD_STEPS="
      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Install dependencies
        run: yarn install --immutable

      - name: Build application
        run: yarn build
        env:
$(echo -e "$CD_BUILD_ENV_VARS")
"
      ;;
    laravel-api)
      CD_BUILD_STEPS="
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Install dependencies
        run: composer install --no-dev --optimize-autoloader --no-interaction
"
      ;;
    laravel-ssr)
      CD_BUILD_STEPS="
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Install PHP dependencies
        run: composer install --no-dev --optimize-autoloader --no-interaction

      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Install Node.js dependencies
        run: yarn install --immutable

      - name: Build frontend assets
        run: yarn build
"
      ;;
    java-maven)
      CD_BUILD_STEPS="
      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Build with Maven
        run: mvn package -DskipTests
"
      ;;
    java-gradle)
      CD_BUILD_STEPS="
      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: gradle

      - name: Build with Gradle
        run: ./gradlew build -x test
"
      ;;
    docker-only)
      CD_BUILD_STEPS=""
      ;;
  esac

  # Build TF_VAR_secret_values env var for Terraform (JSON format)
  if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
    SECRET_ENV_BLOCK="          TF_VAR_secret_values: |"
    SECRET_ENV_BLOCK+="\n            {"
    first_key=true
    while IFS= read -r key; do
      if [[ "$first_key" == "true" ]]; then
        first_key=false
      else
        SECRET_ENV_BLOCK+=","
      fi
      SECRET_ENV_BLOCK+="\n              \"$key\": \"\${{ secrets.$key }}\""
    done < "$SECRET_KEYS_FILE"
    SECRET_ENV_BLOCK+="\n            }"
  else
    SECRET_ENV_BLOCK=""
  fi

  # Determine GitHub runner and Docker platform based on CPU architecture
  if [[ "$CPU_ARCH" == "arm64" ]]; then
    GH_RUNNER="ubuntu-24.04-arm"
    DOCKER_PLATFORM="linux/arm64"
  else
    GH_RUNNER="ubuntu-latest"
    DOCKER_PLATFORM="linux/amd64"
  fi

  # Create AWS CD workflow
  CD_CONTENT="name: CD

on:
  push:
    branches:
      - main
    paths-ignore:
      - '*.md'

permissions:
  contents: read
  id-token: write

env:
  REGION: $REGION
  SERVICE_NAME: $SERVICE_NAME
  AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID

jobs:
  deploy:
    name: Build & Deploy
    runs-on: $GH_RUNNER
    environment: Production

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v5
        with:
          role-to-assume: \${{ secrets.AWS_ROLE_ARN }}
          aws-region: \${{ env.REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
$CD_BUILD_STEPS
      - name: Build Docker image
        env:
          ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ecr-\${{ env.SERVICE_NAME }}
          IMAGE_TAG: \${{ github.sha }}
        run: |
          docker build -t \$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG .
          docker tag \$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG \$ECR_REGISTRY/\$ECR_REPOSITORY:latest

      - name: Push Docker image
        env:
          ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ecr-\${{ env.SERVICE_NAME }}
          IMAGE_TAG: \${{ github.sha }}
        run: |
          docker push \$ECR_REGISTRY/\$ECR_REPOSITORY:\$IMAGE_TAG
          docker push \$ECR_REGISTRY/\$ECR_REPOSITORY:latest

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: \"~> 1.10\"

      - name: Terraform Init
        working-directory: infra/aws
        run: terraform init

      - name: Terraform Apply
        working-directory: infra/aws
        env:
          TF_VAR_image_tag: \${{ github.sha }}
$(echo -e "$SECRET_ENV_BLOCK")
        run: terraform apply -var-file=terraform.tfvars -auto-approve -input=false"

    echo -e "$CD_CONTENT" > "$WORKFLOWS_DIR/cd.yml"
    log_success "Created .github/workflows/cd.yml"
  fi

  # Run terraform if not skipped
  if [[ "$SKIP_TERRAFORM" != "true" ]]; then
    print_header "Step 7: Running Terraform"

    cd "$INFRA_DIR"

    if [[ -d ".terraform" ]]; then
      log_info "Cleaning up old terraform cache..."
      rm -rf .terraform
    fi

    log_info "Terraform init..."
    terraform init -upgrade

    # Import existing ECR repository if it exists
    ECR_REPO_NAME="ecr-${SERVICE_NAME}"
    if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" &>/dev/null; then
      log_info "ECR repository '$ECR_REPO_NAME' already exists, importing..."
      terraform import -var-file=terraform.tfvars 'module.ecr.aws_ecr_repository.main' "$ECR_REPO_NAME" 2>/dev/null || true
    fi

    # Import existing secrets if they exist in AWS Secrets Manager
    if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
      log_info "Checking for existing secrets to import..."
      while IFS= read -r key; do
        secret_name="${SERVICE_NAME}/$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
        secret_arn=$(aws secretsmanager describe-secret --secret-id "$secret_name" --region "$REGION" --query 'ARN' --output text 2>/dev/null || echo "")
        if [[ -n "$secret_arn" && "$secret_arn" != "None" ]]; then
          if ! terraform state show "aws_secretsmanager_secret.secrets[\"$key\"]" &>/dev/null; then
            log_info "Secret '$secret_name' exists, importing..."
            terraform import -var-file=terraform.tfvars "aws_secretsmanager_secret.secrets[\"$key\"]" "$secret_arn" 2>/dev/null || true
            terraform import -var-file=terraform.tfvars "aws_secretsmanager_secret_version.secrets[\"$key\"]" "$secret_arn|AWSCURRENT" 2>/dev/null || true
          fi
        fi
      done < "$SECRET_KEYS_FILE"
    fi

    # Build secret_values for local terraform commands
    SECRET_VALUES_VAR=""
    if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
      SECRET_VAR_ITEMS=""
      while IFS= read -r key && IFS= read -r value <&3; do
        if [[ -n "$SECRET_VAR_ITEMS" ]]; then
          SECRET_VAR_ITEMS+=","
        fi
        escaped_value=$(echo "$value" | sed 's/"/\\"/g')
        SECRET_VAR_ITEMS+="\"$key\":\"$escaped_value\""
      done < "$SECRET_KEYS_FILE" 3< "$SECRET_VALUES_FILE"
      SECRET_VALUES_VAR="-var=secret_values={$SECRET_VAR_ITEMS}"
    fi

    log_info "Terraform plan..."
    terraform plan -var-file=terraform.tfvars $SECRET_VALUES_VAR -out=tfplan

    echo ""
    APPLY_PLAN="false"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
      APPLY_PLAN="true"
    else
      read -p "Apply this plan? (y/n) " -n 1 -r < /dev/tty
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        APPLY_PLAN="true"
      fi
    fi

    if [[ "$APPLY_PLAN" == "true" ]]; then
      log_info "Terraform apply..."
      if terraform apply tfplan; then
        log_success "Terraform applied"
      else
        log_error "Terraform apply failed"
        exit 1
      fi

      # Get outputs for GitHub secrets
      AWS_ROLE_ARN=$(terraform output -raw oidc_role_arn 2>/dev/null || echo "")
    else
      log_warn "Skipped terraform apply"
    fi

    cd - > /dev/null
  else
    log_warn "Skipped terraform (use --skip-terraform=false to run)"
  fi

  # Configure secrets based on architecture
  if [[ "$CPU_ARCH" == "arm64" ]]; then
    print_header "Step 8: AWS Secrets Manager (ARM64 CodeBuild)"
    log_info "ARM64 uses AWS CodeBuild with webhooks - secrets are managed by Terraform in AWS Secrets Manager"
    log_info "Secrets configured in terraform.tfvars → secret_keys"
    log_info "Values are stored in AWS Secrets Manager with prefix: ${SERVICE_NAME}/"
    log_success "No GitHub Secrets needed for ARM64 CodeBuild flow"
  else
    # Configure GitHub secrets (only for amd64 GitHub Actions flow)
    print_header "Step 8: GitHub Secrets Configuration"

    if command -v gh &> /dev/null; then
      log_info "GitHub CLI detected. Checking authentication..."

      if gh auth token &>/dev/null; then
        log_success "GitHub CLI authenticated"

        echo ""
        CONFIGURE_SECRETS="false"
        if [[ "$AUTO_APPROVE" == "true" ]]; then
          CONFIGURE_SECRETS="true"
        else
          read -p "Configure GitHub secrets automatically? (y/n) " -n 1 -r < /dev/tty
          echo ""
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            CONFIGURE_SECRETS="true"
          fi
        fi

        if [[ "$CONFIGURE_SECRETS" == "true" ]]; then
          log_info "Configuring GitHub secrets for $GITHUB_REPO (environment: Production)..."

          gh api "repos/$GITHUB_REPO/environments/Production" --method PUT --silent 2>/dev/null || true

          if [[ -n "$AWS_ROLE_ARN" ]]; then
            echo "$AWS_ROLE_ARN" | gh secret set AWS_ROLE_ARN --repo="$GITHUB_REPO" --env=Production
            log_success "Set AWS_ROLE_ARN"
          fi

          # Set build-time variables
          if [[ -f "$BUILD_KEYS_FILE" ]] && [[ -s "$BUILD_KEYS_FILE" ]]; then
            log_info "Creating GitHub Variables for build-time env vars..."
            while IFS= read -r key && IFS= read -r value <&3; do
              echo "$value" | gh variable set "$key" --repo="$GITHUB_REPO" --env=Production
              log_success "Set variable: $key"
            done < "$BUILD_KEYS_FILE" 3< "$BUILD_VALUES_FILE"
          fi

          # Set secrets for Terraform
          if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
            log_info "Creating GitHub Secrets for Terraform-managed secrets..."
            while IFS= read -r key && IFS= read -r value <&3; do
              echo "$value" | gh secret set "$key" --repo="$GITHUB_REPO" --env=Production
              log_success "Set secret: $key"
            done < "$SECRET_KEYS_FILE" 3< "$SECRET_VALUES_FILE"
          fi

          log_success "GitHub secrets and variables configured in 'Production' environment!"
        else
          log_warn "Skipped GitHub secrets configuration"
        fi
      else
        log_warn "GitHub CLI not authenticated. Run: gh auth login"
      fi
    else
      log_warn "GitHub CLI not found. Install it to auto-configure secrets: https://cli.github.com"
    fi
  fi

  # Manual instructions if secrets not configured (only for amd64 GitHub Actions flow)
  if [[ "$CPU_ARCH" != "arm64" ]] && { [[ -z "$AWS_ROLE_ARN" ]] || ! command -v gh &> /dev/null; }; then
    echo ""
    echo "Add these secrets to your GitHub repository manually:"
    echo ""
    echo "┌────────────────────────────────────────────────────────────────────┐"
    echo "│ Repository Settings → Secrets and variables → Actions             │"
    echo "│ Environment: Production                                            │"
    echo "├────────────────────────────────────────────────────────────────────┤"
    echo "│                                                                    │"
    echo "│ AWS_ROLE_ARN:                                                      │"
    if [[ -n "$AWS_ROLE_ARN" ]]; then
      echo "│ $AWS_ROLE_ARN"
    else
      echo "│ (run terraform apply first)"
    fi
    if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
      echo "│                                                                    │"
      echo "│ Terraform-managed secrets (from .env):                             │"
      while IFS= read -r key; do
        echo "│   • $key"
      done < "$SECRET_KEYS_FILE"
    fi
    echo "│                                                                    │"
    echo "└────────────────────────────────────────────────────────────────────┘"
  fi

  # Custom domain configuration for AWS
  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    print_header "Step 9: Custom Domain Configuration"

    # Get ALB DNS name
    ALB_DNS_NAME=$(terraform -chdir="$INFRA_DIR" output -raw alb_dns_name 2>/dev/null || echo "")

    echo "Custom domain: $CUSTOM_DOMAIN"
    echo ""

    # Extract subdomain and root domain
    ROOT_DOMAIN=$(echo "$CUSTOM_DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
    SUBDOMAIN="${CUSTOM_DOMAIN%%.$ROOT_DOMAIN}"
    if [[ "$SUBDOMAIN" == "$CUSTOM_DOMAIN" ]]; then
      SUBDOMAIN="@"
    fi

    echo "┌────────────────────────────────────────────────────────────────────┐"
    echo "│  Step 1: Create/Verify ACM Certificate                             │"
    echo "├────────────────────────────────────────────────────────────────────┤"
    echo "│                                                                    │"
    echo "│  If you don't have an ACM certificate yet:                         │"
    echo "│                                                                    │"
    echo "│  aws acm request-certificate \\                                     │"
    echo "│    --domain-name $CUSTOM_DOMAIN \\                                  │"
    echo "│    --validation-method DNS \\                                       │"
    echo "│    --region $REGION                                                │"
    echo "│                                                                    │"
    echo "│  Then add the CNAME validation record to your DNS provider.        │"
    echo "│                                                                    │"
    if [[ -n "$CERTIFICATE_ARN" ]]; then
    echo "│  ✓ Certificate ARN provided: $CERTIFICATE_ARN                      │"
    else
    echo "│  ⚠ No --certificate-arn provided. HTTPS will not be enabled.       │"
    echo "│    Re-run with --certificate-arn=ARN after creating certificate.   │"
    fi
    echo "│                                                                    │"
    echo "└────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "┌────────────────────────────────────────────────────────────────────┐"
    echo "│  Step 2: Configure DNS Records                                     │"
    echo "├────────────────────────────────────────────────────────────────────┤"
    echo "│                                                                    │"
    echo "│  Add this record in your DNS provider:                             │"
    echo "│                                                                    │"
    echo "│  Type:   CNAME                                                     │"
    echo "│  Name:   $SUBDOMAIN                                                │"
    if [[ -n "$ALB_DNS_NAME" ]]; then
    echo "│  Target: $ALB_DNS_NAME                                             │"
    else
    echo "│  Target: (run terraform apply to get ALB DNS name)                 │"
    fi
    echo "│  TTL:    300 (or Auto)                                             │"
    echo "│                                                                    │"
    echo "│  Note: For root domain (@), use an ALIAS/ANAME record if your      │"
    echo "│  DNS provider supports it, or use a subdomain (www, app, etc.)     │"
    echo "│                                                                    │"
    echo "└────────────────────────────────────────────────────────────────────┘"
    echo ""
    log_info "After DNS propagation, your service will be available at:"
    if [[ -n "$CERTIFICATE_ARN" ]]; then
      echo "  https://$CUSTOM_DOMAIN"
    else
      echo "  http://$CUSTOM_DOMAIN"
    fi
    echo ""
  fi

  print_header "Bootstrap Complete!"

  echo "Generated files:"
  echo "  $INFRA_DIR/"
  echo "    ├── main.tf"
  echo "    ├── variables.tf"
  echo "    ├── outputs.tf"
  echo "    ├── terraform.tfvars"
  echo "    └── .gitignore"
  echo "  $WORKFLOWS_DIR/"
  echo "    ├── ci.yml              (build & test - runs on PR)"
  echo "    └── cd.yml              (build + deploy - runs on push to main)"
  echo ""
  echo "Next steps:"
  echo "  1. Review generated files"
  echo "  2. Commit and push to GitHub"
  echo "  3. The CD pipeline will build and deploy on push to main"
  if [[ -n "$CUSTOM_DOMAIN" && -z "$CERTIFICATE_ARN" ]]; then
  echo "  4. Create ACM certificate and re-run with --certificate-arn"
  echo "  5. Configure DNS CNAME record"
  elif [[ -n "$CUSTOM_DOMAIN" ]]; then
  echo "  4. Configure DNS CNAME record pointing to ALB"
  fi
  echo ""

  # Show service URL
  ALB_DNS_NAME=$(terraform -chdir="$INFRA_DIR" output -raw alb_dns_name 2>/dev/null || echo "")
  if [[ -n "$ALB_DNS_NAME" ]]; then
    echo "Service URL: http://$ALB_DNS_NAME"
    if [[ -n "$CUSTOM_DOMAIN" ]]; then
      if [[ -n "$CERTIFICATE_ARN" ]]; then
        echo "Custom URL:  https://$CUSTOM_DOMAIN (after DNS configuration)"
      else
        echo "Custom URL:  http://$CUSTOM_DOMAIN (after DNS configuration)"
      fi
    fi
    echo ""
  fi

  log_success "Done!"
  exit 0
fi

# ============================================================================
# GCP PROVIDER FLOW (existing implementation below)
# ============================================================================

print_header "GCP Cloud Run Bootstrap"

echo "Configuration:"
echo "  Provider:         $PROVIDER"
echo "  Project ID:       $PROJECT_ID"
echo "  Region:           $REGION"
echo "  Service Name:     $SERVICE_NAME"
echo "  Registry Name:    $REGISTRY_NAME"
echo "  GitHub Repo:      $GITHUB_REPO"
echo "  Modules Repo:     $TERRAFORM_MODULES_REPO"
echo "  State Bucket:     $STATE_BUCKET"
echo "  Output Dir:       $OUTPUT_DIR"
echo "  Project Type:     $PROJECT_TYPE"
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  echo "  Custom Domain:    $CUSTOM_DOMAIN"
fi
if [[ -n "$VPC_NETWORK" && -n "$VPC_SUBNETWORK" ]]; then
  echo "  VPC Network:      $VPC_NETWORK (Direct VPC Egress)"
  echo "  VPC Subnetwork:   $VPC_SUBNETWORK"
fi
echo ""

# Check gcloud auth
print_header "Step 1: Checking Authentication"

if ! gcloud auth print-access-token &>/dev/null; then
  log_error "Not authenticated. Please run: gcloud auth login"
  exit 1
fi
log_success "gcloud authenticated"

if ! gcloud auth application-default print-access-token &>/dev/null; then
  log_warn "Application default credentials not set"
  log_info "Running: gcloud auth application-default login"
  gcloud auth application-default login
fi
log_success "Application default credentials set"

# Create project if requested
if [[ "$CREATE_PROJECT" == "true" ]]; then
  print_header "Step 2: Creating GCP Project"

  if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    log_warn "Project $PROJECT_ID already exists"
  else
    log_info "Creating project: $PROJECT_ID"
    gcloud projects create "$PROJECT_ID" --name="$PROJECT_ID"
    log_success "Project created"

    log_info "Linking billing account"
    gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
    log_success "Billing linked"
  fi
else
  print_header "Step 2: Verifying GCP Project"

  if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    log_error "Project $PROJECT_ID does not exist. Use --create-project to create it."
    exit 1
  fi
  log_success "Project exists"
fi

# Set project and quota project
gcloud config set project "$PROJECT_ID"
gcloud auth application-default set-quota-project "$PROJECT_ID" --quiet 2>/dev/null || true

# Enable APIs
print_header "Step 3: Enabling APIs"

APIS=(
  "run.googleapis.com"
  "artifactregistry.googleapis.com"
  "secretmanager.googleapis.com"
  "iam.googleapis.com"
  "iamcredentials.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "sqladmin.googleapis.com"
  "compute.googleapis.com"
)

for api in "${APIS[@]}"; do
  log_info "Enabling $api..."
  gcloud services enable "$api" --quiet
done
log_success "All APIs enabled"

# Create state bucket
print_header "Step 4: Creating Terraform State Bucket"

if gcloud storage buckets describe "gs://$STATE_BUCKET" &>/dev/null; then
  log_warn "Bucket $STATE_BUCKET already exists"
else
  log_info "Creating bucket: $STATE_BUCKET"
  gcloud storage buckets create "gs://$STATE_BUCKET" \
    --location="$REGION" \
    --uniform-bucket-level-access
  log_success "Bucket created"
fi

# Create Artifact Registry and push initial image
print_header "Step 5: Building & Pushing Initial Docker Image"

ARTIFACT_REGISTRY="$REGION-docker.pkg.dev/$PROJECT_ID/$REGISTRY_NAME"
IMAGE_NAME="$ARTIFACT_REGISTRY/$SERVICE_NAME:latest"

# Create Artifact Registry if it doesn't exist
if ! gcloud artifacts repositories describe "$REGISTRY_NAME" --location="$REGION" &>/dev/null; then
  log_info "Creating Artifact Registry: $REGISTRY_NAME"
  gcloud artifacts repositories create "$REGISTRY_NAME" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for $SERVICE_NAME"
  log_success "Artifact Registry created"
else
  log_warn "Artifact Registry $REGISTRY_NAME already exists"
fi

# Configure Docker authentication
log_info "Configuring Docker authentication..."
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
log_success "Docker configured"

# Check if Dockerfile exists in output directory
if [[ -f "$OUTPUT_DIR/Dockerfile" ]]; then
  # Run build based on project type
  cd "$OUTPUT_DIR"
  case "$PROJECT_TYPE" in
    nodejs)
      log_info "Building Node.js application..."
      if command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
        yarn install --immutable 2>/dev/null || yarn install
        yarn build
      elif command -v npm &>/dev/null; then
        npm ci 2>/dev/null || npm install
        npm run build
      fi
      log_success "Node.js application built"
      ;;
    laravel-api)
      log_info "Building Laravel API application..."
      log_success "Laravel API ready (composer install runs inside Docker)"
      ;;
    laravel-ssr)
      log_info "Building Laravel SSR application..."
      if command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
        yarn install --immutable 2>/dev/null || yarn install
        yarn build
      elif command -v npm &>/dev/null; then
        npm ci 2>/dev/null || npm install
        npm run build
      fi
      log_success "Laravel SSR application built (composer install runs inside Docker)"
      ;;
    java-maven)
      log_info "Building Java application with Maven..."
      mvn package -DskipTests
      log_success "Maven build completed"
      ;;
    java-gradle)
      log_info "Building Java application with Gradle..."
      ./gradlew build -x test
      log_success "Gradle build completed"
      ;;
    docker-only)
      log_info "Skipping application build (docker-only mode)"
      ;;
  esac
  cd - > /dev/null

  log_info "Building Docker image (linux/amd64,linux/arm64)..."

  # Use buildx for multiplatform build
  if docker buildx version &>/dev/null; then
    # Create builder if needed
    docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch 2>/dev/null || true
    docker buildx build --platform linux/amd64,linux/arm64 -t "$IMAGE_NAME" "$OUTPUT_DIR" --push
  else
    docker build -t "$IMAGE_NAME" "$OUTPUT_DIR"
    log_info "Pushing image to Artifact Registry..."
    docker push "$IMAGE_NAME"
  fi

  log_success "Image pushed: $IMAGE_NAME"
else
  log_warn "No Dockerfile found in $OUTPUT_DIR - skipping image build"
  log_warn "You'll need to build and push the image manually before terraform apply"
fi

# Process environment variables
ENV_VARS_TF=""
SECRET_ENV_VARS_TF=""
CLOUD_SQL_INSTANCE=""

# Auto-detect env file if --env-file not specified
if [[ -z "$ENV_FILE" ]]; then
  case "$PROJECT_TYPE" in
    laravel-api|laravel-ssr)
      # Laravel uses .env.production
      if [[ -f "$OUTPUT_DIR/.env.production" ]]; then
        ENV_FILE="$OUTPUT_DIR/.env.production"
      fi
      ;;
    *)
      # Other projects use .env.local
      if [[ -f "$OUTPUT_DIR/.env.local" ]]; then
        ENV_FILE="$OUTPUT_DIR/.env.local"
      fi
      ;;
  esac
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  print_header "Step 5.5: Processing Environment Variables"

  log_info "Reading environment file: $ENV_FILE"
  echo ""
  echo "┌────────────────────────────────────────────────────────────────────┐"
  echo "│  Annotation syntax:                                                │"
  echo "│    # @secret    → GCP Secret Manager (runtime)                     │"
  echo "│    # @build     → GitHub Variables (build-time)                    │"
  echo "│    # @public    → Cloud Run env vars (runtime, default)            │"
  if [[ "$PROJECT_TYPE" == "nodejs" ]]; then
  echo "│    NEXT_PUBLIC_* without tag → auto-detected as @build             │"
  fi
  echo "└────────────────────────────────────────────────────────────────────┘"
  echo ""

  # Use temp files instead of associative arrays (bash 3.x compatibility)
  ENV_KEYS_FILE=$(mktemp)
  ENV_VALUES_FILE=$(mktemp)
  SECRET_KEYS_FILE=$(mktemp)
  SECRET_VALUES_FILE=$(mktemp)
  BUILD_KEYS_FILE=$(mktemp)
  BUILD_VALUES_FILE=$(mktemp)
  trap "rm -f $ENV_KEYS_FILE $ENV_VALUES_FILE $SECRET_KEYS_FILE $SECRET_VALUES_FILE $BUILD_KEYS_FILE $BUILD_VALUES_FILE" EXIT

  next_marker=""
  env_count=0
  secret_count=0
  build_count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Check for @secret, @build, or @public markers
    if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@secret ]]; then
      next_marker="secret"
      continue
    elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@build ]]; then
      next_marker="build"
      continue
    elif [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@public ]]; then
      next_marker="public"
      continue
    fi

    # Skip other comments
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse KEY=VALUE
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"

      # Remove surrounding quotes if present
      value="${value#\"}"
      value="${value%\"}"
      value="${value#\'}"
      value="${value%\'}"

      # Classify based on marker (priority) or name (fallback)
      if [[ "$next_marker" == "secret" ]]; then
        echo "$key" >> "$SECRET_KEYS_FILE"
        echo "$value" >> "$SECRET_VALUES_FILE"
        ((secret_count++))
      elif [[ "$next_marker" == "build" ]] || { [[ "$PROJECT_TYPE" == "nodejs" ]] && [[ "$key" == NEXT_PUBLIC_* ]]; }; then
        # @build tag or NEXT_PUBLIC_* auto-detected as build-time (nodejs only)
        echo "$key" >> "$BUILD_KEYS_FILE"
        echo "$value" >> "$BUILD_VALUES_FILE"
        ((build_count++))
      else
        echo "$key" >> "$ENV_KEYS_FILE"
        echo "$value" >> "$ENV_VALUES_FILE"
        ((env_count++))
      fi

      # Auto-detect Cloud SQL from DB_HOST=/cloudsql/...
      if [[ "$key" == "DB_HOST" && "$value" == /cloudsql/* ]]; then
        CLOUD_SQL_INSTANCE="${value#/cloudsql/}"
      fi

      # Capture DB_DATABASE for Cloud SQL database creation
      if [[ "$key" == "DB_DATABASE" ]]; then
        DB_DATABASE="$value"
      fi

      # Auto-detect GCS bucket from GOOGLE_CLOUD_STORAGE_BUCKET
      if [[ "$key" == "GOOGLE_CLOUD_STORAGE_BUCKET" && -n "$value" ]]; then
        if [[ -z "$STORAGE_BUCKET" ]]; then
          STORAGE_BUCKET="$value"
        fi
      fi

      # Reset marker for next variable
      next_marker=""
    fi
  done < "$ENV_FILE"

  # Display grouped by type
  if [[ $secret_count -gt 0 ]]; then
    echo ""
    echo -e "${RED}Secrets - GCP Secret Manager ($secret_count):${NC}"
    while IFS= read -r key; do
      echo "  • $key"
    done < "$SECRET_KEYS_FILE"
  fi

  if [[ $build_count -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Build-time Variables - GitHub Variables ($build_count):${NC}"
    while IFS= read -r key; do
      echo "  • $key"
    done < "$BUILD_KEYS_FILE"
  fi

  if [[ $env_count -gt 0 ]]; then
    echo ""
    echo -e "${GREEN}Runtime Variables - Cloud Run ($env_count):${NC}"
    while IFS= read -r key; do
      echo "  • $key"
    done < "$ENV_KEYS_FILE"
  fi

  if [[ -n "$CLOUD_SQL_INSTANCE" ]]; then
    echo ""
    echo -e "${BLUE}Cloud SQL Connection (auto-detected):${NC}"
    echo "  • $CLOUD_SQL_INSTANCE"
  fi

  if [[ -n "$STORAGE_BUCKET" ]]; then
    echo ""
    echo -e "${BLUE}GCS Storage Bucket (auto-detected from GOOGLE_CLOUD_STORAGE_BUCKET):${NC}"
    echo "  • $STORAGE_BUCKET"
  fi

  echo ""

  if [[ $secret_count -gt 0 ]] || [[ $build_count -gt 0 ]]; then
    if [[ "$AUTO_APPROVE" != "true" ]]; then
      read -p "Continue with this classification? (y/n) " -n 1 -r < /dev/tty
      echo ""

      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Aborted. Please update your .env file with @secret/@public markers and try again."
        exit 1
      fi
    fi
  fi

  # Build secret keys list for terraform.tfvars (values will come from GitHub Secrets)
  if [[ $secret_count -gt 0 ]]; then
    log_info "Preparing secrets configuration (Terraform managed)..."

    # Store secret keys for later GitHub Secrets configuration
    SECRET_KEYS_LIST=""
    while IFS= read -r key; do
      SECRET_KEYS_LIST+="$key "
    done < "$SECRET_KEYS_FILE"

    log_success "Secrets will be managed by Terraform via GitHub Secrets"
    log_info "Secret keys: $SECRET_KEYS_LIST"
  fi

  # Create Cloud SQL database if detected
  if [[ -n "$CLOUD_SQL_INSTANCE" && -n "$DB_DATABASE" ]]; then
    # Extract instance name from connection string (project:region:instance -> instance)
    INSTANCE_NAME="${CLOUD_SQL_INSTANCE##*:}"

    log_info "Checking Cloud SQL database: $DB_DATABASE on instance $INSTANCE_NAME..."

    if gcloud sql databases describe "$DB_DATABASE" --instance="$INSTANCE_NAME" &>/dev/null; then
      log_success "Database $DB_DATABASE already exists"
    else
      log_info "Creating database: $DB_DATABASE"
      if gcloud sql databases create "$DB_DATABASE" --instance="$INSTANCE_NAME"; then
        log_success "Database $DB_DATABASE created"
      else
        log_warn "Failed to create database. You may need to create it manually:"
        log_warn "  gcloud sql databases create $DB_DATABASE --instance=$INSTANCE_NAME"
      fi
    fi
  fi

  # Build terraform env_vars
  # First, create a lookup file for variable resolution
  ALL_KEYS_FILE=$(mktemp)
  ALL_VALUES_FILE=$(mktemp)
  cat "$ENV_KEYS_FILE" "$SECRET_KEYS_FILE" "$BUILD_KEYS_FILE" > "$ALL_KEYS_FILE" 2>/dev/null || true
  cat "$ENV_VALUES_FILE" "$SECRET_VALUES_FILE" "$BUILD_VALUES_FILE" > "$ALL_VALUES_FILE" 2>/dev/null || true

  # Function to resolve ${VAR} references
  resolve_env_refs() {
    local value="$1"
    local resolved="$value"
    # Match ${VAR} pattern and replace with actual value
    while [[ "$resolved" =~ \$\{([A-Za-z_][A-Za-z0-9_]*)\} ]]; do
      local var_name="${BASH_REMATCH[1]}"
      local var_value=""
      # Look up the value from our parsed env vars
      local line_num=1
      while IFS= read -r k; do
        if [[ "$k" == "$var_name" ]]; then
          var_value=$(sed -n "${line_num}p" "$ALL_VALUES_FILE")
          break
        fi
        ((line_num++))
      done < "$ALL_KEYS_FILE"
      # Replace the reference with the value (or empty if not found)
      resolved="${resolved/\$\{$var_name\}/$var_value}"
    done
    echo "$resolved"
  }

  ENV_VARS_TF="  NODE_ENV = \"production\"\n"
  if [[ $env_count -gt 0 ]]; then
    while IFS= read -r key && IFS= read -r value <&3; do
      # Resolve ${VAR} references
      resolved_value=$(resolve_env_refs "$value")
      # Escape special characters for terraform
      escaped_value=$(echo "$resolved_value" | sed 's/\\/\\\\/g; s/"/\\"/g')
      ENV_VARS_TF+="  $key = \"$escaped_value\"\n"
    done < "$ENV_KEYS_FILE" 3< "$ENV_VALUES_FILE"
  fi

  rm -f "$ALL_KEYS_FILE" "$ALL_VALUES_FILE"

  if [[ "$PROJECT_TYPE" == "laravel-api" ]] || [[ "$PROJECT_TYPE" == "laravel-ssr" ]]; then
    if ! grep -q "^  LOG_STACK = " <<< "$ENV_VARS_TF"; then
      log_info "Adding cloud-native logging defaults for Laravel..."
      ENV_VARS_TF+="  LOG_STACK = \"stderr\"\n"
      log_success "Set LOG_STACK=stderr (required for container environments)"
    fi
  fi

  log_success "Environment variables processed"
else
  ENV_VARS_TF="  NODE_ENV = \"production\""

  if [[ "$PROJECT_TYPE" == "laravel-api" ]] || [[ "$PROJECT_TYPE" == "laravel-ssr" ]]; then
    ENV_VARS_TF+="\n  LOG_STACK = \"stderr\""
  fi

  log_info "No env file found, using defaults"
fi

# Create directory structure
print_header "Step 6: Creating Project Structure"

mkdir -p "$INFRA_DIR"
mkdir -p "$WORKFLOWS_DIR"
log_success "Created directories: infra/gcp/, .github/workflows/"

# Create terraform.tfvars
cat > "$INFRA_DIR/terraform.tfvars" << EOF
project_id    = "$PROJECT_ID"
region        = "$REGION"
service_name  = "$SERVICE_NAME"
registry_name = "$REGISTRY_NAME"
github_repo   = "$GITHUB_REPO"

cloud_run_cpu           = "1"
cloud_run_memory        = "512Mi"
cloud_run_min_instances = 0
cloud_run_max_instances = 2

env_vars = {
$(echo -e "$ENV_VARS_TF")
}

# Secret keys (values are passed via -var in CI/CD from GitHub Secrets)
# Terraform creates secrets in GCP Secret Manager with prefix: ${SERVICE_NAME}-
secret_keys = [$(if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
  first=true
  while IFS= read -r key; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      echo -n ", "
    fi
    echo -n "\"$key\""
  done < "$SECRET_KEYS_FILE"
fi)]

custom_domain = "${CUSTOM_DOMAIN:-}"
cloudsql_instance = "${CLOUD_SQL_INSTANCE:-}"
storage_buckets = [$(if [[ -n "$STORAGE_BUCKET" ]]; then echo "\"$STORAGE_BUCKET\""; fi)]

container_port    = $CONTAINER_PORT
health_check_path = "$HEALTH_CHECK_PATH"

vpc_network    = "${VPC_NETWORK:-}"
vpc_subnetwork = "${VPC_SUBNETWORK:-}"
EOF
log_success "Created infra/gcp/terraform.tfvars"

# Create main.tf
cat > "$INFRA_DIR/main.tf" << EOF
terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  backend "gcs" {
    bucket = "$STATE_BUCKET"
    prefix = "terraform/state"
  }
}

provider "google" {
  project                         = var.project_id
  region                          = var.region
  default_labels                  = var.default_labels
  add_terraform_attribution_label = true
}

locals {
  registry_name = var.registry_name != "" ? var.registry_name : var.service_name
}

module "workload_identity" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/workload-identity?ref=main"

  project_id  = var.project_id
  github_repo = var.github_repo

  enable_project_iam_admin = true
  enable_storage_admin     = true
}

module "artifact_registry" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/artifact-registry?ref=main"

  region        = var.region
  repository_id = local.registry_name
  description   = "Docker repository for \${var.service_name}"

  # Cleanup policies - keep storage costs low for large images
  delete_untagged         = true
  keep_recent_count       = var.registry_keep_recent_count
  delete_older_than_hours = var.registry_delete_older_than_hours
}

# Secret Manager - Terraform managed secrets with service prefix
resource "google_secret_manager_secret" "secrets" {
  for_each  = toset(var.secret_keys)
  secret_id = "\${var.service_name}-\${lower(replace(each.value, "_", "-"))}"

  replication {
    auto {}
  }

  labels = {
    service = var.service_name
    managed = "terraform"
  }
}

resource "google_secret_manager_secret_version" "secrets" {
  for_each    = toset(var.secret_keys)
  secret      = google_secret_manager_secret.secrets[each.value].id
  secret_data = var.secret_values[each.value]

  lifecycle {
    ignore_changes = [secret_data]
  }
}

module "cloud_run" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/cloud-run?ref=main"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = "\${var.region}-docker.pkg.dev/\${var.project_id}/\${local.registry_name}/\${var.service_name}:\${var.image_tag}"

  cpu           = var.cloud_run_cpu
  memory        = var.cloud_run_memory
  min_instances = var.cloud_run_min_instances
  max_instances = var.cloud_run_max_instances

  env_vars = var.env_vars

  secret_env_vars = {
    for name in var.secret_keys : name => {
      secret_id = google_secret_manager_secret.secrets[name].secret_id
      version   = "latest"
    }
  }

  custom_domain       = var.custom_domain
  allow_public_access = var.allow_public_access
  deletion_protection = var.deletion_protection

  container_port    = var.container_port
  health_check_path = var.health_check_path

  cloudsql_instances = var.cloudsql_instance != "" ? [var.cloudsql_instance] : []
  storage_buckets    = var.storage_buckets

  vpc_network    = var.vpc_network
  vpc_subnetwork = var.vpc_subnetwork

  depends_on = [module.artifact_registry, google_secret_manager_secret_version.secrets]
}
EOF
log_success "Created infra/gcp/main.tf"

# Create variables.tf
cat > "$INFRA_DIR/variables.tf" << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Service name (used for Cloud Run service)"
  type        = string
}

variable "registry_name" {
  description = "Artifact Registry repository name (defaults to service_name if not specified)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

variable "default_labels" {
  description = "Default labels to apply to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
  }
}

variable "deletion_protection" {
  description = "Enable deletion protection for Cloud Run service (enable in production)"
  type        = bool
  default     = false
}

variable "allow_public_access" {
  description = "Allow unauthenticated access to Cloud Run service"
  type        = bool
  default     = true
}

variable "cloud_run_cpu" {
  description = "CPU limit for Cloud Run containers"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory limit for Cloud Run containers"
  type        = string
  default     = "512Mi"
}

variable "cloud_run_min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "env_vars" {
  description = "Environment variables for Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "secret_keys" {
  description = "List of secret environment variable names. Used for creating Secret Manager secrets with service_name prefix."
  type        = list(string)
  default     = []
}

variable "secret_values" {
  description = "Map of secret values (ENV_NAME => value). Values come from GitHub Secrets via -var in CI/CD."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "custom_domain" {
  description = "Custom domain for Cloud Run service"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Docker image tag for Cloud Run deployment"
  type        = string
  default     = "latest"
}

variable "cloudsql_instance" {
  description = "Cloud SQL instance connection name (project:region:instance)"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  default     = "/api/health"
}

variable "storage_buckets" {
  description = "List of GCS bucket names to grant objectAdmin access to Cloud Run service account"
  type        = list(string)
  default     = []
}

variable "registry_keep_recent_count" {
  description = "Number of recent Docker images to keep in Artifact Registry"
  type        = number
  default     = 1
}

variable "registry_delete_older_than_hours" {
  description = "Delete Docker images older than N hours from Artifact Registry"
  type        = number
  default     = 1
}

variable "vpc_network" {
  description = "VPC network name for Direct VPC Egress (e.g., 'default' or 'projects/PROJECT/global/networks/NETWORK')"
  type        = string
  default     = ""
}

variable "vpc_subnetwork" {
  description = "VPC subnetwork name for Direct VPC Egress (e.g., 'default' or 'projects/PROJECT/regions/REGION/subnetworks/SUBNET')"
  type        = string
  default     = ""
}
EOF
log_success "Created infra/gcp/variables.tf"

# Create outputs.tf
cat > "$INFRA_DIR/outputs.tf" << 'EOF'
output "workload_identity_provider" {
  description = "Workload Identity Provider ID for GitHub Actions"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "GitHub Actions Service Account email"
  value       = module.workload_identity.service_account_email
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.url
}

output "cloud_run_service_account" {
  description = "Cloud Run Service Account email"
  value       = module.cloud_run.service_account_email
}
EOF
log_success "Created infra/gcp/outputs.tf"

# Format all terraform files
log_info "Formatting terraform files..."
terraform -chdir="$INFRA_DIR" fmt > /dev/null
log_success "Terraform files formatted"

# Create combined CI workflow (build + terraform)
print_header "Step 7: Creating GitHub Workflows"

# Build dummy TF_VAR_secret_values for CI (placeholder values for plan)
CI_SECRET_ENV_BLOCK=""
if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
  CI_SECRET_ENV_BLOCK="          TF_VAR_secret_values: |"
  CI_SECRET_ENV_BLOCK+="\n            {"
  first_key=true
  while IFS= read -r key; do
    if [[ "$first_key" == "true" ]]; then
      first_key=false
    else
      CI_SECRET_ENV_BLOCK+=","
    fi
    CI_SECRET_ENV_BLOCK+="\n              \"$key\": \"placeholder-for-ci\""
  done < "$SECRET_KEYS_FILE"
  CI_SECRET_ENV_BLOCK+="\n            }"
fi

# Generate build steps based on project type
case "$PROJECT_TYPE" in
  nodejs)
    CI_BUILD_STEPS="      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Cache Next.js build
        uses: actions/cache@v5
        with:
          path: \${{ github.workspace }}/.next/cache
          key: \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-\${{ hashFiles('**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx', '**/*.css', '**/*.scss') }}
          restore-keys: |
            \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-

      - name: Install dependencies
        run: yarn install --immutable

      - name: Build application
        run: yarn build
        env:
          NODE_ENV: production"
    CI_BUILD_NAME="Build & Validate"
    ;;
  java-maven)
    CI_BUILD_STEPS="      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Build with Maven
        run: mvn package -DskipTests"
    CI_BUILD_NAME="Build & Validate"
    ;;
  java-gradle)
    CI_BUILD_STEPS="      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: gradle

      - name: Build with Gradle
        run: ./gradlew build -x test"
    CI_BUILD_NAME="Build & Validate"
    ;;
  laravel-api)
    CI_BUILD_STEPS="      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install dependencies
        run: composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Prepare Laravel
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Run Pint (code style)
        run: vendor/bin/pint --test

      - name: Run tests
        run: php artisan test --compact
        env:
          APP_ENV: testing"
    CI_BUILD_NAME="Build & Test"
    ;;
  laravel-ssr)
    CI_BUILD_STEPS="      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install PHP dependencies
        run: composer install --no-interaction --prefer-dist --optimize-autoloader

      - name: Prepare Laravel
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Install Node.js dependencies
        run: yarn install --immutable

      - name: Build frontend assets
        run: yarn build

      - name: Run Pint (code style)
        run: vendor/bin/pint --test

      - name: Run tests
        run: php artisan test --compact
        env:
          APP_ENV: testing"
    CI_BUILD_NAME="Build & Test"
    ;;
  docker-only)
    CI_BUILD_STEPS="      - name: Build Docker image (validation)
        run: docker build -t test-build ."
    CI_BUILD_NAME="Build & Validate"
    ;;
esac

# Create CI workflow
CI_CONTENT="name: CI

on:
  pull_request:
    branches:
      - develop
      - main
    paths-ignore:
      - '*.md'

permissions:
  contents: read
  pull-requests: read

jobs:
  build:
    name: $CI_BUILD_NAME
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

$CI_BUILD_STEPS
"

echo -e "$CI_CONTENT" > "$WORKFLOWS_DIR/ci.yml"
log_success "Created .github/workflows/ci.yml"

# Generate CD workflow based on project type
# Common header for all project types
CD_HEADER="name: CD

on:
  push:
    branches:
      - main
    paths-ignore:
      - '*.md'

permissions:
  contents: read
  id-token: write

env:
  REGION: $REGION
  SERVICE_NAME: $SERVICE_NAME
  REGISTRY_NAME: $REGISTRY_NAME
  PROJECT_ID: $PROJECT_ID

jobs:
  deploy:
    name: Build & Deploy
    runs-on: ubuntu-latest
    environment: Production

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: \${{ secrets.GCP_SERVICE_ACCOUNT_EMAIL }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v3

      - name: Configure Docker
        run: gcloud auth configure-docker \${{ env.REGION }}-docker.pkg.dev --quiet
"

# Common footer for all project types
CD_FOOTER="
      - name: Build Docker image
        run: |
          docker build -t \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.REGISTRY_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }} .
          docker tag \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.REGISTRY_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }} \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.REGISTRY_NAME }}/\${{ env.SERVICE_NAME }}:latest

      - name: Push Docker image
        run: |
          docker push \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.REGISTRY_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }}
          docker push \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.REGISTRY_NAME }}/\${{ env.SERVICE_NAME }}:latest

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: \"~> 1.10\"

      - name: Terraform Init
        working-directory: infra/gcp
        run: terraform init

      - name: Terraform Apply
        working-directory: infra/gcp
        env:
          TF_VAR_image_tag: \${{ github.sha }}
__SECRET_ENV_PLACEHOLDER__
        run: terraform apply -var-file=terraform.tfvars -auto-approve -input=false"

# Build env vars string for CD workflow (build-time variables)
CD_BUILD_ENV_VARS="          NODE_ENV: production"
if [[ -f "$BUILD_KEYS_FILE" ]] && [[ -s "$BUILD_KEYS_FILE" ]]; then
  while IFS= read -r key; do
    CD_BUILD_ENV_VARS+="\n          $key: \${{ vars.$key }}"
  done < "$BUILD_KEYS_FILE"
fi

case "$PROJECT_TYPE" in
  nodejs)
    CD_BUILD_STEPS="
      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Cache Next.js build
        uses: actions/cache@v5
        with:
          path: \${{ github.workspace }}/.next/cache
          key: \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-\${{ hashFiles('**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx', '**/*.css', '**/*.scss') }}
          restore-keys: |
            \${{ runner.os }}-nextjs-\${{ hashFiles('yarn.lock') }}-

      - name: Install dependencies
        run: yarn install --immutable

      - name: Build application
        run: yarn build
        env:
$(echo -e "$CD_BUILD_ENV_VARS")
"
    ;;
  laravel-api)
    CD_BUILD_STEPS="
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install dependencies
        run: composer install --no-dev --optimize-autoloader --no-interaction
"
    ;;
  laravel-ssr)
    CD_BUILD_STEPS="
      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: mbstring, pdo, pdo_pgsql, bcmath, intl, zip, gd, redis
          coverage: none

      - name: Get Composer cache directory
        id: composer-cache
        run: echo \"dir=\$(composer config cache-files-dir)\" >> \$GITHUB_OUTPUT

      - name: Cache Composer dependencies
        uses: actions/cache@v5
        with:
          path: \${{ steps.composer-cache.outputs.dir }}
          key: \${{ runner.os }}-composer-\${{ hashFiles('composer.lock') }}
          restore-keys: \${{ runner.os }}-composer-

      - name: Install PHP dependencies
        run: composer install --no-dev --optimize-autoloader --no-interaction

      - name: Enable Corepack
        run: corepack enable

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: lts/*
          cache: yarn

      - name: Install Node.js dependencies
        run: yarn install --immutable

      - name: Build frontend assets
        run: yarn build
"
    ;;
  java-maven)
    CD_BUILD_STEPS="
      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Build with Maven
        run: mvn package -DskipTests
"
    ;;
  java-gradle)
    CD_BUILD_STEPS="
      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '21'
          cache: gradle

      - name: Build with Gradle
        run: ./gradlew build -x test
"
    ;;
  docker-only)
    CD_BUILD_STEPS=""
    ;;
esac

# Build TF_VAR_secret_values env var for Terraform (JSON format)
if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
  SECRET_ENV_BLOCK="          TF_VAR_secret_values: |"
  SECRET_ENV_BLOCK+="\n            {"
  first_key=true
  while IFS= read -r key; do
    if [[ "$first_key" == "true" ]]; then
      first_key=false
    else
      SECRET_ENV_BLOCK+=","
    fi
    SECRET_ENV_BLOCK+="\n              \"$key\": \"\${{ secrets.$key }}\""
  done < "$SECRET_KEYS_FILE"
  SECRET_ENV_BLOCK+="\n            }"
else
  SECRET_ENV_BLOCK=""
fi

# Replace placeholder with actual secret env vars
CD_FOOTER="${CD_FOOTER/__SECRET_ENV_PLACEHOLDER__/$SECRET_ENV_BLOCK}"

echo -e "${CD_HEADER}${CD_BUILD_STEPS}${CD_FOOTER}" > "$WORKFLOWS_DIR/cd.yml"
log_success "Created .github/workflows/cd.yml"

# Create .gitignore for terraform
cat > "$INFRA_DIR/.gitignore" << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
.terraform.lock.hcl
tfplan
EOF
log_success "Created infra/gcp/.gitignore"

# Create tfvars example
cat > "$INFRA_DIR/terraform.tfvars.example" << EOF
project_id    = "$PROJECT_ID"
region        = "$REGION"
service_name  = "$SERVICE_NAME"
registry_name = "$REGISTRY_NAME"
github_repo   = "$GITHUB_REPO"

cloud_run_cpu           = "1"
cloud_run_memory        = "512Mi"
cloud_run_min_instances = 0
cloud_run_max_instances = 2

env_vars = {
  NODE_ENV = "production"
}

secret_env_vars = {}
EOF
log_success "Created infra/gcp/terraform.tfvars.example"

# Run terraform if not skipped
if [[ "$SKIP_TERRAFORM" != "true" ]]; then
  print_header "Step 8: Running Terraform"

  cd "$INFRA_DIR"

  # Clean up old terraform cache to avoid backend conflicts
  if [[ -d ".terraform" ]]; then
    log_info "Cleaning up old terraform cache..."
    rm -rf .terraform
  fi

  log_info "Terraform init..."
  terraform init -upgrade

  # Build secret_values for local terraform commands
  SECRET_VALUES_VAR=""
  if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
    SECRET_VAR_ITEMS=""
    while IFS= read -r key && IFS= read -r value <&3; do
      if [[ -n "$SECRET_VAR_ITEMS" ]]; then
        SECRET_VAR_ITEMS+=","
      fi
      # Escape special characters in value
      escaped_value=$(echo "$value" | sed 's/"/\\"/g')
      SECRET_VAR_ITEMS+="\"$key\":\"$escaped_value\""
    done < "$SECRET_KEYS_FILE" 3< "$SECRET_VALUES_FILE"
    SECRET_VALUES_VAR="-var=secret_values={$SECRET_VAR_ITEMS}"
  fi

  # Import existing resources created by bootstrap
  log_info "Importing existing resources into Terraform state..."

  # Import Artifact Registry if it exists and not already in state
  if gcloud artifacts repositories describe "$REGISTRY_NAME" --location="$REGION" &>/dev/null; then
    if ! terraform state show "module.artifact_registry.google_artifact_registry_repository.main" &>/dev/null; then
      log_info "Importing existing Artifact Registry: $REGISTRY_NAME"
      terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
        "module.artifact_registry.google_artifact_registry_repository.main" \
        "projects/$PROJECT_ID/locations/$REGION/repositories/$REGISTRY_NAME"
    else
      log_success "Artifact Registry already in Terraform state"
    fi
  fi

  # Delete existing secrets that are not in Terraform state (Terraform will recreate them)
  if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
    log_info "Checking for orphan secrets to clean up..."
    while IFS= read -r key; do
      secret_name="${SERVICE_NAME}-$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
      if gcloud secrets describe "$secret_name" &>/dev/null; then
        if ! terraform state show "google_secret_manager_secret.secrets[\"$key\"]" &>/dev/null 2>&1; then
          log_warn "Secret $secret_name exists in GCP but not in Terraform state"
          log_info "Deleting orphan secret: $secret_name (Terraform will recreate it)"
          gcloud secrets delete "$secret_name" --quiet || log_warn "Failed to delete $secret_name"
        else
          log_success "Secret $secret_name already managed by Terraform"
        fi
      fi
    done < "$SECRET_KEYS_FILE"
  fi

  # Handle existing Domain Mapping (prevents 20min hang on create)
  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    if gcloud run domain-mappings describe --domain="$CUSTOM_DOMAIN" --region="$REGION" &>/dev/null; then
      if ! terraform state show 'module.cloud_run.google_cloud_run_domain_mapping.main[0]' &>/dev/null; then
        log_warn "Domain Mapping exists but not in Terraform state: $CUSTOM_DOMAIN"
        log_info "Deleting existing Domain Mapping to let Terraform recreate it..."
        if gcloud run domain-mappings delete --domain="$CUSTOM_DOMAIN" --region="$REGION" --quiet; then
          log_success "Domain Mapping deleted, Terraform will recreate it"
        else
          log_warn "Could not delete domain mapping, attempting import..."
          terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
            'module.cloud_run.google_cloud_run_domain_mapping.main[0]' \
            "locations/$REGION/namespaces/$PROJECT_ID/domainmappings/$CUSTOM_DOMAIN" || \
            log_warn "Import failed, Terraform may hang on apply"
        fi
      else
        log_success "Domain Mapping already in Terraform state"
      fi
    fi
  fi

  log_info "Terraform plan..."
  terraform plan -var-file=terraform.tfvars $SECRET_VALUES_VAR -out=tfplan

  echo ""
  APPLY_PLAN="false"
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    APPLY_PLAN="true"
  else
    read -p "Apply this plan? (y/n) " -n 1 -r < /dev/tty
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      APPLY_PLAN="true"
    fi
  fi

  if [[ "$APPLY_PLAN" == "true" ]]; then
    log_info "Terraform apply..."

    # Function to import existing resources
    import_existing_resources() {
      local output="$1"
      local imported=false

      # Import Cloud Run Service Account if already exists and not in state
      if echo "$output" | grep -q "${SERVICE_NAME}-run already exists"; then
        if ! terraform state show 'module.cloud_run.google_service_account.cloud_run' &>/dev/null; then
          log_info "Importing existing Cloud Run Service Account..."
          if terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
            'module.cloud_run.google_service_account.cloud_run' \
            "projects/$PROJECT_ID/serviceAccounts/${SERVICE_NAME}-run@${PROJECT_ID}.iam.gserviceaccount.com" 2>/dev/null; then
            log_success "Cloud Run Service Account imported"
            imported=true
          fi
        else
          log_warn "Cloud Run Service Account already in state"
        fi
      fi

      # Import GitHub Actions Service Account if already exists and not in state
      if echo "$output" | grep -q "github-actions already exists"; then
        if ! terraform state show 'module.workload_identity.google_service_account.github_actions' &>/dev/null; then
          log_info "Importing existing GitHub Actions Service Account..."
          if terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
            'module.workload_identity.google_service_account.github_actions' \
            "projects/$PROJECT_ID/serviceAccounts/github-actions@${PROJECT_ID}.iam.gserviceaccount.com" 2>/dev/null; then
            log_success "GitHub Actions Service Account imported"
            imported=true
          fi
        else
          log_warn "GitHub Actions Service Account already in state"
        fi
      fi

      # Import Workload Identity Pool if already exists and not in state
      if echo "$output" | grep -q "WorkloadIdentityPool.*already exists\|workload_identity_pool.*already exists"; then
        if ! terraform state show 'module.workload_identity.google_iam_workload_identity_pool.github' &>/dev/null; then
          log_info "Importing existing Workload Identity Pool..."
          if terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
            'module.workload_identity.google_iam_workload_identity_pool.github' \
            "projects/$PROJECT_ID/locations/global/workloadIdentityPools/github-pool" 2>/dev/null; then
            log_success "Workload Identity Pool imported"
            imported=true
          fi
        else
          log_warn "Workload Identity Pool already in state"
        fi
      fi

      # Import Workload Identity Provider if already exists and not in state
      if echo "$output" | grep -q "WorkloadIdentityPoolProvider.*already exists\|workload_identity_pool_provider.*already exists"; then
        if ! terraform state show 'module.workload_identity.google_iam_workload_identity_pool_provider.github' &>/dev/null; then
          log_info "Importing existing Workload Identity Provider..."
          if terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
            'module.workload_identity.google_iam_workload_identity_pool_provider.github' \
            "projects/$PROJECT_ID/locations/global/workloadIdentityPools/github-pool/providers/github-provider" 2>/dev/null; then
            log_success "Workload Identity Provider imported"
            imported=true
          fi
        else
          log_warn "Workload Identity Provider already in state"
        fi
      fi

      # Import Domain Mapping if already exists and not in state
      if echo "$output" | grep -qE "DomainMapping.*already exists|Resource '.*\..*' already exists"; then
        if ! terraform state show 'module.cloud_run.google_cloud_run_domain_mapping.main[0]' &>/dev/null; then
          # Extract domain from error message if CUSTOM_DOMAIN not set
          local domain_to_import="$CUSTOM_DOMAIN"
          if [[ -z "$domain_to_import" ]]; then
            domain_to_import=$(echo "$output" | grep -oE "Resource '[^']+' already exists" | grep -oE "'[^']+'" | tr -d "'" | head -1)
          fi
          if [[ -n "$domain_to_import" ]]; then
            log_info "Importing existing Domain Mapping: $domain_to_import"
            if terraform import -var-file=terraform.tfvars $SECRET_VALUES_VAR \
              'module.cloud_run.google_cloud_run_domain_mapping.main[0]' \
              "locations/$REGION/namespaces/$PROJECT_ID/domainmappings/$domain_to_import"; then
              log_success "Domain Mapping imported"
              imported=true
            else
              log_warn "Failed to import Domain Mapping"
            fi
          fi
        else
          log_warn "Domain Mapping already in state"
        fi
      fi

      echo "$imported"
    }

    # Retry logic for IAM propagation delays (~10 minutes max)
    max_retries=20
    retry_count=0
    apply_success=false

    while [[ $retry_count -lt $max_retries ]]; do
      set +e
      apply_output=$(terraform apply tfplan 2>&1)
      apply_exit_code=$?
      set -e

      echo "$apply_output"

      if [[ $apply_exit_code -eq 0 ]]; then
        apply_success=true
        break
      else
        # Check for "already exists" errors (409) - need to import
        if echo "$apply_output" | grep -qE "Error 409.*already exists|alreadyExists"; then
          log_warn "Resources already exist. Attempting auto-import..."
          imported=$(import_existing_resources "$apply_output")

          if [[ "$imported" == "true" ]]; then
            log_success "Resources imported. Regenerating plan..."
            terraform plan -var-file=terraform.tfvars $SECRET_VALUES_VAR -out=tfplan
            ((retry_count++))
            continue
          fi
        fi

        # Check for IAM/permission propagation errors
        if echo "$apply_output" | grep -qiE "(permission denied|secretAccessor|403|access denied)" && \
           ! echo "$apply_output" | grep -qE "Error 409.*already exists"; then
          ((retry_count++))
          if [[ $retry_count -lt $max_retries ]]; then
            log_warn "IAM permission error detected (attempt $retry_count/$max_retries). Waiting 30s for propagation..."
            sleep 30
            log_info "Retrying terraform apply..."
            terraform plan -var-file=terraform.tfvars $SECRET_VALUES_VAR -out=tfplan
          fi
        else
          # Non-retryable error
          if [[ "$imported" != "true" ]]; then
            log_error "Terraform apply failed with non-retryable error"
            exit 1
          fi
        fi
      fi
    done

    if [[ "$apply_success" == "true" ]]; then
      log_success "Terraform applied"
    else
      log_error "Terraform apply failed after $max_retries attempts"
      log_info "Try running manually: cd $INFRA_DIR && terraform apply -var-file=terraform.tfvars"
      exit 1
    fi

    # Get outputs for GitHub secrets
    WIP=$(terraform output -raw workload_identity_provider 2>/dev/null || echo "")
    SAE=$(terraform output -raw service_account_email 2>/dev/null || echo "")
  else
    log_warn "Skipped terraform apply"
  fi

  cd - > /dev/null
else
  log_warn "Skipped terraform (use --skip-terraform=false to run)"
fi

# Configure GitHub secrets
print_header "Step 9: GitHub Secrets Configuration"

if command -v gh &> /dev/null; then
  log_info "GitHub CLI detected. Checking authentication..."

  if gh auth token &>/dev/null; then
    log_success "GitHub CLI authenticated"

    echo ""
    CONFIGURE_SECRETS="false"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
      CONFIGURE_SECRETS="true"
    else
      read -p "Configure GitHub secrets automatically? (y/n) " -n 1 -r < /dev/tty
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        CONFIGURE_SECRETS="true"
      fi
    fi

    if [[ "$CONFIGURE_SECRETS" == "true" ]]; then
      log_info "Configuring GitHub secrets for $GITHUB_REPO (environment: Production)..."

      # Create Production environment if it doesn't exist
      gh api "repos/$GITHUB_REPO/environments/Production" --method PUT --silent 2>/dev/null || true

      # Set secrets in Production environment
      if [[ -n "$WIP" ]]; then
        echo "$WIP" | gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --repo="$GITHUB_REPO" --env=Production
        log_success "Set GCP_WORKLOAD_IDENTITY_PROVIDER"
      fi

      if [[ -n "$SAE" ]]; then
        echo "$SAE" | gh secret set GCP_SERVICE_ACCOUNT_EMAIL --repo="$GITHUB_REPO" --env=Production
        log_success "Set GCP_SERVICE_ACCOUNT_EMAIL"
      fi

      # Set build-time variables (NEXT_PUBLIC_* etc)
      if [[ -f "$BUILD_KEYS_FILE" ]] && [[ -s "$BUILD_KEYS_FILE" ]]; then
        log_info "Creating GitHub Variables for build-time env vars..."
        while IFS= read -r key && IFS= read -r value <&3; do
          echo "$value" | gh variable set "$key" --repo="$GITHUB_REPO" --env=Production
          log_success "Set variable: $key"
        done < "$BUILD_KEYS_FILE" 3< "$BUILD_VALUES_FILE"
      fi

      # Set secrets for Terraform (APP_KEY, DB_PASSWORD, etc)
      if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
        log_info "Creating GitHub Secrets for Terraform-managed secrets..."
        while IFS= read -r key && IFS= read -r value <&3; do
          echo "$value" | gh secret set "$key" --repo="$GITHUB_REPO" --env=Production
          log_success "Set secret: $key"
        done < "$SECRET_KEYS_FILE" 3< "$SECRET_VALUES_FILE"
      fi

      log_success "GitHub secrets and variables configured in 'Production' environment!"
    else
      log_warn "Skipped GitHub secrets configuration"
    fi
  else
    log_warn "GitHub CLI not authenticated. Run: gh auth login"
  fi
else
  log_warn "GitHub CLI not found. Install it to auto-configure secrets: https://cli.github.com"
fi

# Manual instructions if secrets not configured
if [[ -z "$WIP" ]] || ! command -v gh &> /dev/null; then
  echo ""
  echo "Add these secrets to your GitHub repository manually:"
  echo ""
  echo "┌────────────────────────────────────────────────────────────────────┐"
  echo "│ Repository Settings → Secrets and variables → Actions             │"
  echo "│ Environment: Production                                            │"
  echo "├────────────────────────────────────────────────────────────────────┤"
  echo "│                                                                    │"
  echo "│ GCP_WORKLOAD_IDENTITY_PROVIDER:                                    │"
  if [[ -n "$WIP" ]]; then
    echo "│ $WIP"
  else
    echo "│ (run terraform apply first)"
  fi
  echo "│                                                                    │"
  echo "│ GCP_SERVICE_ACCOUNT_EMAIL:                                         │"
  if [[ -n "$SAE" ]]; then
    echo "│ $SAE"
  else
    echo "│ (run terraform apply first)"
  fi
  if [[ -f "$SECRET_KEYS_FILE" ]] && [[ -s "$SECRET_KEYS_FILE" ]]; then
    echo "│                                                                    │"
    echo "│ Terraform-managed secrets (from .env):                             │"
    while IFS= read -r key; do
      echo "│   • $key"
    done < "$SECRET_KEYS_FILE"
  fi
  echo "│                                                                    │"
  echo "└────────────────────────────────────────────────────────────────────┘"
fi

# Custom domain configuration
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  print_header "Step 10: Custom Domain Configuration"

  # Extract root domain for verification
  ROOT_DOMAIN=$(echo "$CUSTOM_DOMAIN" | awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')

  echo "Custom domain: $CUSTOM_DOMAIN"
  echo ""
  log_info "Domain verification required before Cloud Run can use custom domains."
  echo ""
  echo "┌────────────────────────────────────────────────────────────────────┐"
  echo "│  Step 1: Verify Domain Ownership                                   │"
  echo "├────────────────────────────────────────────────────────────────────┤"
  echo "│                                                                    │"
  echo "│  Open Google Search Console to verify your domain:                 │"
  echo "│                                                                    │"
  echo "│  https://search.google.com/search-console/welcome                  │"
  echo "│                                                                    │"
  echo "│  1. Click 'Add property'                                           │"
  echo "│  2. Select 'URL prefix' and enter: https://$ROOT_DOMAIN            │"
  echo "│  3. Choose verification method (HTML file or DNS TXT recommended)  │"
  echo "│  4. Complete verification                                          │"
  echo "│                                                                    │"
  echo "└────────────────────────────────────────────────────────────────────┘"
  echo ""
  echo "┌────────────────────────────────────────────────────────────────────┐"
  echo "│  Step 2: Configure DNS Records                                     │"
  echo "├────────────────────────────────────────────────────────────────────┤"
  echo "│                                                                    │"
  echo "│  Add this CNAME record in your DNS provider (Cloudflare, etc.):   │"
  echo "│                                                                    │"
  echo "│  Type:   CNAME                                                     │"
  echo "│  Name:   ${CUSTOM_DOMAIN%%.$ROOT_DOMAIN}                                                       │"
  echo "│  Target: ghs.googlehosted.com                                      │"
  echo "│  TTL:    Auto or 3600                                              │"
  echo "│                                                                    │"
  echo "│  ⚠️  If using Cloudflare, set Proxy status to 'DNS only' (gray)    │"
  echo "│                                                                    │"
  echo "└────────────────────────────────────────────────────────────────────┘"
  echo ""
  log_warn "Domain mapping will be created by Terraform after verification."
  log_info "If terraform apply fails with domain error, verify the domain first."
  echo ""
fi

print_header "Bootstrap Complete!"

echo "Generated files:"
echo "  $INFRA_DIR/"
echo "    ├── main.tf"
echo "    ├── variables.tf"
echo "    ├── outputs.tf"
echo "    ├── terraform.tfvars"
echo "    ├── terraform.tfvars.example"
echo "    └── .gitignore"
echo "  $WORKFLOWS_DIR/"
echo "    ├── ci.yml              (build & test - runs on PR)"
echo "    └── cd.yml              (build + deploy - runs on push to main)"
echo ""
echo "Next steps:"
echo "  1. Review generated files"
echo "  2. Commit and push to GitHub"
echo "  3. The CD pipeline will build and deploy on push to main"
echo ""
log_success "Done!"