#!/bin/bash
set -e

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
    --custom-domain=*)
      CUSTOM_DOMAIN="${1#*=}"
      shift
      ;;
    --provider=*)
      PROVIDER="${1#*=}"
      shift
      ;;
    --help)
      echo "Usage: ./bootstrap.sh [options]"
      echo ""
      echo "Options:"
      echo "  --project-id=ID            GCP Project ID (required)"
      echo "  --region=REGION            GCP Region (default: us-central1)"
      echo "  --service-name=NAME        Service name (required)"
      echo "  --github-repo=REPO         GitHub repo owner/repo (required)"
      echo "  --billing-account=ID       Billing account ID (required if --create-project)"
      echo "  --terraform-modules-repo=REPO  Terraform modules repo (default: thoggs/terraform-modules)"
      echo "  --output-dir=PATH          Output directory for generated files (default: current dir)"
      echo "  --create-project           Create new GCP project"
      echo "  --skip-terraform           Skip terraform init/plan/apply"
      echo "  --custom-domain=DOMAIN     Custom domain for Cloud Run (e.g., app.example.com)"
      echo "  --provider=PROVIDER        Cloud provider: gcp (default), aws*, azure* (*coming soon)"
      echo "  --help                     Show this help"
      echo ""
      echo "Example:"
      echo "  ./bootstrap.sh \\"
      echo "    --project-id=my-project \\"
      echo "    --service-name=my-app \\"
      echo "    --github-repo=myuser/my-app \\"
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

# Validate provider
if [[ "$PROVIDER" != "gcp" ]]; then
  if [[ "$PROVIDER" == "aws" ]] || [[ "$PROVIDER" == "azure" ]]; then
    log_error "Provider '$PROVIDER' is not implemented yet. Only 'gcp' is currently supported."
    log_info "AWS and Azure support coming soon!"
    exit 1
  else
    log_error "Unknown provider: $PROVIDER. Supported: gcp (aws and azure coming soon)"
    exit 1
  fi
fi

# Validate required arguments
if [[ -z "$PROJECT_ID" ]]; then
  log_error "Missing required argument: --project-id"
  exit 1
fi

if [[ -z "$SERVICE_NAME" ]]; then
  log_error "Missing required argument: --service-name"
  exit 1
fi

if [[ -z "$GITHUB_REPO" ]]; then
  log_error "Missing required argument: --github-repo"
  exit 1
fi

if [[ "$CREATE_PROJECT" == "true" && -z "$BILLING_ACCOUNT" ]]; then
  log_error "Missing required argument: --billing-account (required when using --create-project)"
  exit 1
fi

# State bucket name
STATE_BUCKET="${PROJECT_ID}-tfstate"

# Directory paths
INFRA_DIR="$OUTPUT_DIR/infra/gcp"
WORKFLOWS_DIR="$OUTPUT_DIR/.github/workflows"

print_header "GCP Cloud Run Bootstrap"

echo "Configuration:"
echo "  Provider:         $PROVIDER"
echo "  Project ID:       $PROJECT_ID"
echo "  Region:           $REGION"
echo "  Service Name:     $SERVICE_NAME"
echo "  GitHub Repo:      $GITHUB_REPO"
echo "  Modules Repo:     $TERRAFORM_MODULES_REPO"
echo "  State Bucket:     $STATE_BUCKET"
echo "  Output Dir:       $OUTPUT_DIR"
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  echo "  Custom Domain:    $CUSTOM_DOMAIN"
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

ARTIFACT_REGISTRY="$REGION-docker.pkg.dev/$PROJECT_ID/$SERVICE_NAME"
IMAGE_NAME="$ARTIFACT_REGISTRY/$SERVICE_NAME:latest"

# Create Artifact Registry if it doesn't exist
if ! gcloud artifacts repositories describe "$SERVICE_NAME" --location="$REGION" &>/dev/null; then
  log_info "Creating Artifact Registry: $SERVICE_NAME"
  gcloud artifacts repositories create "$SERVICE_NAME" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Docker repository for $SERVICE_NAME"
  log_success "Artifact Registry created"
else
  log_warn "Artifact Registry $SERVICE_NAME already exists"
fi

# Configure Docker authentication
log_info "Configuring Docker authentication..."
gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
log_success "Docker configured"

