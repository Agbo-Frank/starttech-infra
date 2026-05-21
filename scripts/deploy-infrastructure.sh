#!/usr/bin/env bash
# Usage: ./scripts/deploy-infrastructure.sh [plan|apply|destroy]
# Requires: AWS credentials set (env vars or ~/.aws/credentials) and TF_VAR_deployer_public_key

set -euo pipefail

ACTION=${1:-plan}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../terraform"

if [[ -z "${TF_VAR_deployer_public_key:-}" ]]; then
  echo "ERROR: TF_VAR_deployer_public_key is not set"
  echo "Export your SSH public key: export TF_VAR_deployer_public_key=\$(cat ~/.ssh/id_rsa.pub)"
  exit 1
fi

cd "$TF_DIR"

echo "=== Terraform Init ==="
terraform init

case "$ACTION" in
  plan)
    echo "=== Terraform Plan ==="
    terraform plan -var="deployer_public_key=${TF_VAR_deployer_public_key}"
    ;;
  apply)
    echo "=== Terraform Apply ==="
    terraform apply -var="deployer_public_key=${TF_VAR_deployer_public_key}" -auto-approve
    echo ""
    echo "=== Infrastructure Outputs ==="
    terraform output
    echo ""
    echo "NEXT STEPS:"
    echo "1. Whitelist NAT EIP IPs in MongoDB Atlas (see 'nat_eip_public_ips' output above)"
    echo "2. Store secrets in SSM:"
    echo "   aws ssm put-parameter --name /starttech/prod/MONGO_URI --value '<atlas-uri>' --type SecureString"
    echo "   aws ssm put-parameter --name /starttech/prod/JWT_SECRET_KEY --value \$(openssl rand -hex 32) --type SecureString"
    echo "3. Set GitHub Secrets in starttech-application repo (see README.md)"
    ;;
  destroy)
    echo "=== Terraform Destroy ==="
    echo "WARNING: This will destroy all infrastructure!"
    read -r -p "Type 'yes' to confirm: " confirm
    if [[ "$confirm" == "yes" ]]; then
      terraform destroy -var="deployer_public_key=${TF_VAR_deployer_public_key}" -auto-approve
    else
      echo "Aborted."
      exit 1
    fi
    ;;
  *)
    echo "ERROR: Unknown action '$ACTION'. Use: plan, apply, or destroy"
    exit 1
    ;;
esac
