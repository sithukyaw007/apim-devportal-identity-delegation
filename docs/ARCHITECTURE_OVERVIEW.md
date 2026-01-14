# Architecture Overview

## Quick Reference

This document provides a high-level overview of the APIM Identity Delegation solution architecture.

## System Components

### Core Services
1. **Auth0** - Identity Provider (IdP)
2. **Azure API Management** - API Gateway with Developer Portal
3. **Identity Web Application** - Authentication Proxy (Go/Gin)
4. **Azure Container Registry** - Docker Image Repository
5. **Azure App Service** - Web Application Host

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           User Browser                                   │
└────────────┬────────────────────────────────────────────────────────────┘
             │
             ├─────────────────────────────────────────────────────────┐
             │                                                         │
             ▼                                                         ▼
┌────────────────────────┐                            ┌────────────────────────┐
│   APIM Developer       │                            │     Auth0              │
│   Portal               │                            │   (Identity Provider)  │
│                        │                            │                        │
│  - API Documentation   │                            │  - User Database       │
│  - Subscriptions       │                            │  - OAuth 2.0 / OIDC    │
│  - User Profile        │                            │  - Token Management    │
└────────────┬───────────┘                            └────────────┬───────────┘
             │                                                     │
             │ Delegate Auth                                      │ Auth
             │ (Sign In/Up)                                       │ Request
             │                                                    │
             ▼                                                    │
┌───────────────────────────────────────────────────────────────┐ │
│        Identity Web Application (Go/Gin)                      │ │
│        Running on Azure App Service                           │◄┘
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │   Delegation │  │   Callback   │  │  Azure Client     │  │
│  │   Handler    │  │   Handler    │  │  - APIM API       │  │
│  │              │  │              │  │  - Token Mgmt     │  │
│  └──────────────┘  └──────────────┘  └───────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Managed Identity (System-Assigned)                  │   │
│  │  - ACRPull Role                                      │   │
│  │  - APIM Contributor Role                             │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬────────────────────────────────────────────────┘
             │
             ├──────────────────────┬─────────────────────────┐
             │                      │                         │
             ▼                      ▼                         ▼
┌────────────────────┐  ┌─────────────────────┐  ┌────────────────────┐
│  Azure APIM        │  │ Azure Container     │  │  Azure AD          │
│  Service           │  │ Registry            │  │  (Managed Identity)│
│                    │  │                     │  │                    │
│  - User Mgmt API   │  │  - Docker Images    │  │  - Token Issuance  │
│  - SSO Token API   │  │  - ACRPull Access   │  │  - RBAC            │
└────────────────────┘  └─────────────────────┘  └────────────────────┘
```

## Data Flow

### 1. Sign-Up/Sign-In Flow

```
User → APIM Portal → Identity App → Auth0 → Identity App → APIM Service → APIM Portal
```

**Detailed Steps:**
1. User clicks "Sign In" on APIM Developer Portal
2. APIM redirects to Identity App `/delegation` endpoint with HMAC signature
3. Identity App verifies signature and redirects to Auth0
4. User authenticates with Auth0
5. Auth0 redirects back to Identity App `/callback`
6. Identity App:
   - Gets Azure management token via Managed Identity
   - Creates/verifies user in APIM
   - Requests SSO token from APIM
7. Identity App redirects to APIM Portal with SSO token
8. User is authenticated in APIM Portal

### 2. Delegation Request Verification

```
┌─────────────┐
│ APIM Portal │
└──────┬──────┘
       │ 1. Generate HMAC-SHA512
       │    Message: salt + "\n" + returnUrl
       │    Key: Delegation Key
       │
       ▼
┌──────────────────────────────────────────────┐
│ GET /delegation?operation=SignIn&            │
│    returnUrl=...&salt=...&sig=HMAC_SIG       │
└──────────────────┬───────────────────────────┘
                   │
                   ▼
       ┌───────────────────────┐
       │  Identity Web App     │
       │                       │
       │  1. Decode params     │
       │  2. Compute HMAC      │
       │  3. Compare sigs      │
       │  4. If valid → Auth0  │
       │  5. If invalid → 500  │
       └───────────────────────┘
```

## Security Layers

### Layer 1: Request Verification
- **HMAC-SHA512** signature verification
- Prevents unauthorized delegation requests
- Shared secret between APIM and Web App

### Layer 2: OAuth 2.0 Authentication
- **Authorization Code Flow**
- State parameter for CSRF protection
- ID Token verification via OIDC

### Layer 3: Azure AD Authentication
- **Managed Identity** for Azure resources
- No stored credentials
- RBAC for APIM and ACR access

### Layer 4: Session Security
- **Encrypted cookies** for session storage
- HTTPOnly, Secure, SameSite flags (recommended)
- Session timeout and rotation

### Layer 5: HTTPS Encryption
- All endpoints use TLS 1.2+
- Certificate management by Azure
- End-to-end encryption

## Technology Stack

### Backend Application
```
Language:     Go 1.19
Framework:    Gin Web Framework
Auth:         OAuth 2.0 / OIDC (go-oidc)
Azure SDK:    azidentity, azcore
```

### Infrastructure
```
IaC:          Azure Bicep
Container:    Docker
Registry:     Azure Container Registry
Hosting:      Azure App Service (Linux Containers)
API Gateway:  Azure API Management
```

### Authentication
```
Provider:     Auth0
Protocol:     OAuth 2.0 / OpenID Connect
Grant Type:   Authorization Code Flow
Scopes:       openid, profile
```

## Resource Dependencies

```
subscription
    │
    └─► resource-group
            │
            ├─► acr (Azure Container Registry)
            │     └─► role: AcrPull → webapp managed identity
            │
            ├─► apim (API Management)
            │     ├─► delegation settings → webapp URL
            │     └─► role: Contributor → webapp managed identity
            │
            └─► app-service-plan
                  └─► webapp
                        ├─► system-assigned managed identity
                        ├─► docker image: ACR
                        └─► environment variables
