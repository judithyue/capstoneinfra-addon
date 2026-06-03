# OPA/Conftest Policies for Terraform

This directory contains industry best-practice OPA policies for Terraform configurations. These policies are enforced via `conftest` in the CI/CD pipeline.

## Policy Files

### `tags.rego` - Tagging Standards
- Enforces mandatory tags on taggable resources (Name, Environment, Owner, Project, CostCenter)
- Prevents resources without tags
- Warns about empty tag values
- **Impact**: Ensures cost tracking, resource ownership, and lifecycle management

### `security.rego` - Security Best Practices
- Denies public S3 bucket ACLs
- Requires RDS encryption and prohibits public accessibility
- Warns about unrestricted security group access on sensitive ports (SSH 22, DB 3306/5432, etc.)
- Enforces EKS cluster encryption and backup retention
- Enables CloudTrail for audit logs
- **Impact**: Reduces attack surface and ensures compliance

### `networking.rego` - Network Security
- Ensures VPCs have DNS hostnames enabled
- Warns about subnets without route tables
- Requires NAT Gateways for private subnets
- Checks for overly permissive Network ACLs
- Recommends VPC Flow Logs
- **Impact**: Ensures proper network isolation and observability

### `iam.rego` - IAM Least Privilege
- Denies overly broad IAM policies (Action: *, Resource: *)
- Warns about wildcard actions in policies
- Recommends IAM roles over user access keys
- Ensures EKS roles have required policies attached
- Restricts S3 bucket policies to specific principals
- **Impact**: Implements principle of least privilege for security

### `general.rego` - General Best Practices
- Recommends Terraform version >= 1.x
- Warns about hard-coded AZs (use data sources instead)
- Checks for appropriate resource sizing to control costs
- Enforces naming conventions
- Ensures database snapshot handling
- Enables access logs on load balancers
- **Impact**: Improves code quality and cost management

### `eks.rego` - EKS-Specific Best Practices
- Enforces private API endpoint access for EKS clusters
- Warns about public endpoint unrestricted access
- Requires tags on node groups
- Checks for outdated EKS AMI types
- Ensures minimum node count for availability
- Requires capacity type specification (spot vs on-demand)
- Recommends EKS add-ons (VPC-CNI, CoreDNS, kube-proxy)
- **Impact**: Hardens EKS deployments and ensures HA/DR

## How It Works

1. **During CI/CD**: `conftest test -p ./policies .` scans all Terraform files
2. **Violations**:
   - `deny` rules fail the build
   - `warn` rules pass but generate warnings
3. **Customize**: Edit `.rego` files to match your organization's standards

## Running Locally

```bash
# Install conftest
curl -sL "https://github.com/open-policy-agent/conftest/releases/download/v0.32.0/conftest_v0.32.0_Linux_x86_64.tar.gz" | tar xzf - -C /usr/local/bin

# Test Terraform files against policies
conftest test -p ./policies *.tf

# Verbose output
conftest test -p ./policies *.tf -v

# Test specific file
conftest test -p ./policies main.tf
```

## Customization Guide

### Add a new policy
1. Create `new_policy.rego` in this directory
2. Define `deny[msg]` for hard failures
3. Define `warn[msg]` for warnings
4. Test with `conftest test`

### Disable a specific rule
Comment out the rule in the `.rego` file:

```rego
# deny[msg] {
#   ...
# }
```

### Override for specific resources
Add exceptions in the policy logic:

```rego
# Exceptions for specific resources
exceptions := ["my-legacy-bucket"]

deny[msg] {
  bucket := input.resource.aws_s3_bucket[name]
  name not in exceptions
  bucket.public_acl[0] == true
  msg := sprintf("...")
}
```

## Industry Standards Covered

- **AWS Well-Architected Framework** (Security, Reliability, Cost Optimization)
- **CIS AWS Foundations Benchmark**
- **NIST Cybersecurity Framework**
- **Terraform Best Practices** (HashiCorp)
- **Kubernetes (EKS) Security Best Practices**

## References

- [OPA Documentation](https://www.openpolicyagent.org/)
- [Conftest](https://www.conftest.dev/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
