terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "workload_identity" {
  source = "github.com/YOUR_USERNAME/terraform-modules//modules/gcp/workload-identity?ref=v1.0.0"

  project_id  = var.project_id
  github_repo = var.github_repo
}

module "artifact_registry" {
  source = "github.com/YOUR_USERNAME/terraform-modules//modules/gcp/artifact-registry?ref=v1.0.0"

  region        = var.region
  repository_id = var.service_name
  description   = "Docker repository for ${var.service_name}"
}

module "secrets" {
  source = "github.com/YOUR_USERNAME/terraform-modules//modules/gcp/secrets?ref=v1.0.0"

  secrets = var.secret_env_vars
}

module "cloud_run" {
  source = "github.com/YOUR_USERNAME/terraform-modules//modules/gcp/cloud-run?ref=v1.0.0"

  project_id   = var.project_id
  region       = var.region
  service_name = var.service_name
  image        = "${module.artifact_registry.repository_url}/${var.service_name}:${var.image_tag}"

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

  custom_domain       = var.custom_domain
  allow_public_access = var.allow_public_access
  deletion_protection = var.deletion_protection

  depends_on = [module.artifact_registry, module.secrets]
}