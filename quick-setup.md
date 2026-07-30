# Quick Setup — Linux VM

This document describes how to prepare a Linux VM, update the Compose configuration, and deploy the Formflow stack using Docker Compose. It also explains required secrets/variables and how the CI/CD pipeline finds Terraform files.

## Prerequisites

- SSH access to the VM.
- Docker and Docker Compose installed on the VM.
- Docker Hub account (or a registry you control) with pushed `formflow-backend` and `formflow-frontend` images.
- (Optional) Azure access for Terraform remote state setup.

## 1. Prepare the VM file structure

SSH into your Linux VM and create the required directories with correct ownership:

```bash
ssh your-user@YOUR_VM_PUBLIC_IP
sudo mkdir -p /opt/formflow/{deployment,nginx}
sudo chown -R "$USER":"$USER" /opt/formflow
cd /opt/formflow
```

Create or copy the following files into `/opt/formflow` (the contents can come from this repo's `formflow-linux-vm` folder):

- `docker-compose.yml`
- `deployment/db.env`
- `deployment/backend.env`
- `deployment/frontend.env`
- `nginx/nginx.conf`

Tip: keep `.env` files out of the repo and populate them in CI or via secrets.

## 2. Update image tags in `docker-compose.yml`

Open `docker-compose.yml` and set the images to the tags you pushed to Docker Hub:

```yaml
# Example (replace tags):
services:
    backend:
        image: yourusername/formflow-backend:1.0.0
    frontend:
        image: yourusername/formflow-frontend:1.0.0
```

## 3. Login to Docker Hub on the VM

Authenticate so the VM can pull the images:

```bash
docker login
# enter your Docker Hub username and password/token
```

If you use a private registry, update `docker login` accordingly and/or configure `docker-credentials` on the host.

## 4. Pull images and start the stack

```bash
cd /opt/formflow
docker compose pull
docker compose up -d
```

## 5. Verify everything is running

Check running containers and recent logs:

```bash
docker compose ps
docker compose logs backend --tail 30
docker compose logs frontend --tail 30
docker compose logs nginx --tail 20
```

Test health endpoints from the VM:

```bash
curl http://localhost/healthz
curl http://localhost/api/health
```

Then open your browser and visit `http://YOUR_VM_PUBLIC_IP`.

---

## Required secrets / credentials (high level)

These items are used by Terraform, the VM, and CI/CD pipelines:

| Item                                                                | Why                                              |
| ------------------------------------------------------------------- | ------------------------------------------------ |
| Azure Service Principal / OIDC credentials                          | Terraform authentication with Azure              |
| `VM_SSH_PUBLIC_KEY`                                                 | Provision VM access for the admin user           |
| `VM_SSH_KEY`                                                        | Private key used by pipelines to SSH into the VM |
| Docker registry credentials (`DOCKER_USERNAME` / `DOCKER_PASSWORD`) | Pull private images                              |
| Terraform state storage (Resource Group + Storage Account)          | Remote, shared Terraform state                   |

### Recommended secrets (table)

| Secret name                    | Description                         | Notes                                    |
| ------------------------------ | ----------------------------------- | ---------------------------------------- |
| AZURE_CLIENT_ID                | Service Principal client id         | From Azure AD app registration           |
| AZURE_TENANT_ID                | Azure tenant id                     | From Azure portal                        |
| AZURE_SUBSCRIPTION_ID          | Subscription id                     | From Azure portal                        |
| VM_SSH_PUBLIC_KEY              | Public SSH key contents             | Used by Terraform to provision VM access |
| VM_SSH_KEY                     | Private SSH key contents            | For CI to SSH into VM (keep secret)      |
| DOCKER_USERNAME                | Docker Hub username                 |                                          |
| DOCKER_PASSWORD                | Docker Hub password or access token | Prefer access token                      |
| POSTGRES_PASSWORD              | Postgres DB password                | Strong secret                            |
| JWT_SECRET                     | JWT signing secret                  | Long random string                       |
| ADMIN_EMAIL                    | Admin user email                    |                                          |
| ADMIN_PASSWORD                 | Admin user password                 |                                          |
| APP_AZURE_STORAGE_ACCOUNT_NAME | Azure storage account name          | Optional for blob storage                |
| APP_AZURE_STORAGE_ACCOUNT_KEY  | Azure storage account key           | Optional                                 |
| APP_AZURE_ENDPOINT             | Azure OpenAI endpoint               | Optional                                 |
| APP_AZURE_API_KEY              | Azure OpenAI key                    | Optional                                 |

Best practice: store sensitive values in GitHub Actions Secrets and non-sensitive config in Actions Variables.

---

## CI/CD and Terraform location

Your pipeline expects Terraform files in this repo path:

```
Infrastructure/terraform/
```

Example pipeline environment variable used in the workflow:

```yaml
env:
    TF_WORKING_DIR: Infrastructure/terraform
```

Then pipeline steps run in that directory:

```yaml
working-directory: ${{ env.TF_WORKING_DIR }}
run: terraform init
run: terraform plan
run: terraform apply
```

Ensure all Terraform files (`main.tf`, `variables.tf`, `providers.tf`, etc.) are inside `Infrastructure/terraform/`.

---

## One-time: Create Terraform remote state storage (Azure)

Use the Azure CLI to create a resource group, storage account, and container for the Terraform state. Update names to be globally unique where required.

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

az group create \
  --name tfstate-rg \
  --location uksouth

az storage account create \
  --name tfstateformflow123 \
  --resource-group tfstate-rg \
  --location uksouth \
  --sku Standard_LRS \
  --encryption-services blob \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name tfstateformflow123
```

After creating the storage account and container, add these GitHub variables/secrets for your pipeline:

| Variable name            | Example value         |
| ------------------------ | --------------------- |
| TF_STATE_RESOURCE_GROUP  | tfstate-rg            |
| TF_STATE_STORAGE_ACCOUNT | tfstateformflow123    |
| TF_STATE_CONTAINER       | tfstate               |
| TF_STATE_KEY             | formflow-prod.tfstate |

---

If you'd like, I can also:

- Add a sample `docker-compose.yml` snippet for this repo.
- Generate `deployment/*.env` templates from the repository values.
- Add a short Table of Contents at the top.