```

## Network Flow

```
Internet
    │
    ├─► Auth0 (auth.domain.com)
    │     └─► OAuth endpoints
    │
    ├─► APIM Portal (apim-name.developer.azure-api.net)
    │     ├─► Developer Portal UI
    │     └─► Delegation to Identity App
    │
    └─► Identity App (webapp-suffix.azurewebsites.net)
          ├─► /delegation
          ├─► /callback
          ├─► /logout
          └─► /
               │
               └─► Azure Management API (management.azure.com)
                     └─► APIM User Management
```

## Deployment Pipeline

```
Developer
    │
    ├─► 1. Edit Code
    │
    ├─► 2. Build Docker Image
    │       docker build -t image:tag
    │
    ├─► 3. Push to ACR
    │       az acr login && docker push
    │
    ├─► 4. Deploy Infrastructure
    │       az deployment sub create --template-file main.bicep
    │
    └─► 5. App Service Auto-Deploy
            - Detects new image
            - Pulls from ACR
            - Restarts application
```

## Key Endpoints

### Identity Web Application

| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| `/` | GET | Home page | No |
| `/delegation` | GET | APIM delegation entry point | HMAC Signature |
| `/callback` | GET | OAuth callback from Auth0 | State Parameter |
| `/logout` | GET | Clear session | No |

### APIM Management API (used by Identity App)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/users/{userId}` | GET | Check user existence |
| `/users/{userId}` | PUT | Create/update user |
| `/users/{userId}/token` | POST | Generate SSO token |

## Environment Configuration

### Development (Local)
```
┌─────────────┐
│ Local Dev   │
│ Machine     │
│             │
│ - .env file │
│ - Go 1.19   │
│ - Port 3000 │
└─────────────┘
       │
       ├─► Auth0 (localhost callback)
       └─► Azure (via Azure CLI credentials)
```

### Production (Azure)
```
┌──────────────────┐
│ App Service      │
│ (Linux Container)│
│                  │
│ - Env vars from  │
│   Bicep          │
│ - Managed        │
│   Identity       │
│ - Port 3000      │
└──────────────────┘
       │
       ├─► Auth0 (webapp callback)
       └─► Azure (via Managed Identity)
```

## Monitoring & Observability

### Recommended Telemetry

1. **Application Logs**
   - Request/response logs
   - Error logs with stack traces
   - Authentication events

2. **Metrics**
   - Request rate
   - Error rate
   - Response time
   - Auth success/failure rate

3. **Traces**
   - End-to-end request flow
   - APIM API calls
   - Auth0 integration

4. **Health Checks**
   - Application health endpoint
   - Dependency health (APIM, Auth0)
   - Container health

## Scalability Considerations

### Horizontal Scaling
- **App Service Plan**: Can scale to multiple instances
- **Session Storage**: Use distributed cache (Redis) for multi-instance
- **Stateless Design**: Current implementation is mostly stateless

### Performance Optimization
- **Connection Pooling**: HTTP client connection reuse
- **Caching**: User existence checks
- **Async Operations**: Non-blocking I/O

## High Availability

### Components HA
- **APIM**: Built-in HA in Developer tier
- **App Service**: Multi-instance deployment
- **Auth0**: SLA 99.99%
- **ACR**: Geo-replication (if needed)

### Failure Modes
1. **Auth0 Down**: Users cannot authenticate
2. **APIM Down**: Portal unavailable, delegation fails
3. **Identity App Down**: Authentication fails
4. **Network Issues**: Retry logic recommended

## Cost Optimization

### Resource Sizing
- **APIM**: Developer tier (dev/test) → Standard/Premium (prod)
- **App Service**: P1v3 → Optimize based on usage
- **ACR**: Basic tier → Standard if needed

### Cost Drivers
1. APIM (largest cost)
2. App Service Plan
3. ACR storage
4. Data transfer

## Future Enhancements

### Security
- [ ] Implement PKCE for OAuth flow
- [ ] Add rate limiting
- [ ] Integrate Azure Key Vault
- [ ] Add WAF/DDoS protection

### Functionality
- [ ] Support subscription delegation
- [ ] Add user profile management
- [ ] Implement password reset flow
- [ ] Multi-factor authentication

### Operations
- [ ] Add Application Insights
- [ ] Implement circuit breaker
- [ ] Add retry policies
- [ ] Automated deployment pipeline

### Performance
- [ ] Add Redis for session storage
- [ ] Implement response caching
- [ ] Optimize Docker image size
- [ ] Add CDN for static assets

## References

- [Azure APIM Identity Delegation](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-setup-delegation)
- [Auth0 Documentation](https://auth0.com/docs)
- [Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Go Gin Framework](https://gin-gonic.com/)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)
