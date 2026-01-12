#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Migrate GCP Cloud Run infrastructure from one region to another."
  echo ""
  echo "Required options:"
  echo "  --project-id=ID            GCP Project ID"
  echo "  --service-name=NAME        Cloud Run service name"
  echo "  --old-region=REGION        Current region (e.g., us-central1)"
  echo "  --new-region=REGION        Target region (e.g., southamerica-east1)"
  echo "  --infra-dir=PATH           Path to infra/gcp directory"
  echo ""
  echo "Optional options:"
  echo "  --registry-name=NAME       Artifact Registry name (default: same as service-name)"
  echo "  --custom-domain=DOMAIN     Custom domain to remove mapping (optional)"
  echo "  --skip-delete              Skip deletion of old resources"
  echo "  --skip-state-cleanup       Skip terraform state cleanup"
  echo "  --dry-run                  Show what would be done without executing"
  echo "  --yes, -y                  Auto-approve (skip confirmation prompt)"
  echo "  -h, --help                 Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 \\"
  echo "    --project-id=my-project \\"
  echo "    --service-name=my-app \\"
  echo "    --registry-name=my-app-gcr \\"
  echo "    --custom-domain=app.example.com \\"
  echo "    --old-region=us-central1 \\"
  echo "    --new-region=southamerica-east1 \\"
  echo "    --infra-dir=/path/to/project/infra/gcp"
  echo ""
}

PROJECT_ID=""
SERVICE_NAME=""
REGISTRY_NAME=""
CUSTOM_DOMAIN=""
OLD_REGION=""
NEW_REGION=""
INFRA_DIR=""
SKIP_DELETE="false"
SKIP_STATE_CLEANUP="false"
DRY_RUN="false"
AUTO_APPROVE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id=*)
      PROJECT_ID="${1#*=}"
      shift
      ;;
    --service-name=*)
      SERVICE_NAME="${1#*=}"
      shift
      ;;
    --registry-name=*)
      REGISTRY_NAME="${1#*=}"
      shift
      ;;
    --custom-domain=*)
      CUSTOM_DOMAIN="${1#*=}"
      shift
      ;;
    --old-region=*)
      OLD_REGION="${1#*=}"
      shift
      ;;
    --new-region=*)
      NEW_REGION="${1#*=}"
      shift
      ;;
    --infra-dir=*)
      INFRA_DIR="${1#*=}"
      shift
      ;;
    --skip-delete)
      SKIP_DELETE="true"
      shift
      ;;
    --skip-state-cleanup)
      SKIP_STATE_CLEANUP="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --yes|-y)
      AUTO_APPROVE="true"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

REGISTRY_NAME="${REGISTRY_NAME:-$SERVICE_NAME}"

if [[ -z "$PROJECT_ID" ]] || [[ -z "$SERVICE_NAME" ]] || [[ -z "$OLD_REGION" ]] || [[ -z "$NEW_REGION" ]] || [[ -z "$INFRA_DIR" ]]; then
  log_error "Missing required options"
  show_help
  exit 1
fi

if [[ ! -d "$INFRA_DIR" ]]; then
  log_error "Infrastructure directory not found: $INFRA_DIR"
  exit 1
fi

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
  else
    "$@"
  fi
}

print_header "GCP Region Migration"

echo "Configuration:"
echo "  Project ID:     $PROJECT_ID"
echo "  Service Name:   $SERVICE_NAME"
echo "  Registry Name:  $REGISTRY_NAME"
echo "  Custom Domain:  ${CUSTOM_DOMAIN:-"(not set)"}"
echo "  Old Region:     $OLD_REGION"
echo "  New Region:     $NEW_REGION"
echo "  Infra Dir:      $INFRA_DIR"
echo "  Skip Delete:    $SKIP_DELETE"
echo "  Dry Run:        $DRY_RUN"
echo ""

if [[ "$DRY_RUN" != "true" ]] && [[ "$AUTO_APPROVE" != "true" ]]; then
  read -p "Proceed with migration? (y/n) " -n 1 -r < /dev/tty
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Migration cancelled"
    exit 0
  fi
fi

