# Capstone Infra Addon

This repository contains AWS infrastructure and Kubernetes deployment support for the Capstone project.

## Project Overview

- **Terraform-based AWS provisioning** for VPC, subnets, EKS, ECR, IAM, and networking.
- **Kustomize-managed Kubernetes manifests** for application and cluster resources.
- **Multi-environment configuration** with separate Dev and Prod variable files.
- **OPA/Conftest policy enforcement** in the `policies/` directory for security, compliance, and tagging rules.

## Key Folders

- `env/` - Environment-specific Terraform and Kubernetes configuration files:
  - `dev.tfvars`, `prod.tfvars`
  - `backend-dev.tfvars`, `backend-prod.tfvars`
  - `values-dev.yaml`, `values-prod.yaml`
  - `aws-lb-controller-base.yaml`
- `bootstrap/` - Initial setup for Terraform backend and state-related bootstrap resources.
- `policies/` - OPA rules used by `conftest` to validate Terraform plans.

## Typical Workflow

1. Update Terraform or Kubernetes configuration in the repo.
2. Select the target environment files:
   - `env/dev.tfvars` and `env/backend-dev.tfvars`
   - `env/prod.tfvars` and `env/backend-prod.tfvars`
3. Initialize Terraform if needed:
   ```bash
   terraform init -backend-config=env/backend-dev.tfvars
   ```
4. Plan changes:
   ```bash
   terraform plan -var-file=env/dev.tfvars
   ```
5. Run policy checks (CI/CD or locally):
   ```bash
   conftest test -p policies/ terraform.tfplan
   ```
6. Apply changes:
   ```bash
   terraform apply -var-file=env/dev.tfvars
   ```
7. Deploy or update Kubernetes resources via `kustomization.yaml` and the matching environment values file.

## Notes

- The project uses **AWS** and expects region/config values from the `env/` files.
- `bootstrap/` contains the initial Terraform state setup and is used for first-time infrastructure provisioning.
- Policy rules in `policies/` help enforce tagging, security, networking, and IAM standards.

For more detail, refer to the external wiki link if available.
