#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    --create-project)
      CREATE_PROJECT=true
      shift
      ;;
    --help)
      echo "Usage: ./bootstrap.sh [options]"
      echo ""
      echo "Options:"
      echo "  --project-id=ID        GCP Project ID (required)"
      echo "  --region=REGION        GCP Region (default: us-central1)"
      echo "  --service-name=NAME    Service name (required)"
      echo "  --github-repo=REPO     GitHub repo owner/repo (required)"
      echo "  --billing-account=ID   Billing account ID (required if --create-project)"
      echo "  --create-project       Create new GCP project"
      echo "  --help                 Show this help"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set defaults
REGION="${REGION:-us-central1}"

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

print_header "GCP Cloud Run Bootstrap"

echo "Configuration:"
echo "  Project ID:    $PROJECT_ID"
echo "  Region:        $REGION"
echo "  Service Name:  $SERVICE_NAME"
echo "  GitHub Repo:   $GITHUB_REPO"
echo "  State Bucket:  $STATE_BUCKET"
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

# Set project
gcloud config set project "$PROJECT_ID"

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

# Create terraform.tfvars
print_header "Step 5: Creating Terraform Configuration"

TFVARS_FILE="terraform.tfvars"

cat > "$TFVARS_FILE" << EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
service_name = "$SERVICE_NAME"
github_repo  = "$GITHUB_REPO"

cpu           = "1"
memory        = "512Mi"
min_instances = 0
max_instances = 2

env_vars = {
  NODE_ENV = "production"
}

secret_env_vars = {}
EOF

log_success "Created $TFVARS_FILE"

# Create main.tf that uses modules
cat > "main.tf" << EOF
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
  project = var.project_id
  region  = var.region
}

module "workload_identity" {
  source = "github.com/$GITHUB_REPO/../terraform-modules//modules/gcp/workload-identity?ref=main"

  project_id  = var.project_id
  github_repo = var.github_repo
}

module "artifact_registry" {
  source = "github.com/$GITHUB_REPO/../terraform-modules//modules/gcp/artifact-registry?ref=main"

  region        = var.region
  repository_id = var.service_name
  description   = "Docker repository for \${var.service_name}"
}

module "secrets" {
  source = "github.com/$GITHUB_REPO/../terraform-modules//modules/gcp/secrets?ref=main"

  secrets = var.secret_env_vars
}

module "cloud_run" {
  source = "github.com/$GITHUB_REPO/../terraform-modules//modules/gcp/cloud-run?ref=main"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = "\${var.region}-docker.pkg.dev/\${var.project_id}/\${var.service_name}/\${var.service_name}:\${var.image_tag}"

  cpu           = var.cpu
  memory        = var.memory
  min_instances = var.min_instances
  max_instances = var.max_instances

  env_vars = var.env_vars

  secret_env_vars = {
    for name, _ in var.secret_env_vars : name => {
      secret_id = module.secrets.secret_ids[name]
      version   = "latest"
    }
  }

  allow_public_access = true
  deletion_protection = false

  depends_on = [module.artifact_registry, module.secrets]
}
EOF

log_success "Created main.tf"

# Create variables.tf
cat > "variables.tf" << 'EOF'
variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "service_name" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_env_vars" {
  type      = map(string)
  default   = {}
  sensitive = true
}
EOF

log_success "Created variables.tf"

# Create outputs.tf
cat > "outputs.tf" << 'EOF'
output "workload_identity_provider" {
  description = "Workload Identity Provider for GitHub Actions"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "GitHub Actions Service Account email"
  value       = module.workload_identity.service_account_email
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = module.artifact_registry.repository_url
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = module.cloud_run.url
}
EOF

log_success "Created outputs.tf"

# Terraform init and apply
print_header "Step 6: Running Terraform"

log_info "Terraform init..."
terraform init

log_info "Terraform plan..."
terraform plan -var-file=terraform.tfvars -out=tfplan

echo ""
read -p "Apply this plan? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
  log_info "Terraform apply..."
  terraform apply tfplan
  log_success "Terraform applied"
else
  log_warn "Skipped terraform apply"
fi

# Print outputs
print_header "Step 7: GitHub Secrets Configuration"

echo "Add these secrets to your GitHub repository:"
echo ""
echo "┌────────────────────────────────────────────────────────────────────┐"
echo "│ Repository Settings → Secrets and variables → Actions             │"
echo "├────────────────────────────────────────────────────────────────────┤"

echo "│                                                                    │"
echo "│ GCP_WORKLOAD_IDENTITY_PROVIDER:                                    │"
terraform output -raw workload_identity_provider 2>/dev/null || echo "(run terraform apply first)"
echo ""
echo "│                                                                    │"
echo "│ GCP_SERVICE_ACCOUNT_EMAIL:                                         │"
terraform output -raw service_account_email 2>/dev/null || echo "(run terraform apply first)"
echo ""
echo "│                                                                    │"
echo "│ TERRAFORM_TFVARS:                                                  │"
echo "│ (Copy contents of terraform.tfvars file)                           │"
echo "│                                                                    │"
echo "└────────────────────────────────────────────────────────────────────┘"

print_header "Bootstrap Complete!"

echo "Next steps:"
echo "  1. Copy the outputs above to GitHub Secrets"
echo "  2. Build and push your first Docker image"
echo "  3. Run terraform apply with image_tag"
echo ""
log_success "Done!"