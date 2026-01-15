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
      echo "  --yes, -y                  Auto-approve all prompts (skip confirmations)"
      echo "  --custom-domain=DOMAIN     Custom domain for Cloud Run (e.g., app.example.com)"
      echo "  --provider=PROVIDER        Cloud provider: gcp (default), aws*, azure* (*coming soon)"
      echo "  --env-file=PATH            Environment file to process (auto-detects .env.local)"
      echo "  --project-type=TYPE        Project type (required): nodejs, laravel-api, laravel-ssr, java-maven, java-gradle, docker-only"
      echo "  --storage-bucket=NAME      GCS bucket name for application storage (Terraform grants objectAdmin to Cloud Run SA)"
      echo "  --container-port=PORT      Container port (default: 3000 for nodejs, 80 for laravel, 8080 for java)"
      echo "  --health-check-path=PATH   Health check endpoint (default: /api/health for nodejs, /up for laravel)"
      echo "  --registry-name=NAME       Artifact Registry name (default: same as service-name)"
      echo "  --tf-state-bucket=NAME     GCS bucket name for Terraform state (default: {project-id}-tfstate)"
      echo "  --vpc-network=NAME         VPC network for Direct VPC Egress (e.g., 'default' or 'projects/PROJECT/global/networks/NETWORK')"
      echo "  --vpc-subnetwork=NAME      VPC subnetwork for Direct VPC Egress (e.g., 'default' or 'projects/PROJECT/regions/REGION/subnetworks/SUBNET')"
      echo "  --help                     Show this help"
      echo ""
      echo "Project types:"
      echo "  nodejs       - Node.js project (yarn/npm build before Docker)"
      echo "  laravel-api  - Laravel API only (composer install, no frontend build)"
      echo "  laravel-ssr  - Laravel with Inertia SSR (composer + yarn build)"
      echo "  java-maven   - Java project with Maven (mvn package before Docker)"
      echo "  java-gradle  - Java project with Gradle (./gradlew build before Docker)"
      echo "  docker-only  - Multi-stage Dockerfile handles everything"
      echo ""
      echo "Example:"
      echo "  ./bootstrap.sh \\"
      echo "    --project-id=my-project \\"
      echo "    --service-name=my-app \\"
      echo "    --github-repo=myuser/my-app \\"
      echo "    --project-type=nodejs \\"
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

if [[ -z "$PROJECT_TYPE" ]]; then
  log_error "Missing required argument: --project-type"
  log_info "Options: nodejs, laravel-api, laravel-ssr, java-maven, java-gradle, docker-only"
  exit 1
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

# Terraform state bucket name (custom or default: {project-id}-tfstate)
STATE_BUCKET="${TF_STATE_BUCKET:-${PROJECT_ID}-tfstate}"

# Directory paths
INFRA_DIR="$OUTPUT_DIR/infra/gcp"
WORKFLOWS_DIR="$OUTPUT_DIR/.github/workflows"

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
        uses: actions/cache@v4
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
        uses: actions/setup-java@v4
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
        uses: actions/setup-java@v4
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
        uses: actions/cache@v4
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
        uses: actions/cache@v4
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
        uses: actions/cache@v4
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
        uses: actions/cache@v4
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
        uses: actions/cache@v4
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
        uses: actions/setup-java@v4
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
        uses: actions/setup-java@v4
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
  terraform init

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