# Check if Dockerfile exists in output directory
if [[ -f "$OUTPUT_DIR/Dockerfile" ]]; then
  # Check if Node.js build is needed (package.json exists)
  if [[ -f "$OUTPUT_DIR/package.json" ]]; then
    log_info "Running application build..."
    cd "$OUTPUT_DIR"

    if command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
      yarn install --immutable 2>/dev/null || yarn install
      yarn build
    elif command -v npm &>/dev/null; then
      npm ci 2>/dev/null || npm install
      npm run build
    fi

    cd - > /dev/null
    log_success "Application built"
  fi

  log_info "Building Docker image (linux/amd64)..."

  # Use buildx for multiplatform build
  if docker buildx version &>/dev/null; then
    # Create builder if needed
    docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch 2>/dev/null || true
    docker buildx build --platform linux/amd64 -t "$IMAGE_NAME" "$OUTPUT_DIR" --push
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

# Create directory structure
print_header "Step 6: Creating Project Structure"

mkdir -p "$INFRA_DIR"
mkdir -p "$WORKFLOWS_DIR"
log_success "Created directories: infra/gcp/, .github/workflows/"

# Create terraform.tfvars
cat > "$INFRA_DIR/terraform.tfvars" << EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
service_name = "$SERVICE_NAME"
github_repo  = "$GITHUB_REPO"

cloud_run_cpu           = "1"
cloud_run_memory        = "512Mi"
cloud_run_min_instances = 0
cloud_run_max_instances = 2

env_vars = {
  NODE_ENV = "production"
}

secret_env_vars = {}
EOF
log_success "Created infra/gcp/terraform.tfvars"

# Create main.tf
cat > "$INFRA_DIR/main.tf" << EOF
terraform {
  required_version = ">= 1.5"

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

module "workload_identity" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/workload-identity?ref=main"

  project_id  = var.project_id
  github_repo = var.github_repo
}

module "artifact_registry" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/artifact-registry?ref=main"

  region        = var.region
  repository_id = var.service_name
  description   = "Docker repository for \${var.service_name}"
}

module "secrets" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/secrets?ref=main"

  secrets = var.secret_env_vars
}

module "cloud_run" {
  source = "github.com/$TERRAFORM_MODULES_REPO//modules/gcp/cloud-run?ref=main"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = "\${var.region}-docker.pkg.dev/\${var.project_id}/\${var.service_name}/\${var.service_name}:\${var.image_tag}"

  cpu           = var.cloud_run_cpu
  memory        = var.cloud_run_memory
  min_instances = var.cloud_run_min_instances
  max_instances = var.cloud_run_max_instances

  env_vars = var.env_vars

  secret_env_vars = {
    for name, _ in var.secret_env_vars : name => {
      secret_id = module.secrets.secret_ids[name]
      version   = "latest"
    }
  }

  custom_domain       = var.custom_domain
  allow_public_access = var.allow_public_access
  deletion_protection = var.deletion_protection

