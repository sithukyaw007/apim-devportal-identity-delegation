# Technical Solutions Documentation

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Technology Stack](#technology-stack)
3. [Component Architecture](#component-architecture)
4. [Authentication Flow](#authentication-flow)
5. [Infrastructure Architecture](#infrastructure-architecture)
6. [Application Components](#application-components)
7. [API Endpoints](#api-endpoints)
8. [Deployment Architecture](#deployment-architecture)
9. [Security Implementation](#security-implementation)
10. [Development Guide](#development-guide)
11. [Troubleshooting](#troubleshooting)

## System Architecture Overview

This solution implements identity delegation for Azure API Management (APIM) Developer Portal using Auth0 as the identity provider. It enables users to sign up and sign in to the APIM Developer Portal using Auth0 credentials through a custom web application acting as an authentication proxy.

### High-Level Architecture

```
┌─────────────┐          ┌──────────────┐          ┌─────────────┐
│             │          │              │          │             │
│   APIM      │◄────────►│  Web App     │◄────────►│   Auth0     │
│  Developer  │          │  (Identity   │          │  (Identity  │
│   Portal    │          │   Proxy)     │          │  Provider)  │
│             │          │              │          │             │
└─────────────┘          └──────────────┘          └─────────────┘
      │                         │                         
      │                         │                         
      ▼                         ▼                         
┌─────────────┐          ┌──────────────┐                
│   Azure     │          │    Azure     │                
│   APIM      │          │  Container   │                
│  Service    │          │  Registry    │                
└─────────────┘          └──────────────┘                
```

### Key Components

1. **Auth0**: External identity provider for user authentication
2. **Azure API Management (APIM)**: API gateway with developer portal
3. **Identity Web Application**: Go-based proxy application handling delegation
4. **Azure Container Registry**: Stores Docker images for the web app
5. **Azure App Service**: Hosts the identity web application

## Technology Stack

### Backend
- **Language**: Go 1.19
- **Web Framework**: Gin (v1.9.1)
- **Authentication**: 
  - go-oidc v3.5.0 (OpenID Connect)
  - oauth2 v0.7.0
- **Azure SDK**: 
  - azidentity v1.3.0
  - azcore v1.6.0

### Infrastructure
- **IaC Tool**: Azure Bicep
- **Container**: Docker
- **Cloud Platform**: Microsoft Azure
  - Azure API Management
  - Azure App Service (Linux containers)
  - Azure Container Registry

### Key Dependencies
- `github.com/gin-contrib/sessions`: Session management
- `github.com/joho/godotenv`: Environment variable management
- `github.com/tidwall/gjson`: JSON parsing
- `github.com/Azure/azure-sdk-for-go`: Azure service integration

## Component Architecture

### 1. Auth0 Integration

**Purpose**: Provides OAuth 2.0/OIDC authentication for users.

**Configuration**:
- Application Type: Regular Web Application
- Grant Type: Authorization Code Flow
- Scopes: `openid`, `profile`

**Key Files**:
- `src/identityApp/platform/authenticator/auth.go`

**Responsibilities**:
- User authentication via OAuth 2.0
- Token verification
- User profile management

### 2. Azure API Management (APIM)

**Purpose**: API gateway with developer portal requiring identity delegation.

**Configuration**:
- SKU: Developer (1 capacity unit)
- Identity Delegation: Enabled for user registration
- Delegation URL: Points to identity web app `/delegation` endpoint

**Key Features**:
- Developer portal for API consumption
- User management
- Subscription management
- Token-based SSO

### 3. Identity Web Application

**Purpose**: Acts as an authentication proxy between Auth0 and APIM.

**Architecture**:
```
┌────────────────────────────────────────────────────┐
│          Identity Web Application                  │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │   Router     │  │ Authenticator│  │  Azure   │ │
│  │              │  │              │  │  Client  │ │
│  │  - /         │  │  - OAuth2    │  │  - APIM  │ │
│  │  - /delegate │  │  - OIDC      │  │  - Auth  │ │
│  │  - /callback │  │  - Verify    │  │  - User  │ │
│  │  - /logout   │  │              │  │   Mgmt   │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐               │
│  │  Middleware  │  │   Session    │               │
│  │              │  │   Store      │               │
│  │  - Auth      │  │  - Cookie    │               │
│  │    Check     │  │    Based     │               │
│  └──────────────┘  └──────────────┘               │
└────────────────────────────────────────────────────┘
```

**Key Responsibilities**:
- Handle delegation requests from APIM
- Redirect to Auth0 for authentication
- Process OAuth callbacks
- Create/verify users in APIM
- Generate and return SSO tokens

## Authentication Flow

### Sign-Up Flow

```
User                APIM Portal        Web App          Auth0           Azure APIM Service
 │                      │                 │               │                    │
 │  1. Click SignUp     │                 │               │                    │
 ├─────────────────────►│                 │               │                    │
 │                      │  2. Delegate    │               │                    │
 │                      ├────────────────►│               │                    │
 │                      │  /delegation    │               │                    │
 │                      │  ?operation=    │               │                    │
 │                      │   SignUp        │               │                    │
 │                      │                 │               │                    │
 │                      │  3. Verify HMAC │               │                    │
 │                      │     Signature   │               │                    │
 │                      │                 │               │                    │
 │                      │  4. Redirect to Auth0           │                    │
 │                      │                 ├──────────────►│                    │
 │                      │                 │  OAuth2 Flow  │                    │
 │  5. Auth0 Login UI   │                 │               │                    │
 │◄─────────────────────┴─────────────────┴───────────────┤                    │
 │                                                         │                    │
 │  6. Enter Credentials & Sign Up                         │                    │
 ├────────────────────────────────────────────────────────►│                    │
 │                                                         │                    │
 │  7. Callback with code                                  │                    │
 │◄────────────────────────────────────────────────────────┤                    │
 │                      │                 │               │                    │
 │                      │  8. Exchange code for token      │                    │
 │                      │                 ├──────────────►│                    │
 │                      │                 │               │                    │
 │                      │  9. ID Token + Access Token      │                    │
 │                      │                 ◄───────────────┤                    │
 │                      │                 │               │                    │
 │                      │  10. Get Azure Token (Managed Identity)               │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │                      │  11. Check if user exists in APIM                     │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │                      │  12. Create user in APIM                              │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │                      │  13. Get Shared Access Token                          │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │  14. Redirect to APIM Portal with SSO token            │                    │
 │◄─────────────────────┴─────────────────┤               │                    │
 │                                                                              │
 │  15. Access APIM Portal (Authenticated)                                      │
 ├─────────────────────────────────────────────────────────────────────────────►│
```

### Sign-In Flow

```
User                APIM Portal        Web App          Auth0           Azure APIM Service
 │                      │                 │               │                    │
 │  1. Click SignIn     │                 │               │                    │
 ├─────────────────────►│                 │               │                    │
 │                      │  2. Delegate    │               │                    │
 │                      ├────────────────►│               │                    │
 │                      │  /delegation    │               │                    │
 │                      │  ?operation=    │               │                    │
 │                      │   SignIn        │               │                    │
 │                      │                 │               │                    │
 │                      │  3. Redirect to Auth0           │                    │
 │                      │                 ├──────────────►│                    │
 │                      │                 │               │                    │
 │  4. Auth0 Login      │                 │               │                    │
 │◄─────────────────────┴─────────────────┴───────────────┤                    │
 │                                                         │                    │
 │  5. Enter Credentials                                   │                    │
 ├────────────────────────────────────────────────────────►│                    │
 │                                                         │                    │
 │  6. Callback                                            │                    │
 │◄────────────────────────────────────────────────────────┤                    │
 │                      │                 │               │                    │
 │                      │  7. Check if user exists in APIM                      │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │                      │  8. Create user if not exists                         │
 │                      │                 ├───────────────────────────────────►│
 │                      │                 │               │                    │
 │  9. Redirect with SSO token                            │                    │
 │◄─────────────────────┴─────────────────┤               │                    │
```

### Delegation Request Verification

The web app verifies that delegation requests originate from APIM using HMAC-SHA512 signature:

```go
func verifyRequestFromAPIM(salt, returnUrl, sig, delegation_key string) bool {
    // Decode the delegation key
    key, _ := base64.StdEncoding.DecodeString(delegation_key)
    
    // Create HMAC with SHA512
    res := hmac.New(sha512.New, key)
    
    // Decode URL parameters
    salt, _ = url.PathUnescape(salt)
    sig, _ = url.PathUnescape(sig)
    rurl, _ := url.PathUnescape(returnUrl)
    
    // Compute signature: salt + "\n" + returnUrl
    salt_url := salt + "\n" + rurl
    res.Write([]byte(salt_url))
    sum := res.Sum(nil)
    computed_sig := base64.StdEncoding.EncodeToString(sum)
    
    // Verify
    return computed_sig == sig
}
```

## Infrastructure Architecture

### Bicep Module Structure

```
infra/
├── main.bicep                          # Main orchestration
└── modules/
    ├── acr.bicep                       # Container Registry
    ├── acr-role-assignment.bicep       # ACR pull permissions
    ├── apim.bicep                      # API Management service
    ├── apim-role-assignment.bicep      # APIM contributor role
    ├── webapp.bicep                    # App Service & Plan
    └── webapp-settings.bicep           # App configuration
```

### Resource Dependencies

```
Resource Group
    │
    ├─► Azure Container Registry (ACR)
    │       │
    │       └─► Role Assignment: ACRPull
    │               └─► Principal: Web App Managed Identity
    │
    ├─► API Management Service
    │       │
    │       ├─► Portal Settings (Delegation)
    │       └─► Role Assignment: Contributor
    │               └─► Principal: Web App Managed Identity
    │
    └─► App Service Plan (Linux)
            │
            └─► Web App
                    ├─► System Assigned Managed Identity
                    ├─► Container: ACR image
                    └─► App Settings (Environment Variables)
```

### Key Azure Resources

#### 1. Azure Container Registry (ACR)
```bicep
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
```

**Purpose**: Store Docker images for the identity web application.

#### 2. API Management Service
```bicep
resource apiManagementInstance 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: name
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  properties: {
    virtualNetworkType: 'None'
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}
```

**Delegation Settings**:
```bicep
resource apiManagementIdentityDelegation 'Microsoft.ApiManagement/service/portalsettings@2022-08-01' = {
  parent: apiManagementInstance
  name: 'delegation'
  properties: {
    subscriptions: {
      enabled: false
    }
    url: '${identityWebAppUrl}/delegation'
    userRegistration: {
      enabled: true
    }
    validationKey: delegationKey
  }
}
```

#### 3. App Service Plan & Web App
```bicep
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: 'asp-${suffix}'
  location: location
  kind: 'app,linux,container'
  sku: {
    name: 'P1v3'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource webApplication 'Microsoft.Web/sites@2022-03-01' = {
  name: 'webapp-${suffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrName}.azurecr.io/${acrRepoName}:${imageTag}'
      alwaysOn: true
    }
  }
}
```

### Role Assignments

#### ACR Pull Role
Allows the Web App to pull Docker images from ACR:
```bicep
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, principalId, roleId)
  scope: containerRegistry
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalType: 'ServicePrincipal'
  }
}
```

#### APIM Contributor Role
Allows the Web App to manage APIM users:
```bicep
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, principalId, roleId)
  scope: apimService
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalType: 'ServicePrincipal'
  }
}
```

## Application Components

### 1. Main Application (`main.go`)

**Entry Point**: Initializes the application and starts the HTTP server.

```go
func main() {
    // Load environment variables
    if err := godotenv.Load(); err != nil {
        fmt.Println("No .env file found")
    }
    
    // Initialize Auth0 authenticator
    auth, err := authenticator.New()
    
    // Create router with all routes
    rtr := router.New(auth)
    
    // Start server on port 3000
    http.ListenAndServe("0.0.0.0:3000", rtr)
}
```

### 2. Router (`platform/router/router.go`)

**Purpose**: Configures HTTP routes and middleware.

**Routes**:
- `GET /` - Home page
- `GET /delegation` - APIM delegation endpoint
- `GET /callback` - OAuth callback from Auth0
- `GET /logout` - User logout

**Middleware**:
- Session management (cookie-based)
- Static file serving

### 3. Authenticator (`platform/authenticator/auth.go`)

**Purpose**: Manages Auth0 authentication.

**Key Methods**:
- `New()`: Creates authenticator with OIDC provider
- `VerifyIDToken()`: Validates ID tokens from Auth0

**Configuration**:
```go
type Authenticator struct {
    *oidc.Provider
    oauth2.Config
}

func New() (*Authenticator, error) {
    provider, err := oidc.NewProvider(
        context.Background(),
        "https://"+os.Getenv("AUTH0_DOMAIN")+"/",
    )
    
    conf := oauth2.Config{
        ClientID:     os.Getenv("AUTH0_CLIENT_ID"),
        ClientSecret: os.Getenv("AUTH0_CLIENT_SECRET"),
        RedirectURL:  os.Getenv("AUTH0_CALLBACK_URL"),
        Endpoint:     provider.Endpoint(),
        Scopes:       []string{oidc.ScopeOpenID, "profile"},
    }
    
    return &Authenticator{
        Provider: provider,
        Config:   conf,
    }, nil
}
```

### 4. Azure Client (`platform/azureClient/azure.go`)

**Purpose**: Interacts with Azure services (APIM, Azure AD).

**Key Functions**:

#### Get Azure Token
```go
func GetTokenViaGoSDK(ctx *gin.Context) (string, error) {
    // Uses DefaultAzureCredential chain:
    // 1. EnvironmentCredential
    // 2. WorkloadIdentityCredential
    // 3. ManagedIdentityCredential (used in production)
    // 4. AzureCLICredential
    
    cred, err := azidentity.NewDefaultAzureCredential(nil)
    token, err := cred.GetToken(ctx, policy.TokenRequestOptions{
        Scopes: []string{"https://management.azure.com/.default"},
    })
    
    return token.Token, nil
}
```

#### Create User in APIM
```go
func CreateUserInAPIM(username, uid, accessToken string) error {
    // Construct payload
    payload := createUserRequest{
        Properties: createUserProperties{
            Email:     username,
            FirstName: strings.Split(username, "@")[0],
            LastName:  strings.Split(username, "@")[0],
        },
    }
    
    // PUT request to APIM REST API
    apiEndpoint := fmt.Sprintf(
        "https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.ApiManagement/service/%s/users/%s?api-version=2022-08-01",
        subscriptionId, rg, apimName, userId
    )
    
    // Execute request with Bearer token
    req.Header.Add("Authorization", "Bearer "+accessToken)
    req.Header.Set("Content-Type", "application/json")
    
    return nil
}
```

#### Get Shared Access Token
```go
func GetSharedAccessTokenFromAPIM(accessToken, uid string) (string, error) {
    // Token expires 12 hours from now
    expiryTime := getTimeAfterHours(12)
    
    requestBody := fmt.Sprintf(
        `{"properties": {"keyType": "primary", "expiry": "%s"}}`,
        expiryTime
    )
    
    // POST to APIM token endpoint
    apiEndpoint := fmt.Sprintf(
        "https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.ApiManagement/service/%s/users/%s/token?api-version=2022-08-01",
        subscriptionId, rg, apimName, userId
    )
    
    return sharedAccessToken, nil
}
```

#### Check User Existence
```go
func UserExistInApim(uid, accessToken string) (bool, error) {
    // GET request to check if user exists
    url := fmt.Sprintf(
        "https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.ApiManagement/service/%s/users/%s?api-version=2021-04-01",
        subscriptionId, rg, apimName, userId
    )
    
    // Returns true if HTTP 200, false otherwise
    return resp.StatusCode == http.StatusOK, nil
}
```

### 5. Delegation Handler (`web/app/delegation/delegation.go`)

**Purpose**: Processes delegation requests from APIM.

**Flow**:
1. Extract query parameters: `operation`, `returnUrl`, `salt`, `sig`
2. Verify HMAC signature to ensure request is from APIM
3. Handle `SignOut` operation immediately
4. For `SignIn`/`SignUp`:
   - Generate random state for CSRF protection
   - Store state and operation in session
   - Redirect to Auth0

**Query Parameters**:
- `operation`: SignUp | SignIn | SignOut
- `returnUrl`: URL to return to after authentication
- `salt`: Random value for signature
- `sig`: HMAC-SHA512 signature

### 6. Callback Handler (`web/app/callback/callback.go`)

**Purpose**: Processes OAuth callback from Auth0.

**Flow**:
1. Validate state parameter (CSRF protection)
2. Exchange authorization code for tokens
3. Verify ID token
4. Extract user profile (sub, name)
5. Get Azure management token via Managed Identity
6. Check if user exists in APIM
7. Create user in APIM if not exists
8. Get shared access token from APIM
9. Redirect to APIM portal with SSO token

**User ID Mapping**:
```go
// Auth0 sub format: "auth0|123456789"
parts := strings.Split(profile["sub"].(string), "|")
uid := parts[1]  // Use "123456789" as APIM user ID
```

**SSO Redirect**:
```go
url := fmt.Sprintf(
    "%ssignin-sso?token=%s&returnUrl=%s",
    developerPortalUrl,
    url.QueryEscape(sharedAccessToken),
    url.QueryEscape("/")
)
```

## API Endpoints

### 1. GET /delegation

**Purpose**: Entry point for APIM delegation.

**Query Parameters**:
- `operation` (required): SignIn | SignUp | SignOut
- `returnUrl` (required): URL to redirect after auth
- `salt` (required): Random value for HMAC
- `sig` (required): HMAC-SHA512 signature

**Response**: 
- 302 Redirect to Auth0 (for SignIn/SignUp)
- 302 Redirect to logout (for SignOut)
- 500 Error if signature invalid

**Example**:
```
GET /delegation?operation=SignIn&returnUrl=https%3A%2F%2Fapim.developer.azure-api.net%2F&salt=abc123&sig=xyz789
```

### 2. GET /callback

**Purpose**: OAuth 2.0 callback from Auth0.

**Query Parameters**:
- `code` (required): Authorization code
- `state` (required): CSRF token

**Response**:
- 302 Redirect to APIM portal with SSO token
- 400 Invalid state
- 401 Failed to exchange code
- 500 Server error

**Example**:
```
GET /callback?code=AUTH_CODE&state=RANDOM_STATE
```

### 3. GET /logout

**Purpose**: Logout user from session.

**Response**:
- 302 Redirect to home page
- Session cleared

### 4. GET /

**Purpose**: Home page.

**Response**:
- HTML page with app status

## Deployment Architecture

### Build & Deployment Pipeline

```
┌─────────────────┐
│  1. Local Dev   │
│  - Edit .env    │
│  - Run locally  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. Build Image │
│  make buildimage│
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. Push to ACR │
│  make pushimage │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. Deploy Infra│
│  make deploy    │
│  (Bicep)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  5. App Service │
│  pulls image    │
│  from ACR       │
└─────────────────┘
```

### Deployment Steps

1. **Environment Configuration**
   ```bash
   # Copy and edit .env file
   cp .env.sample .env
   # Set all required variables
   ```

2. **Deploy Azure Infrastructure**
   ```bash
   make deploy
   ```
   This executes `deploy.sh` which runs:
   ```bash
   az deployment sub create \
       --template-file ./infra/main.bicep \
       -l westeurope \
       --parameters ...
   ```

3. **Build Docker Image**
   ```bash
   make buildimage
   ```
   Builds image:
   ```
   ${ACR_NAME}.azurecr.io/${ACR_REPO_NAME}:${IMAGE_TAG}
   ```

4. **Push to ACR**
   ```bash
   make pushimage
   ```
   Authenticates with ACR and pushes image.

5. **App Service Auto-Deploy**
   - App Service detects new image
   - Pulls from ACR using Managed Identity
   - Restarts with new image

### Dockerfile

```dockerfile
# Multi-stage build
FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY src/identityApp/ .
RUN go mod download
RUN go build -o main .

FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/main .
COPY --from=builder /app/web ./web
EXPOSE 3000
CMD ["./main"]
```

### Environment Variables

#### Required for Local Development
```bash
# Auth0 Configuration
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
AUTH0_CALLBACK_URL=http://localhost:3000/callback

# Azure Configuration
AZURE_SUBSCRIPTION_ID=your_subscription_id
APIM_NAME=your_apim_name
APIM_RESOURCE_GROUP=your_rg_name
DEVELOPER_PORTAL_URL=https://your-apim.developer.azure-api.net/

# Delegation
DELEGATION_KEY=base64_encoded_key

# Deployment (for make commands)
SUFFIX=unique_suffix
ACR_NAME=globally_unique_acr_name
ACR_REPO_NAME=identity
IMAGE_TAG=latest
PUB_EMAIL=your@email.com
PUB_NAME=Your Name
```

#### Automatically Set by Bicep (Production)
- All Auth0 variables
- All Azure configuration
- DELEGATION_KEY

## Security Implementation

### 1. Authentication & Authorization

#### OAuth 2.0 Flow
- **Grant Type**: Authorization Code
- **PKCE**: Not explicitly implemented (could be added)
- **State Parameter**: Used for CSRF protection
- **Scopes**: `openid`, `profile`

#### Token Management
- **ID Token**: Verified using OIDC
- **Access Token**: Stored in session (cookie)
- **Azure Token**: Short-lived, obtained via Managed Identity
- **APIM Shared Access Token**: 12-hour expiry

### 2. HMAC Signature Verification

Prevents unauthorized delegation requests:

```go
func verifyRequestFromAPIM(salt, returnUrl, sig, delegation_key string) bool {
    key, _ := base64.StdEncoding.DecodeString(delegation_key)
    res := hmac.New(sha512.New, key)
    salt_url := salt + "\n" + returnUrl
    res.Write([]byte(salt_url))
    computed_sig := base64.StdEncoding.EncodeToString(res.Sum(nil))
    return computed_sig == sig
}
```

**Algorithm**: HMAC-SHA512  
**Message**: `salt + "\n" + returnUrl`  
**Key**: Base64-decoded delegation key

### 3. Managed Identity

Web App uses System-Assigned Managed Identity for:
- Pulling images from ACR (ACRPull role)
- Managing APIM users (Contributor role)
- Obtaining Azure management tokens

**Benefits**:
- No credential management
- Automatic token rotation
- Azure AD integration

**DefaultAzureCredential Chain**:
1. Environment variables
2. Workload Identity
3. **Managed Identity** ← Used in production
4. Azure CLI

### 4. Session Security

```go
store := cookie.NewStore([]byte("secret"))
router.Use(sessions.Sessions("auth-session", store))
```

**Improvements Recommended**:
- Use secure random secret (not "secret")
- Set HttpOnly, Secure, SameSite flags
- Implement session timeout
- Add session ID rotation

### 5. HTTPS Enforcement

- All production endpoints use HTTPS
- Auth0 callbacks require HTTPS
- APIM portal requires HTTPS

### 6. Secret Management

**Current Approach**:
- Environment variables via App Service settings
- Delegation key in Bicep parameters (secure string)

**Best Practices Applied**:
- Secrets not in source code
- `.env` in `.gitignore`
- Bicep `@secure()` decorator

**Recommended Enhancements**:
- Azure Key Vault integration
- Managed Identity for Key Vault access
- Secret rotation policies

### 7. CORS & CSP

**Current Status**: Not explicitly configured

**Recommendations**:
- Set CORS policy in Gin
- Implement Content Security Policy headers
- Validate Origin header

## Development Guide

### Local Development Setup

1. **Prerequisites**
   ```bash
   # Install Go 1.19+
   brew install go
   
   # Install Docker
   brew install docker
   
   # Install Azure CLI
   brew install azure-cli
   ```

2. **Clone Repository**
   ```bash
   git clone https://github.com/sithukyaw007/apim-devportal-identity-delegation.git
   cd apim-devportal-identity-delegation
   ```

3. **Configure Auth0**
   - Create Auth0 application
   - Configure callback URLs:
     - `http://localhost:3000/callback`
     - `https://your-webapp.azurewebsites.net/callback`
     - `https://your-apim.developer.azure-api.net/callback`
   - Copy credentials

4. **Set Environment Variables**
   ```bash
   cd src/identityApp
   cp ../../.env.sample .env
   # Edit .env with your values
   ```

5. **Install Dependencies**
   ```bash
   go mod vendor
   ```

6. **Run Locally**
   ```bash
   go run main.go
   ```
   
   Application starts on http://localhost:3000/

7. **Deploy Azure Resources** (one-time)
   ```bash
   # From repository root
   make deploy
   ```

8. **Build & Deploy Application**
   ```bash
   make buildimage
   make pushimage
   ```

### Project Structure

```
.
├── .env.sample              # Environment variable template
├── .gitignore
├── LICENSE
├── Makefile                 # Build automation
├── ReadMe.md               # User documentation
├── deploy.sh               # Deployment script
├── infra/                  # Infrastructure as Code
│   ├── main.bicep          # Main Bicep file
│   ├── modules/            # Bicep modules
│   │   ├── acr.bicep
│   │   ├── acr-role-assignment.bicep
│   │   ├── apim.bicep
│   │   ├── apim-role-assignment.bicep
│   │   ├── webapp.bicep
│   │   └── webapp-settings.bicep
│   └── scripts/            # Helper scripts
└── src/
    ├── identityApp/        # Go application
    │   ├── .dockerignore
    │   ├── .gitignore
    │   ├── Dockerfile
    │   ├── go.mod          # Go dependencies
    │   ├── go.sum
    │   ├── main.go         # Entry point
    │   ├── platform/       # Core logic
    │   │   ├── authenticator/
    │   │   │   └── auth.go
    │   │   ├── azureClient/
    │   │   │   └── azure.go
    │   │   ├── middleware/
    │   │   │   └── isAuthenticated.go
    │   │   └── router/
    │   │       └── router.go
    │   └── web/            # Web layer
    │       ├── app/
    │       │   ├── callback/
    │       │   ├── delegation/
    │       │   ├── home/
    │       │   └── logout/
    │       ├── static/     # CSS, JS, images
    │       └── template/   # HTML templates
    └── images/             # Documentation images
```

### Testing Locally

1. **Start Application**
   ```bash
   cd src/identityApp
   go run main.go
   ```

2. **Access Home Page**
   ```
   http://localhost:3000/
   ```

3. **Test Delegation Flow**
   
   Manually construct delegation URL:
   ```
   http://localhost:3000/delegation?operation=SignIn&returnUrl=http://localhost:3000/&salt=test&sig=computed_sig
   ```
   
   Note: You need to compute valid HMAC signature or disable verification for testing.

4. **Test Auth0 Integration**
   - Click through to Auth0
   - Login/Signup
   - Verify callback handling
   - Check console logs for errors

### Debugging

#### Enable Verbose Logging

In `main.go`:
```go
gin.SetMode(gin.DebugMode)
```

In Azure App Service:
1. Go to App Service → Monitoring → App Service Logs
2. Enable Application Logging
3. View logs in Log Stream

#### Common Debug Points

```go
// In callback.go
fmt.Println("profile: ", profile)
fmt.Println("developerPortalUrl: ", developerPortalUrl)

// In azureClient.go
fmt.Println("User exists:", userExistInApim)
fmt.Println("Creating user:", username)
```

## Troubleshooting

### Common Issues

#### 1. 403 Forbidden from APIM API

**Symptom**: Error when creating users or getting tokens

**Cause**: Web App lacks Contributor role on APIM

**Solution**:
```bash
# Verify role assignment
az role assignment list \
    --assignee <webapp-managed-identity-id> \
    --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ApiManagement/service/<apim-name>

# Reassign if missing
az role assignment create \
    --assignee <webapp-managed-identity-id> \
    --role "API Management Service Contributor" \
    --scope <apim-resource-id>
```

#### 2. Invalid State Parameter

**Symptom**: "Invalid state parameter" error on callback

**Cause**: Session not persisting between requests

**Solutions**:
- Check cookie settings
- Ensure session secret is consistent
- Verify browser allows cookies
- Check session timeout

#### 3. Failed to Pull Image from ACR

**Symptom**: App Service can't pull Docker image

**Cause**: Missing ACRPull role assignment

**Solution**:
```bash
# Check role assignment
az role assignment list \
    --assignee <webapp-managed-identity-id> \
    --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>

# Reassign if needed
az role assignment create \
    --assignee <webapp-managed-identity-id> \
    --role "AcrPull" \
    --scope <acr-resource-id>
```

#### 4. SharedAccessToken is Empty

**Symptom**: Redirect fails with empty token error

**Causes**:
- User ID format mismatch
- APIM API version incompatibility
- Invalid expiry time format

**Debug**:
```go
// Check user ID
fmt.Println("User ID:", uid)

// Check API response
body, _ := ioutil.ReadAll(resp.Body)
fmt.Println("API Response:", string(body))
```

#### 5. Auth0 Callback URL Mismatch

**Symptom**: Auth0 error about redirect URI

**Solution**:
1. Go to Auth0 Dashboard
2. Applications → Your App → Settings
3. Add to Allowed Callback URLs:
   ```
   http://localhost:3000/callback
   https://your-webapp.azurewebsites.net/callback
   ```

#### 6. HMAC Signature Verification Failed

**Symptom**: "Request is not from APIM" error

**Causes**:
- Delegation key mismatch
- URL encoding issues
- Wrong HMAC algorithm

**Debug**:
```go
fmt.Println("Computed sig:", computed_sig)
fmt.Println("Received sig:", sig)
fmt.Println("Delegation key:", delegation_key)
```

**Solution**:
- Verify delegation key in APIM matches .env
- Ensure key is base64 encoded
- Check URL parameter encoding

### Logging & Monitoring

#### Application Insights (Recommended)

Add to App Service:
```bicep
resource webApplication 'Microsoft.Web/sites@2022-03-01' = {
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
      ]
    }
  }
}
```

#### Custom Logging

Enhance logging in Go:
```go
import "log"

log.Printf("[INFO] User %s authenticated", username)
log.Printf("[ERROR] Failed to create user: %v", err)
log.Printf("[DEBUG] Token expiry: %s", expiryTime)
```

#### Log Levels

Implement structured logging:
```go
import "github.com/sirupsen/logrus"

log := logrus.New()
log.SetLevel(logrus.InfoLevel)

log.WithFields(logrus.Fields{
    "user_id": uid,
    "operation": operation,
}).Info("Processing delegation request")
```

### Health Checks

Add health endpoint:
```go
// In router.go
router.GET("/health", func(c *gin.Context) {
    c.JSON(200, gin.H{
        "status": "healthy",
        "version": "1.0.0",
    })
})
```

Configure in App Service:
```bicep
resource webApplication 'Microsoft.Web/sites@2022-03-01' = {
  properties: {
    siteConfig: {
      healthCheckPath: '/health'
    }
  }
}
```

## Best Practices & Recommendations

### Security Enhancements

1. **Use Azure Key Vault**
   ```bicep
   // Store secrets in Key Vault
   resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
     properties: {
       enabledForDeployment: true
       sku: { family: 'A', name: 'standard' }
     }
   }
   
   // Reference in App Settings
   {
     name: 'AUTH0_CLIENT_SECRET'
     value: '@Microsoft.KeyVault(SecretUri=${keyVault.properties.vaultUri}secrets/auth0-client-secret/)'
   }
   ```

2. **Implement Rate Limiting**
   ```go
   import "github.com/ulule/limiter/v3"
   
   // Limit delegation requests
   rate := limiter.Rate{
       Period: 1 * time.Hour,
       Limit:  100,
   }
   ```

3. **Add Request Validation**
   ```go
   // Validate returnUrl
   func isValidReturnUrl(returnUrl string) bool {
       allowedDomains := []string{
           "developer.azure-api.net",
           os.Getenv("DEVELOPER_PORTAL_URL"),
       }
       // Check if returnUrl matches allowed domains
   }
   ```

4. **Secure Session Cookie**
   ```go
   store := cookie.NewStore([]byte(os.Getenv("SESSION_SECRET")))
   store.Options(sessions.Options{
       Path:     "/",
       MaxAge:   3600,
       HttpOnly: true,
       Secure:   true,
       SameSite: http.SameSiteLaxMode,
   })
   ```

### Operational Excellence

1. **Add Metrics**
   - Track authentication success/failure rates
   - Monitor APIM API response times
   - Alert on error rate thresholds

2. **Implement Retry Logic**
   ```go
   import "github.com/avast/retry-go"
   
   err := retry.Do(
       func() error {
           return azureClient.CreateUserInAPIM(username, uid, token)
       },
       retry.Attempts(3),
       retry.Delay(time.Second),
   )
   ```

3. **Add Circuit Breaker**
   ```go
   import "github.com/sony/gobreaker"
   
   cb := gobreaker.NewCircuitBreaker(gobreaker.Settings{
       Name: "APIM",
       MaxRequests: 3,
       Timeout: 60 * time.Second,
   })
   ```

### Performance Optimization

1. **Cache User Existence Check**
   ```go
   import "github.com/patrickmn/go-cache"
   
   c := cache.New(5*time.Minute, 10*time.Minute)
   
   // Check cache before API call
   if _, found := c.Get(uid); found {
       // User exists
   }
   ```

2. **Use HTTP Connection Pooling**
   ```go
   var httpClient = &http.Client{
       Timeout: time.Second * 10,
       Transport: &http.Transport{
           MaxIdleConns:        100,
           MaxIdleConnsPerHost: 100,
       },
   }
   ```

### Testing

1. **Unit Tests**
   ```go
   func TestVerifyRequestFromAPIM(t *testing.T) {
       // Test HMAC verification
   }
   
   func TestCreateUserInAPIM(t *testing.T) {
       // Mock APIM API
   }
   ```

2. **Integration Tests**
   ```go
   func TestAuthFlow(t *testing.T) {
       // Test full OAuth flow
   }
   ```

3. **Load Testing**
   ```bash
   # Use k6 or similar
   k6 run load-test.js
   ```

## Conclusion

This solution provides a secure, scalable identity delegation implementation for Azure API Management using Auth0. Key highlights:

- **OAuth 2.0/OIDC** standard compliance
- **Managed Identity** for secure Azure access
- **HMAC signature** verification for request integrity
- **Infrastructure as Code** for reproducible deployments
- **Containerized** application for portability

For questions or issues, refer to the troubleshooting section or open an issue in the repository.
