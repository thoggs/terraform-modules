# Terraform Modules

Reusable Terraform modules for multi-cloud infrastructure with automated bootstrap.

## Quick Start (One Command)

```bash
curl -fsSL "https://raw.githubusercontent.com/thoggs/terraform-modules/main/scripts/bootstrap.sh" | bash -s -- \
  --project-id=my-project \
  --service-name=my-app \
  --github-repo=myuser/my-app \
  --output-dir=/path/to/my-app
```

This single command will:
1. Enable required GCP APIs
2. Create Terraform state bucket
3. Create Artifact Registry
4. Build and push Docker image
5. Process environment variables (secrets → GCP Secret Manager)
6. Generate Terraform configuration
7. Generate GitHub Actions CI/CD workflows
8. Run Terraform to provision infrastructure
9. Configure GitHub repository secrets

## Structure

```
terraform-modules/
├── modules/
│   ├── gcp/
│   │   ├── cloud-run/          # Google Cloud Run service
│   │   ├── workload-identity/  # GitHub Actions OIDC authentication
│   │   └── artifact-registry/  # Docker container registry
│   ├── aws/                    # (coming soon)
│   └── azure/                  # (coming soon)
└── scripts/
    └── bootstrap.sh            # Automated setup script
```

---

## Bootstrap Script

### Prerequisites

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login

# Install GitHub CLI (optional, for auto-configuring secrets)
# https://cli.github.com
```

### Usage

```bash
curl -fsSL "https://raw.githubusercontent.com/thoggs/terraform-modules/main/scripts/bootstrap.sh" | bash -s -- [options]
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--project-id=ID` | GCP Project ID | required |
| `--service-name=NAME` | Service name | required |
| `--github-repo=REPO` | GitHub repo (owner/repo) | required |
| `--region=REGION` | GCP Region | `us-central1` |
| `--output-dir=PATH` | Output directory for generated files | current dir |
| `--env-file=PATH` | Environment file to process | auto-detects `.env.local` |
| `--custom-domain=DOMAIN` | Custom domain for Cloud Run | none |
| `--create-project` | Create new GCP project | false |
| `--billing-account=ID` | Billing account (required with --create-project) | none |
| `--skip-terraform` | Skip terraform execution | false |
| `--provider=PROVIDER` | Cloud provider: `gcp`, `aws*`, `azure*` (*coming soon) | `gcp` |

### Example with All Options

```bash
curl -fsSL "https://raw.githubusercontent.com/thoggs/terraform-modules/main/scripts/bootstrap.sh" | bash -s -- \
  --project-id=my-gcp-project \
  --service-name=my-app \
  --github-repo=myuser/my-app \
  --region=us-central1 \
  --output-dir=/path/to/my-app \
  --env-file=/path/to/my-app/.env.local \
  --custom-domain=app.example.com
```

---

## Environment Variables

The bootstrap script processes `.env.local` files and classifies variables as **public** (plain env vars) or **secret** (stored in GCP Secret Manager).

### Annotation Syntax

```bash
# .env.local

# Regular env vars (default - stored as plain env vars in Cloud Run)
NODE_ENV=production
API_URL=https://api.example.com

# @secret
# Variables marked with @secret are stored in GCP Secret Manager
DATABASE_PASSWORD=super-secret-password

# @public
# Explicitly mark as public (optional, this is the default)
PUBLIC_KEY=some-public-value
```

### How It Works

1. Variables marked with `# @secret` are:
   - Created in GCP Secret Manager (name converted to lowercase-kebab-case)
   - Referenced by Cloud Run as secret environment variables
   - Never exposed in terraform.tfvars

2. All other variables are:
   - Stored as plain environment variables in Cloud Run
   - Visible in terraform.tfvars

---

## Health Check Endpoint

Cloud Run requires a health check endpoint. Add this to your Next.js app:

```typescript
// src/app/api/health/route.ts
import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({ status: 'ok' }, { status: 200 })
}
```

The default health check path is `/api/health`. This can be configured via the `health_check_path` variable in the cloud-run module.

---

