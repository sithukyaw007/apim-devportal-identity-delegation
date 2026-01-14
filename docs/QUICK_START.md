# Quick Start Guide

This guide helps you get the APIM Identity Delegation solution up and running quickly.

## Prerequisites Checklist

- [ ] Azure subscription with contributor access
- [ ] Auth0 account (free tier is sufficient)
- [ ] Go 1.19+ installed
- [ ] Docker installed
- [ ] Azure CLI installed and logged in
- [ ] Git installed

## 5-Minute Setup (Local Development)

### Step 1: Clone Repository (30 seconds)

```bash
git clone https://github.com/sithukyaw007/apim-devportal-identity-delegation.git
cd apim-devportal-identity-delegation
```

### Step 2: Configure Auth0 (2 minutes)

1. Go to [Auth0 Dashboard](https://manage.auth0.com/)
2. Create new application:
   - Click **Applications** → **Create Application**
   - Name: `APIM Identity Delegation`
   - Type: **Regular Web Applications**
   - Click **Create**

3. Configure callbacks:
   - Go to **Settings** tab
   - **Allowed Callback URLs**: 
     ```
     http://localhost:3000/callback
     ```
   - **Allowed Logout URLs**:
     ```
     http://localhost:3000
     ```
   - Click **Save Changes**

4. Copy credentials (keep these handy):
   - Domain (e.g., `dev-abc123.us.auth0.com`)
   - Client ID
   - Client Secret

### Step 3: Setup Environment (1 minute)

```bash
cd src/identityApp
cp ../../.env.sample .env
```

Edit `.env` and set minimum required variables:

```bash
# Auth0 (from Step 2)
AUTH0_DOMAIN=dev-abc123.us.auth0.com
AUTH0_CLIENT_ID=your_client_id_here
AUTH0_CLIENT_SECRET=your_client_secret_here
AUTH0_CALLBACK_URL=http://localhost:3000/callback

# Azure (will use Azure CLI credentials locally)
AZURE_SUBSCRIPTION_ID=your_subscription_id
APIM_NAME=your-apim-name
APIM_RESOURCE_GROUP=your-resource-group
DEVELOPER_PORTAL_URL=https://your-apim.developer.azure-api.net/

# Generate a random base64 key
DELEGATION_KEY=$(echo -n "your-secret-key-here" | base64)
```

### Step 4: Install Dependencies (30 seconds)

```bash
go mod download
```

### Step 5: Run Application (30 seconds)

```bash
go run main.go
```

You should see:
```
Server listening on http://localhost:3000/
```

### Step 6: Test (30 seconds)

Open browser to [http://localhost:3000/](http://localhost:3000/)

You should see the home page!

## Full Azure Deployment (30 Minutes)

### Prerequisites

Ensure you have all values for `.env` file at project root.

### Step 1: Prepare Environment File

Copy sample and fill in all values:

```bash
cp .env.sample .env
```

Required variables:
```bash
# Azure Subscription
PERSONAL_SUB_ID=your-subscription-id
AZURE_SUBSCRIPTION_ID=your-subscription-id

# Naming
SUFFIX=unique-suffix-123
PUB_EMAIL=your@email.com
PUB_NAME=Your Name

# Container Registry (must be globally unique)
ACR_NAME=acrunique123
ACR_REPO_NAME=identity
IMAGE_TAG=latest

# Auth0
AUTH0_DOMAIN=dev-abc123.us.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret

# Delegation Key (base64 encoded)
DELEGATION_KEY=$(openssl rand -base64 32)
```

### Step 2: Deploy Infrastructure (15 minutes)

```bash
make deploy
```

This will:
- Create resource group
- Deploy APIM instance (takes ~10-15 min)
- Create ACR
- Create App Service Plan and Web App
- Configure role assignments

Expected output:
```
✅ Deployment complete
```

Take note of the outputs:
- Resource Group Name
- APIM Name
- Web App Name

### Step 3: Build and Push Image (2 minutes)

```bash
# Build Docker image
make buildimage

# Push to ACR
make pushimage
```

### Step 4: Update Auth0 Callbacks (1 minute)

Add production URLs to Auth0:

1. Go to Auth0 Dashboard → Applications → Your App → Settings
2. **Allowed Callback URLs** (add):
   ```
   https://webapp-<your-suffix>.azurewebsites.net/callback
   https://<your-apim-name>.developer.azure-api.net/callback
   ```
3. **Allowed Logout URLs** (add):
   ```
   https://webapp-<your-suffix>.azurewebsites.net
   https://<your-apim-name>.developer.azure-api.net
   ```
4. Click **Save Changes**

### Step 5: Configure APIM Delegation (2 minutes)

1. Go to Azure Portal
2. Navigate to your APIM instance
3. Go to **Developer Portal** → **Portal overview** → **Delegation**
4. Verify delegation is enabled
5. Delegation URL should be:
   ```
   https://webapp-<your-suffix>.azurewebsites.net/delegation
   ```

### Step 6: Publish Developer Portal (2 minutes)

1. In APIM, go to **Developer portal** → **Portal overview**
2. Click **Publish** button
3. Wait for publishing to complete
4. Click **Portal URL** to open developer portal

### Step 7: Test End-to-End (5 minutes)

1. Open APIM Developer Portal
2. Click **Sign In**
3. Should redirect to Auth0
4. Sign up or sign in with Auth0
5. Should redirect back to APIM Portal (authenticated)
6. Verify you can access your profile

🎉 **Success!** You now have a working identity delegation system.

## Common Commands

### Local Development

```bash
# Run locally
cd src/identityApp
go run main.go

# Run with hot reload (install air first: go install github.com/cosmtrek/air@latest)
air

# Run tests
go test ./...

# Format code
go fmt ./...

# Lint code
golangci-lint run
```

### Docker

```bash
# Build image locally
docker build -t identity-app:latest -f src/identityApp/Dockerfile .

# Run container locally
docker run -p 3000:3000 --env-file src/identityApp/.env identity-app:latest

# Check logs
docker logs <container-id>
```

### Azure Deployment

```bash
# Deploy all
make all

# Deploy infrastructure only
make deploy

# Build Docker image
make buildimage

# Push to ACR
make pushimage

# Run image locally
make runimage
```

### Azure CLI Commands

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-id"

# View resource group
az group show --name rg-apim-sample-<suffix>

# View APIM instance
az apim show --name apim-sample-<suffix> --resource-group rg-apim-sample-<suffix>

# View Web App
az webapp show --name webapp-<suffix> --resource-group rg-apim-sample-<suffix>

# View Web App logs
az webapp log tail --name webapp-<suffix> --resource-group rg-apim-sample-<suffix>

# Restart Web App
az webapp restart --name webapp-<suffix> --resource-group rg-apim-sample-<suffix>
```

## Environment Variables Reference

### Required for Local Development

| Variable | Description | Example |
|----------|-------------|---------|
| `AUTH0_DOMAIN` | Auth0 tenant domain | `dev-abc123.us.auth0.com` |
| `AUTH0_CLIENT_ID` | Auth0 application client ID | `abc123def456` |
| `AUTH0_CLIENT_SECRET` | Auth0 application secret | `secret123` |
| `AUTH0_CALLBACK_URL` | OAuth callback URL | `http://localhost:3000/callback` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789abc` |
| `APIM_NAME` | APIM instance name | `apim-sample-dev` |
| `APIM_RESOURCE_GROUP` | Resource group name | `rg-apim-sample-dev` |
| `DEVELOPER_PORTAL_URL` | APIM developer portal URL | `https://apim-sample.developer.azure-api.net/` |
| `DELEGATION_KEY` | Base64 encoded key for HMAC | `base64encodedkey==` |

### Required for Deployment (Additional)

| Variable | Description | Example |
|----------|-------------|---------|
| `SUFFIX` | Unique suffix for resources | `dev123` |
| `ACR_NAME` | Container registry name (globally unique) | `acrapimdev123` |
| `ACR_REPO_NAME` | Repository name in ACR | `identity` |
| `IMAGE_TAG` | Docker image tag | `latest` |
| `PUB_EMAIL` | Publisher email for APIM | `admin@example.com` |
| `PUB_NAME` | Publisher name for APIM | `Admin User` |
| `PERSONAL_SUB_ID` | Same as AZURE_SUBSCRIPTION_ID | `12345678-...` |

## Troubleshooting Quick Fixes

### Issue: "No .env file found"
**Solution**: Create `.env` file in `src/identityApp/` directory

### Issue: "Failed to initialize authenticator"
**Solution**: Check Auth0 credentials in `.env` file

### Issue: "403 Forbidden" when creating users
**Solution**: 
```bash
# Verify role assignment
az role assignment list --assignee <webapp-identity-id>

# If missing, run make deploy again
make deploy
```

### Issue: "Invalid state parameter"
**Solution**: Clear browser cookies and try again

### Issue: "Failed to pull image from ACR"
**Solution**: 
```bash
# Push image again
make pushimage

# Restart web app
az webapp restart --name webapp-<suffix> --resource-group rg-apim-sample-<suffix>
```

### Issue: App not starting in Azure
**Solution**:
```bash
# Check logs
az webapp log tail --name webapp-<suffix> --resource-group rg-apim-sample-<suffix>

# Enable logging if not enabled
az webapp log config --name webapp-<suffix> --resource-group rg-apim-sample-<suffix> \
  --application-logging filesystem --level information
```

## Next Steps

After successful setup:

1. **Read the full documentation**
   - [Technical Solutions Documentation](./TECHNICAL_SOLUTIONS.md)
   - [Architecture Overview](./ARCHITECTURE_OVERVIEW.md)

2. **Customize the application**
   - Modify HTML templates in `src/identityApp/web/template/`
   - Add custom styling in `src/identityApp/web/static/`
   - Extend functionality in handlers

3. **Enhance security**
   - Implement Azure Key Vault for secrets
   - Add rate limiting
   - Enable Application Insights

4. **Set up CI/CD**
   - GitHub Actions
   - Azure DevOps
   - Automated testing

5. **Monitor and maintain**
   - Set up alerts
   - Review logs regularly
   - Keep dependencies updated

## Getting Help

- **Documentation**: Check [TECHNICAL_SOLUTIONS.md](./TECHNICAL_SOLUTIONS.md)
- **Issues**: Open an issue on GitHub
- **Logs**: Check Azure App Service logs
- **Community**: Ask on Stack Overflow with tags `azure-api-management`, `auth0`, `go`

## Clean Up Resources

To avoid Azure charges, delete resources when done testing:

```bash
# Delete resource group (deletes all resources)
az group delete --name rg-apim-sample-<suffix> --yes --no-wait
```

⚠️ **Warning**: This will permanently delete all resources in the group!

## Quick Reference Card

```
┌──────────────────────────────────────────────────────┐
│ APIM Identity Delegation - Quick Reference           │
├──────────────────────────────────────────────────────┤
│ Local Development:                                    │
│   cd src/identityApp && go run main.go              │
│                                                       │
│ Deploy Everything:                                    │
│   make all                                           │
│                                                       │
│ Deploy Infrastructure Only:                          │
│   make deploy                                        │
│                                                       │
│ Build & Push Docker Image:                           │
│   make buildimage && make pushimage                  │
│                                                       │
│ View Logs:                                           │
│   az webapp log tail --name webapp-<suffix> ...     │
│                                                       │
│ Restart App:                                         │
│   az webapp restart --name webapp-<suffix> ...      │
│                                                       │
│ Delete Resources:                                    │
│   az group delete --name rg-apim-sample-<suffix>    │
└──────────────────────────────────────────────────────┘
```

## Architecture at a Glance

```
User → APIM Portal → Identity App → Auth0
                           ↓
                      APIM Service
                           ↓
                   User Created/Verified
                           ↓
                      SSO Token
                           ↓
                    APIM Portal (Authenticated)
```

That's it! You're ready to work with APIM Identity Delegation.