if [[ "$SKIP_STATE_CLEANUP" != "true" ]]; then
  print_header "Step 1: Cleaning Terraform State"

  cd "$INFRA_DIR"

  RESOURCES_TO_REMOVE=(
    "module.artifact_registry.google_artifact_registry_repository.main"
    "module.cloud_run.google_cloud_run_v2_service.main"
    "module.cloud_run.google_cloud_run_domain_mapping.main[0]"
    "module.cloud_run.google_cloud_run_service_iam_member.public_access[0]"
  )

  for resource in "${RESOURCES_TO_REMOVE[@]}"; do
    if terraform state show "$resource" &>/dev/null; then
      log_info "Removing from state: $resource"
      run_cmd terraform state rm "$resource" || true
    else
      log_warn "Resource not in state: $resource"
    fi
  done

  log_success "Terraform state cleaned"
else
  log_warn "Skipping terraform state cleanup"
fi

if [[ "$SKIP_DELETE" != "true" ]]; then
  print_header "Step 2: Deleting Old Resources"

  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    if gcloud beta run domain-mappings describe --domain="$CUSTOM_DOMAIN" --region="$OLD_REGION" --project="$PROJECT_ID" &>/dev/null 2>&1; then
      log_info "Deleting domain mapping for $CUSTOM_DOMAIN in $OLD_REGION..."
      run_cmd gcloud beta run domain-mappings delete \
        --domain="$CUSTOM_DOMAIN" \
        --region="$OLD_REGION" \
        --project="$PROJECT_ID" \
        --quiet || log_warn "Failed to delete domain mapping (may not exist)"
    else
      log_warn "No domain mapping found for $CUSTOM_DOMAIN in $OLD_REGION"
    fi
  else
    log_warn "No custom domain specified, skipping domain mapping deletion"
  fi

  if gcloud run services describe "$SERVICE_NAME" --region="$OLD_REGION" --project="$PROJECT_ID" &>/dev/null 2>&1; then
    log_info "Deleting Cloud Run service in $OLD_REGION..."
    run_cmd gcloud run services delete "$SERVICE_NAME" \
      --region="$OLD_REGION" \
      --project="$PROJECT_ID" \
      --quiet
    log_success "Cloud Run service deleted"
  else
    log_warn "No Cloud Run service found in $OLD_REGION"
  fi

  if gcloud artifacts repositories describe "$SERVICE_NAME" --location="$OLD_REGION" --project="$PROJECT_ID" &>/dev/null 2>&1; then
    log_info "Deleting Artifact Registry in $OLD_REGION..."
    run_cmd gcloud artifacts repositories delete "$SERVICE_NAME" \
      --location="$OLD_REGION" \
      --project="$PROJECT_ID" \
      --quiet
    log_success "Artifact Registry deleted"
  else
    log_warn "No Artifact Registry '$SERVICE_NAME' found in $OLD_REGION"
  fi

  log_success "Old resources deleted"
else
  log_warn "Skipping deletion of old resources"
fi

print_header "Step 3: Summary"

echo "Migration preparation complete!"
echo ""
echo "Next steps:"
echo "  1. Run the bootstrap script with the new region:"
echo ""
echo -e "${GREEN}curl -fsSL \"https://raw.githubusercontent.com/thoggs/terraform-modules/main/scripts/bootstrap.sh?\$(date +%s)\" | bash -s -- \\${NC}"
echo -e "${GREEN}  --project-id=$PROJECT_ID \\${NC}"
echo -e "${GREEN}  --service-name=$SERVICE_NAME \\${NC}"
echo -e "${GREEN}  --registry-name=$REGISTRY_NAME \\${NC}"
echo -e "${GREEN}  --region=$NEW_REGION \\${NC}"
echo -e "${GREEN}  --github-repo=<your-github-repo> \\${NC}"
echo -e "${GREEN}  --output-dir=<your-project-dir> \\${NC}"
echo -e "${GREEN}  --custom-domain=<your-domain> \\${NC}"
echo -e "${GREEN}  --project-type=<laravel-ssr|nodejs|static>${NC}"
echo ""

if [[ "$SKIP_DELETE" == "true" ]]; then
  echo -e "${YELLOW}Remember to manually delete old resources:${NC}"
  echo "  gcloud beta run domain-mappings delete --domain=<domain> --region=$OLD_REGION --project=$PROJECT_ID"
  echo "  gcloud run services delete $SERVICE_NAME --region=$OLD_REGION --project=$PROJECT_ID"
  echo "  gcloud artifacts repositories delete $SERVICE_NAME --location=$OLD_REGION --project=$PROJECT_ID"
  echo ""
fi

log_success "Migration script completed!"
