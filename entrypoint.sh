#!/usr/bin/env bash

set -euf
set -o pipefail

errVarUnset() {
  >&2 echo "\$$1 is not set. Exiting."
  exit 1
}

if [ -z "${ADDITIONAL_HOSTNAMES+x}" ]; then
    ADDITIONAL_HOSTNAMES='[]'
fi

if [ -z "${ADMIN_EMAIL+x}" ]; then
  errVarUnset 'ADMIN_EMAIL'
fi

if [ -z "${APP_DB_PASSWORD+x}" ]; then
  errVarUnset 'APP_DB_PASSWORD'
fi

if [ -z "${DB_BACKUP_BUCKET+x}" ]; then
  errVarUnset 'DB_BACKUP_BUCKET'
fi

if [ -z "${DB_BACKUP_REGION+x}" ]; then
  errVarUnset 'DB_BACKUP_REGION'
fi

if [ -z "${DEPLOY_HOST+x}" ]; then
  errVarUnset 'DEPLOY_HOST'
fi

if [ -z "${GRAFANA_GITHUB_CLIENT_ID+x}" ]; then
  errVarUnset 'GRAFANA_GITHUB_CLIENT_ID'
fi

if [ -z "${GRAFANA_GITHUB_CLIENT_SECRET+x}" ]; then
  errVarUnset 'GRAFANA_GITHUB_CLIENT_SECRET'
fi

if [ -z "${GRAFANA_GITHUB_ORGANIZATIONS+x}" ]; then
  errVarUnset 'GRAFANA_GITHUB_ORGANIZATIONS'
fi

if [ -z "${PRIMARY_HOSTNAME+x}" ]; then
  errVarUnset 'PRIMARY_HOSTNAME'
fi

if [ -z "${SECRET_KEY+x}" ]; then
  errVarUnset 'SECRET_KEY'
fi

if [ -z "${SPACES_ACCESS_KEY_ID+x}" ]; then
  errVarUnset 'SPACES_ACCESS_KEY_ID'
fi

if [ -z "${SPACES_SECRET_ACCESS_KEY+x}" ]; then
  errVarUnset 'SPACES_SECRET_ACCESS_KEY'
fi

if [ -z "${SSH_PRIVATE_KEY+x}" ]; then
  errVarUnset 'SSH_PRIVATE_KEY'
fi

if [ -z "${SSH_PUBLIC_KEY+x}" ]; then
  errVarUnset 'SSH_PUBLIC_KEY'
fi

if [ -z "${SUPER_DB_PASSWORD+x}" ]; then
  errVarUnset 'SUPER_DB_PASSWORD'
fi

if [ -z "${TERRAFORM_TOKEN+x}" ]; then
  errVarUnset 'TERRAFORM_TOKEN'
fi

if [ -z "${TERRAFORM_WORKSPACE+x}" ]; then
  errVarUnset 'TERRAFORM_WORKSPACE'
fi

if [ -z "${ZEROED_BOOKS_VERSION+x}" ]; then
  errVarUnset 'ZEROED_BOOKS_VERSION'
fi

cd /github/workspace/deploy/terraform

export TF_CLI_CONFIG_FILE="${HOME}/.terraformrc"

cat > "${TF_CLI_CONFIG_FILE}" <<EOF
credentials "app.terraform.io" {
    token = "${TERRAFORM_TOKEN}"
}
EOF
echo -e "Wrote Terraform config to '${TF_CLI_CONFIG_FILE}'\n\n"


export TF_WORKSPACE="${TERRAFORM_WORKSPACE}"
terraform init -input=false
terraform plan -input=false -out=tfplan
terraform apply -input=false tfplan

cd /github/workspace/deploy/ansible

ansible_key_file=.ansible_key_file
ansible_extra_params=.ansible-params
ansible_inventory_file=.ansible-inventory

echo "Writing Ansible configuration files to disk:"

echo "${SSH_PRIVATE_KEY}" > "${ansible_key_file}"
chmod 600 "${ansible_key_file}"
echo "  - Wrote SSH private key to '${ansible_key_file}'"

cat > "${ansible_extra_params}" <<EOF
{
  "additional_hostnames": ${ADDITIONAL_HOSTNAMES},
  "admin_email": "${ADMIN_EMAIL}",
  "db_password": "${APP_DB_PASSWORD}",
  "db_super_password": "${SUPER_DB_PASSWORD}",
  "grafana_github_client_id": "${GRAFANA_GITHUB_CLIENT_ID}",
  "grafana_github_client_secret": "${GRAFANA_GITHUB_CLIENT_SECRET}",
  "grafana_github_organizations": "${GRAFANA_GITHUB_ORGANIZATIONS}",
  "primary_hostname": "${PRIMARY_HOSTNAME}",
  "secret_key": "${SECRET_KEY}",
  "ssh_public_key": "${SSH_PUBLIC_KEY}",
  "zeroed_books_db_backup_bucket": "${DB_BACKUP_BUCKET}",
  "zeroed_books_db_backup_region": "${DB_BACKUP_REGION}",
  "zeroed_books_spaces_access_key_id": "${SPACES_ACCESS_KEY_ID}",
  "zeroed_books_spaces_secret_access_key": "${SPACES_SECRET_ACCESS_KEY}",
  "zeroed_books_version": "${ZEROED_BOOKS_VERSION}"
}
EOF
echo "  - Wrote parameters to '${ansible_extra_params}'"

cat > "${ansible_inventory_file}" <<EOF
[web]
${DEPLOY_HOST}
EOF
echo "  - Wrote inventory to '${ansible_inventory_file}'"
echo "Done."

export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_FORCE_COLOR=True

echo -e "\n\nRunning Ansible playbook:\n\n"

ansible-playbook \
  --extra-vars "@${ansible_extra_params}" \
  --inventory-file "${ansible_inventory_file}" \
  --key-file "${ansible_key_file}" \
  --verbose \
  ./deploy.yml

