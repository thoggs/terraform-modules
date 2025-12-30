# Terraform Modules

Reusable Terraform modules for multi-cloud infrastructure.

## Structure

```
terraform-modules/
├── modules/
│   ├── gcp/
│   │   ├── cloud-run/          # Google Cloud Run service
│   │   ├── workload-identity/  # GitHub Actions OIDC authentication
│   │   ├── artifact-registry/  # Docker container registry
│   │   └── secrets/            # Secret Manager secrets
│   ├── aws/                    # (future)
│   └── azure/                  # (future)
├── examples/
│   └── gcp-cloud-run-complete/ # Full example with all GCP modules
└── scripts/
    └── bootstrap.sh            # Initial setup script
```

## Quick Start

### 1. Prerequisites

```bash
# Install gcloud CLI
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login
```

### 2. Create GCP Project (Console)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create new project
3. Link billing account
4. Note the Project ID

### 3. Bootstrap Infrastructure

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/terraform-modules.git
cd terraform-modules

# Run bootstrap script
./scripts/bootstrap.sh \
  --project-id="your-project-id" \
  --region="us-central1" \
  --service-name="your-service" \
  --github-repo="owner/repo"
```

### 4. Configure GitHub Secrets

After bootstrap, copy the outputs to your GitHub repository secrets:

| Secret Name                      | Value                                         |
|----------------------------------|-----------------------------------------------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `terraform output workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT_EMAIL`      | `terraform output service_account_email`      |
| `TERRAFORM_TFVARS`               | Contents of your `terraform.tfvars` file      |

---

## Module Usage

### Using in Your Project

```hcl
# your-project/infra/main.tf

module "cloud_run" {
  source = "github.com/YOUR_USERNAME/terraform-modules//modules/gcp/cloud-run?ref=v1.0.0"

  project_id   = "your-project-id"
  region       = "us-central1"
  service_name = "your-service"
  image        = "us-central1-docker.pkg.dev/your-project/your-service/your-service:latest"

  cpu           = "1"
  memory        = "512Mi"
  min_instances = 1
  max_instances = 10

  env_vars = {
    NODE_ENV = "production"
  }
}
```

---

## GCP Modules

### cloud-run

Deploys a Cloud Run service with:

- Service account
- Public access (optional)
- Custom domain (optional)
- Health checks (startup + liveness probes)
- Autoscaling configuration

**Variables:**

| Name                  | Description                       | Default       |
|-----------------------|-----------------------------------|---------------|
| `project_id`          | GCP Project ID                    | required      |
| `region`              | GCP Region                        | `us-central1` |
| `service_name`        | Service name                      | required      |
| `image`               | Container image URL               | required      |
| `cpu`                 | CPU limit                         | `1`           |
| `memory`              | Memory limit                      | `512Mi`       |
| `min_instances`       | Min instances (0 = scale to zero) | `0`           |
| `max_instances`       | Max instances                     | `10`          |
| `cpu_idle`            | CPU idle billing                  | `true`        |
| `env_vars`            | Environment variables             | `{}`          |
| `secret_env_vars`     | Secret env vars                   | `{}`          |
| `allow_public_access` | Allow unauthenticated access      | `true`        |
| `custom_domain`       | Custom domain                     | `""`          |

**Outputs:**

| Name                    | Description           |
|-------------------------|-----------------------|
| `url`                   | Cloud Run service URL |
| `service_account_email` | Service account email |

---

### workload-identity

Sets up Workload Identity Federation for GitHub Actions:

- Identity Pool
- OIDC Provider
- Service Account with IAM roles

**Variables:**

| Name                 | Description              | Default          |
|----------------------|--------------------------|------------------|
| `project_id`         | GCP Project ID           | required         |
| `github_repo`        | GitHub repo (owner/repo) | required         |
| `pool_id`            | Pool ID                  | `github-pool`    |
| `service_account_id` | SA ID                    | `github-actions` |

**Outputs:**

| Name                         | Description                      |
|------------------------------|----------------------------------|
| `workload_identity_provider` | Provider name for GitHub Actions |
| `service_account_email`      | Service account email            |

---

### artifact-registry

Creates a Docker repository with cleanup policies.

**Variables:**

| Name                | Description            | Default       |
|---------------------|------------------------|---------------|
| `region`            | GCP Region             | `us-central1` |
| `repository_id`     | Repository ID          | required      |
| `delete_untagged`   | Delete untagged images | `true`        |
| `keep_recent_count` | Images to keep         | `2`           |

**Outputs:**

| Name             | Description              |
|------------------|--------------------------|
| `repository_url` | URL for docker push/pull |

---

### secrets

Manages Secret Manager secrets.

**Variables:**

| Name      | Description                   | Default |
|-----------|-------------------------------|---------|
| `secrets` | Map of secret names to values | `{}`    |

**Outputs:**

| Name         | Description                |
|--------------|----------------------------|
| `secret_ids` | Map of secret names to IDs |

---

## Versioning

This repository follows [Semantic Versioning](https://semver.org/):

- `v1.0.0` - Initial stable release
- `v1.1.0` - New features (backwards compatible)
- `v2.0.0` - Breaking changes

Pin your module versions:

```hcl
source = "github.com/USER/terraform-modules//modules/gcp/cloud-run?ref=v1.0.0"
```

---

## GitHub Actions Workflow

Example workflow for your project:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_EMAIL }}

      - name: Configure Docker
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev

      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT }}/${{ env.SERVICE }}/${{ env.SERVICE }}:${{ github.sha }}

      - name: Terraform Apply
        working-directory: infra
        run: |
          terraform init
          terraform apply -auto-approve -var="image_tag=${{ github.sha }}"
```

---

## License

MIT