  depends_on = [module.artifact_registry, module.secrets]
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
  description = "Service name (used for Cloud Run, Artifact Registry, etc.)"
  type        = string
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
  description = "Enable deletion protection for Cloud Run service"
  type        = bool
  default     = true
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

variable "secret_env_vars" {
  description = "Secret environment variables mapping (ENV_NAME => secret_value)"
  type        = map(string)
  default     = {}
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

# Create CI workflow
print_header "Step 7: Creating GitHub Workflows"

cat > "$WORKFLOWS_DIR/ci.yml" << EOF
name: CI

on:
  pull_request:
    branches:
      - develop
      - main
    paths-ignore:
      - '*.md'

permissions:
  contents: read
  id-token: write

jobs:
  terraform:
    name: Terraform Plan
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: \${{ secrets.GCP_SERVICE_ACCOUNT_EMAIL }}

      - name: Create terraform.tfvars
        working-directory: infra/gcp
        run: echo '\${{ secrets.TERRAFORM_TFVARS }}' > terraform.tfvars

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.5"

      - name: Terraform Init
        working-directory: infra/gcp
        run: terraform init

      - name: Terraform Format
        working-directory: infra/gcp
        run: terraform fmt -check

      - name: Terraform Plan
        working-directory: infra/gcp
        run: terraform plan -var-file=terraform.tfvars -input=false

  build:
    name: Build & Validate
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

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
          NODE_ENV: production
EOF
log_success "Created .github/workflows/ci.yml"

# Create CD workflow
cat > "$WORKFLOWS_DIR/cd.yml" << EOF
name: CD

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
  PROJECT_ID: $PROJECT_ID

jobs:
  deploy:
    name: Build & Deploy
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: \${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: \${{ secrets.GCP_SERVICE_ACCOUNT_EMAIL }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Configure Docker
        run: gcloud auth configure-docker \${{ env.REGION }}-docker.pkg.dev --quiet

      - name: Build Docker image
        run: |
          docker build -t \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.SERVICE_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }} .
          docker tag \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.SERVICE_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }} \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.SERVICE_NAME }}/\${{ env.SERVICE_NAME }}:latest

      - name: Push Docker image
        run: |
          docker push \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.SERVICE_NAME }}/\${{ env.SERVICE_NAME }}:\${{ github.sha }}
          docker push \${{ env.REGION }}-docker.pkg.dev/\${{ env.PROJECT_ID }}/\${{ env.SERVICE_NAME }}/\${{ env.SERVICE_NAME }}:latest

      - name: Create terraform.tfvars
        working-directory: infra/gcp
        run: |
          echo '\${{ secrets.TERRAFORM_TFVARS }}' > terraform.tfvars
          echo 'image_tag = "\${{ github.sha }}"' >> terraform.tfvars

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.5"

      - name: Terraform Init
        working-directory: infra/gcp
        run: terraform init

      - name: Terraform Apply
        working-directory: infra/gcp
        run: terraform apply -var-file=terraform.tfvars -auto-approve -input=false
EOF
log_success "Created .github/workflows/cd.yml"

# Create .gitignore for terraform
cat > "$INFRA_DIR/.gitignore" << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
.terraform.lock.hcl
tfplan
EOF
log_success "Created infra/gcp/.gitignore"

# Create tfvars example
cat > "$INFRA_DIR/terraform.tfvars.example" << EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
service_name = "$SERVICE_NAME"
github_repo  = "$GITHUB_REPO"

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

  log_info "Terraform init..."
  terraform init

  log_info "Terraform plan..."
  terraform plan -var-file=terraform.tfvars -out=tfplan

  echo ""
  read -p "Apply this plan? (y/n) " -n 1 -r < /dev/tty
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Terraform apply..."
    terraform apply tfplan
    log_success "Terraform applied"

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

  if gh auth status &>/dev/null; then
    log_success "GitHub CLI authenticated"

    echo ""
    read -p "Configure GitHub secrets automatically? (y/n) " -n 1 -r < /dev/tty
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "Configuring GitHub secrets for $GITHUB_REPO..."

      # Set secrets
      if [[ -n "$WIP" ]]; then
        echo "$WIP" | gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --repo="$GITHUB_REPO"
        log_success "Set GCP_WORKLOAD_IDENTITY_PROVIDER"
      fi

      if [[ -n "$SAE" ]]; then
        echo "$SAE" | gh secret set GCP_SERVICE_ACCOUNT_EMAIL --repo="$GITHUB_REPO"
        log_success "Set GCP_SERVICE_ACCOUNT_EMAIL"
      fi

      # Set TERRAFORM_TFVARS
      if [[ -f "$INFRA_DIR/terraform.tfvars" ]]; then
        gh secret set TERRAFORM_TFVARS --repo="$GITHUB_REPO" < "$INFRA_DIR/terraform.tfvars"
        log_success "Set TERRAFORM_TFVARS"
      fi

      log_success "GitHub secrets configured!"
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
  echo "│                                                                    │"
  echo "│ TERRAFORM_TFVARS:                                                  │"
  echo "│ (Copy contents of infra/gcp/terraform.tfvars)                      │"
  echo "│                                                                    │"
  echo "└────────────────────────────────────────────────────────────────────┘"
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
echo "    ├── ci.yml"
echo "    └── cd.yml"
echo ""
echo "Next steps:"
echo "  1. Review generated files"
echo "  2. Commit and push to GitHub"
echo "  3. The CD pipeline will build and deploy on push to main"
echo ""
log_success "Done!"