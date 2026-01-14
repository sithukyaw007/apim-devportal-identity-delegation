# APIM Developer Portal Delegation & Hybrid Gateway Architecture

## 1. Goals & Scope
- Hybrid API Management across **on-premises**, **Azure**, and **third-party clouds** with **Self-Hosted Gateway (SHG)**.
- **Developer Portal delegation** for **Entra ID** (internal) and **Keycloak (shared realm)** (external) personas.
- **GitOps** for APIs, products, policies, and portal content.
- **Region & Residency**: **southeastasia**; **Prod** with **ZRS**, **Dev/Test** with **LRS**.

## 2. Personas
| Persona | Auth | Roles | Capabilities |
|---------|------|-------|--------------|
| Platform Admin (customer platform team) | **Entra ID** | APIM Owner/Contributor | APIM governance, gateway ops, compliance, DR |
| API Publisher (internal) | **Entra ID** | APIM API Developer/Publisher | Publish APIs, docs, policies, products |
| API Publisher (external) | **Keycloak** (shared realm) | APIM Groups (scoped) | Onboard APIs via GitOps-approved process |
| API Consumer (internal/external) | **Entra ID / Keycloak** | Product subscriptions | Discover, subscribe, consume APIs |

## 3. High-Level Architecture
```mermaid
graph TD
  subgraph Azure
    APIM[APIM - Premium (Prod), Developer (Dev)]
    Portal[Developer Portal]
    DelegationApp[Delegation App (Go)]
    ACR[(ACR)]
    AppSvc[App Service for Delegation]
    LA[Log Analytics]
  end

  subgraph OnPrem / 3rd Party Cloud
    SHG[Self-Hosted Gateway]
    OnPremAPI[On-Prem APIs]
    PartnerAPI[Partner Cloud APIs]
  end

  subgraph Azure VNET
    ManagedGW[Managed Gateway]
    PrivateAPI[Azure Private APIs]
  end

  subgraph IdP
    Entra[Microsoft Entra ID]
    Keycloak[Keycloak Shared Realm]
  end

  Portal -->|/delegation| DelegationApp
  DelegationApp -->|OIDC| Entra
  DelegationApp -->|OIDC| Keycloak
  DelegationApp -->|Mgmt API| APIM
  APIM --> ManagedGW
  ManagedGW --> PrivateAPI
  APIM --> SHG
  SHG --> OnPremAPI
  SHG --> PartnerAPI
  APIM --> LA
```

## 4. Identity & Delegation
- Delegation endpoint `/delegation` validates **HMAC** (`DELEGATION_KEY`) to ensure request originates from APIM portal.
- Redirects to **Keycloak** or **Entra** (OIDC) with `state`.
- Callback `/callback` exchanges code → verifies ID token → provisions APIM user (if missing) → issues **APIM developer portal SSO token** (`signin-sso?token=`) → redirects to portal.
- Session stored in **secure cookie**; APIM **groups** differentiate internal vs external publishers/consumers.
- Secrets managed via **Key Vault**, injected with **Managed Identity**.

## 5. API Publishing (GitOps)
- Repos contain **OpenAPI specs**, **policies**, **products**, **groups**, **portal content**.
- Pipelines (GitHub Actions/Azure DevOps) validate and apply via `az apim`/ARM/REST.
- Semantic versioning; lifecycle and deprecation tracked via Git.

## 6. Gateways & Connectivity
- **Prod**: APIM Premium (ZRS) in **southeastasia**; **Self-Hosted Gateways** deployed on-prem/partner clouds with outbound-only sync.
- **Dev/Test**: APIM Developer (LRS) in **southeastasia**.
- **Managed Gateway**: VNET-integrated, Private Link to Azure backends.
- **Policies**: JWT/Subscription validation, rate-limit, transform, cache (where beneficial), mTLS (optional).

## 7. Environments
| Env | Region | APIM SKU | Resiliency | Notes |
|-----|--------|----------|------------|-------|
| Dev/Test | southeastasia | Developer | LRS | Lower cost, approvals/test |
| Prod | southeastasia | Premium | ZRS | SLA-backed, multi-AZ |

## 8. Operations & Monitoring
- **Logs/Metrics**: APIM diagnostics → Log Analytics; SHG logs shipped via sidecar/agent.
- **Alerts**: Throughput, latency, 429/5xx, SHG heartbeat, cert expiry.
- **Approvals**: Consumer onboarding **approval-based**; integrate with ticketing (TBD: ServiceNow/Azure DevOps).
- **Backups/DR**: Configuration in Git; APIM Premium backup/restore; SHG containers redeployable.

## 9. Security
- End-to-end TLS; certificates from Key Vault; rotation policy.
- APIM > Backend: OAuth2/JWT validation; optional mTLS.
- Least privilege: **Managed Identity** for APIM mgmt calls; role assignments for ACR pull & APIM contributor for delegation app.
- Regular rotation of **delegation key** and IdP client secrets.

## 10. Deployment Pipeline (High-Level)
1. **Infra** (Bicep): RG, APIM, App Service, ACR, role assignments (Prod Premium ZRS / Dev LRS).
2. **Image**: `make buildimage` → push to ACR.
3. **App Config**: App Service settings from Key Vault (IdP configs, delegation key).
4. **APIM Config**: GitOps pipeline applies APIs/policies/products/portal content.

## 11. Open Items
- Ticketing integration for approvals.
- Retention and PII scrubbing policies.
- API versioning/tagging conventions across repos.
- Cert lifecycle and mTLS backend requirements (if any).