## Generated Files

After running bootstrap, these files are created:

```
your-project/
├── infra/
│   └── gcp/
│       ├── main.tf              # Terraform configuration
│       ├── variables.tf         # Variable definitions
│       ├── outputs.tf           # Output definitions
│       ├── terraform.tfvars     # Variable values (gitignored)
│       ├── terraform.tfvars.example
│       └── .gitignore
└── .github/
    └── workflows/
        ├── ci.yml               # PR validation (terraform plan, build)
        └── cd.yml               # Deploy on push to main
```

---

## GitHub Secrets

The bootstrap configures these secrets automatically (if GitHub CLI is installed):

| Secret | Description |
|--------|-------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity provider for OIDC auth |
| `GCP_SERVICE_ACCOUNT_EMAIL` | Service account for GitHub Actions |
| `TERRAFORM_TFVARS` | Terraform variables (includes secrets mapping) |

---

## Custom Domain

When using `--custom-domain`, you need to:

### 1. Verify Domain Ownership

Go to [Google Search Console](https://search.google.com/search-console/welcome):
1. Click "Add property"
2. Select "URL prefix"
3. Enter your root domain (e.g., `https://example.com`)
4. Complete DNS or HTML verification

### 2. Configure DNS

Add a CNAME record in your DNS provider:

| Type | Name | Target |
|------|------|--------|
| CNAME | `app` (subdomain) | `ghs.googlehosted.com` |

**Note:** If using Cloudflare, set proxy status to "DNS only" (gray cloud).

---

## GCP Modules

### cloud-run

Deploys a Cloud Run service with service account, health checks, autoscaling, and optional custom domain.

```hcl
module "cloud_run" {
  source = "github.com/thoggs/terraform-modules//modules/gcp/cloud-run?ref=main"

  project_id   = "my-project"
  region       = "us-central1"
  service_name = "my-app"
  image        = "us-central1-docker.pkg.dev/my-project/my-app/my-app:latest"

  env_vars = {
    NODE_ENV = "production"
  }

  secret_env_vars = {
    DATABASE_PASSWORD = {
      secret_id = "database-password"
      version   = "latest"
    }
  }

  custom_domain       = "app.example.com"
  allow_public_access = true
}
```

**Key Variables:**

| Name | Description | Default |
|------|-------------|---------|
| `cpu` | CPU limit | `1` |
| `memory` | Memory limit | `512Mi` |
| `min_instances` | Min instances (0 = scale to zero) | `0` |
| `max_instances` | Max instances | `10` |
| `health_check_path` | Health check endpoint | `/api/health` |
| `deletion_protection` | Prevent accidental deletion | `false` |

### workload-identity

Sets up Workload Identity Federation for GitHub Actions (no service account keys needed).

```hcl
module "workload_identity" {
  source = "github.com/thoggs/terraform-modules//modules/gcp/workload-identity?ref=main"

  project_id  = "my-project"
  github_repo = "myuser/my-repo"
}
```

### artifact-registry

Creates a Docker repository with cleanup policies.

```hcl
module "artifact_registry" {
  source = "github.com/thoggs/terraform-modules//modules/gcp/artifact-registry?ref=main"

  region        = "us-central1"
  repository_id = "my-app"
}
```

---

## Re-running Bootstrap

The bootstrap is **idempotent** - safe to run multiple times:

- Existing resources are detected and skipped
- Secrets get new versions (not duplicated)
- Terraform state is preserved
- Generated files are overwritten

---

## Troubleshooting

### "Workload Identity Pool already exists"

The pool may be in soft-delete state (30 days). Run:
```bash
gcloud iam workload-identity-pools undelete github-pool --location=global --project=PROJECT_ID
```

### "Permission denied on secret"

Grant access to the Cloud Run service account:
```bash
gcloud secrets add-iam-policy-binding SECRET_NAME \
  --project=PROJECT_ID \
  --member="serviceAccount:SERVICE_NAME-run@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Container startup failed

Ensure your app has a `/api/health` endpoint that returns HTTP 200.

---

## License

MIT