# Certificate-Based Authentication and mTLS for Azure APIM

## Overview

This document provides recommendations for integrating offsite remote systems with Azure API Management (APIM) using certificate-based authentication and mutual TLS (mTLS) for secure API consumption.

## Table of Contents
1. [Introduction](#introduction)
2. [Authentication Options Comparison](#authentication-options-comparison)
3. [Certificate-Based Authentication](#certificate-based-authentication)
4. [Mutual TLS (mTLS)](#mutual-tls-mtls)
5. [Implementation Approaches](#implementation-approaches)
6. [Best Practices](#best-practices)
7. [Integration Patterns](#integration-patterns)
8. [Certificate Management](#certificate-management)
9. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)

## Introduction

While the current solution uses Auth0 for developer portal authentication (human users), enterprise scenarios often require **machine-to-machine (M2M)** authentication for offsite remote systems consuming APIs. Certificate-based authentication and mTLS provide strong security for these scenarios.

### Use Cases
- **B2B Integration**: Partner systems calling your APIs
- **IoT Devices**: Device-to-cloud communication
- **Microservices**: Service-to-service authentication
- **Enterprise Systems**: Legacy systems requiring certificate authentication
- **Regulatory Compliance**: Industries requiring strong cryptographic authentication (finance, healthcare)

## Authentication Options Comparison

### 1. Certificate-Based Client Authentication (One-Way TLS + Client Cert)

```
┌─────────────┐                    ┌──────────────┐
│   Client    │                    │     APIM     │
│   System    │                    │              │
└──────┬──────┘                    └──────┬───────┘
       │                                   │
       │  1. HTTPS Request + Client Cert   │
       ├──────────────────────────────────►│
       │                                   │
       │  2. Server validates client cert  │
       │     - Thumbprint check            │
       │     - CA chain validation         │
       │     - Expiry check                │
       │                                   │
       │  3. Response (if cert valid)      │
       ◄───────────────────────────────────┤
       │                                   │
```

**Pros:**
- Strong authentication without passwords
- Client certificate uniquely identifies the system
- Difficult to impersonate
- Suitable for long-lived system credentials

**Cons:**
- Certificate management overhead
- Certificate rotation complexity
- Client must support certificate authentication

### 2. Mutual TLS (mTLS) - Two-Way Certificate Authentication

```
┌─────────────┐                    ┌──────────────┐
│   Client    │                    │     APIM     │
│   System    │                    │              │
└──────┬──────┘                    └──────┬───────┘
       │                                   │
       │  1. TLS Handshake                 │
       │     Client verifies server cert   │
       │     Server requests client cert   │
       ├──────────────────────────────────►│
       │                                   │
       │  2. Client sends certificate      │
       ├──────────────────────────────────►│
       │                                   │
       │  3. Mutual verification           │
       │     - Both certs validated        │
       │     - Encrypted channel           │
       │                                   │
       │  4. Encrypted API traffic         │
       ◄──────────────────────────────────►│
       │                                   │
```

**Pros:**
- Highest security level
- Both parties verify each other's identity
- Prevents man-in-the-middle attacks
- End-to-end encryption

**Cons:**
- Complex setup and configuration
- Both parties need certificate infrastructure
- Requires coordinated certificate rotation

### 3. OAuth 2.0 Client Credentials Flow (Alternative)

```
┌─────────────┐                    ┌──────────────┐
│   Client    │                    │  Auth Server │
│   System    │                    │  (Auth0/AAD) │
└──────┬──────┘                    └──────┬───────┘
       │                                   │
       │  1. Request token                 │
       │     client_id + client_secret     │
       ├──────────────────────────────────►│
       │                                   │
       │  2. Access token                  │
       ◄───────────────────────────────────┤
       │                                   │
       │                    ┌──────────────┴─┐
       │  3. API call       │      APIM      │
       │     + Bearer token │                │
       ├───────────────────►│                │
       │                    │ 4. Validate    │
       │                    │    token       │
       │                    └────────────────┘
```

**Pros:**
- Industry standard for M2M
- Token-based (easier rotation)
- Integrates with existing OAuth infrastructure
- Fine-grained scopes

**Cons:**
- Requires OAuth server
- Token exchange overhead
- Secret management (client_secret)

## Certificate-Based Authentication

### Option 1: Client Certificate Validation in APIM Policy

**Architecture:**
```
Client with Certificate → APIM (validate cert in policy) → Backend API
```

**Implementation:**

1. **Upload Client Certificates to APIM**
   ```bash
   # Upload certificate to APIM
   az apim certificate create \
     --resource-group <rg-name> \
     --service-name <apim-name> \
     --certificate-id client-cert-001 \
     --certificate-path ./client-cert.pfx \
     --certificate-password <password>
   ```

2. **APIM Inbound Policy for Certificate Validation**
   ```xml
   <policies>
     <inbound>
       <base />
       
       <!-- Validate client certificate -->
       <choose>
         <when condition="@(context.Request.Certificate == null)">
           <return-response>
             <set-status code="401" reason="Client certificate required" />
           </return-response>
         </when>
       </choose>
       
       <!-- Validate certificate thumbprint -->
       <choose>
         <when condition="@(context.Request.Certificate.Thumbprint != "EXPECTED_THUMBPRINT")">
           <return-response>
             <set-status code="403" reason="Invalid client certificate" />
           </return-response>
         </when>
       </choose>
       
       <!-- Validate certificate has not expired -->
       <choose>
         <when condition="@(context.Request.Certificate.NotAfter < DateTime.Now)">
           <return-response>
             <set-status code="403" reason="Client certificate expired" />
           </return-response>
         </when>
       </choose>
       
       <!-- Optional: Validate issuer -->
       <choose>
         <when condition="@(!context.Request.Certificate.Issuer.Contains("CN=YourCA"))">
           <return-response>
             <set-status code="403" reason="Certificate from untrusted issuer" />
           </return-response>
         </when>
       </choose>
       
       <!-- Set custom headers for backend -->
       <set-header name="X-Client-Cert-Subject" exists-action="override">
         <value>@(context.Request.Certificate.SubjectName.Name)</value>
       </set-header>
       
     </inbound>
     <backend>
       <base />
     </backend>
     <outbound>
       <base />
     </outbound>
     <on-error>
       <base />
     </on-error>
   </policies>
   ```

3. **Advanced: Certificate Validation with Multiple Allowed Certificates**
   ```xml
   <policies>
     <inbound>
       <base />
       
       <!-- Store allowed thumbprints in named value -->
       <set-variable name="allowedThumbprints" value="@{
         return new List<string> {
           "THUMBPRINT_1",
           "THUMBPRINT_2",
           "THUMBPRINT_3"
         };
       }" />
       
       <!-- Validate certificate -->
       <choose>
         <when condition="@{
           var cert = context.Request.Certificate;
           if (cert == null) return false;
           
           var allowed = (List<string>)context.Variables["allowedThumbprints"];
           return allowed.Contains(cert.Thumbprint);
         }">
           <!-- Certificate is valid, continue -->
         </when>
         <otherwise>
           <return-response>
             <set-status code="403" reason="Invalid or missing client certificate" />
             <set-body>@{
               return new JObject(
                 new JProperty("error", "authentication_failed"),
                 new JProperty("message", "Valid client certificate required")
               ).ToString();
             }</set-body>
           </return-response>
         </otherwise>
       </choose>
       
     </inbound>
   </policies>
   ```

### Option 2: Certificate Validation in Custom Backend

**Architecture:**
```
Client with Certificate → APIM → Custom Identity Service → APIM → Backend API
```

This approach extends the current Auth0 solution to support certificates:

**Implementation Steps:**

1. **Extend the Go Application** (`src/identityApp/platform/certauth/`)

```go
// certauth/validator.go
package certauth

import (
    "crypto/x509"
    "encoding/pem"
    "errors"
    "time"
)

type CertificateValidator struct {
    allowedThumbprints map[string]bool
    trustedCAs         *x509.CertPool
}

func NewCertificateValidator(allowedCerts []string, caPool *x509.CertPool) *CertificateValidator {
    thumbprints := make(map[string]bool)
    for _, cert := range allowedCerts {
        thumbprints[cert] = true
    }
    
    return &CertificateValidator{
        allowedThumbprints: thumbprints,
        trustedCAs:         caPool,
    }
}

func (v *CertificateValidator) ValidateCertificate(cert *x509.Certificate) error {
    // Check expiration
    now := time.Now()
    if now.Before(cert.NotBefore) || now.After(cert.NotAfter) {
        return errors.New("certificate expired or not yet valid")
    }
    
    // Check thumbprint
    thumbprint := fmt.Sprintf("%X", sha256.Sum256(cert.Raw))
    if !v.allowedThumbprints[thumbprint] {
        return errors.New("certificate not in allowed list")
    }
    
    // Verify certificate chain
    opts := x509.VerifyOptions{
        Roots:     v.trustedCAs,
        KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth},
    }
    
    if _, err := cert.Verify(opts); err != nil {
        return fmt.Errorf("certificate verification failed: %v", err)
    }
    
    return nil
}
```

2. **Add Certificate Endpoint** (`web/app/certauth/certauth.go`)

```go
package certauth

import (
    "net/http"
    "github.com/gin-gonic/gin"
    "auth-proxy/platform/certauth"
    "auth-proxy/platform/azureClient"
)

func Handler(validator *certauth.CertificateValidator) gin.HandlerFunc {
    return func(ctx *gin.Context) {
        // Extract client certificate from TLS connection
        if ctx.Request.TLS == nil || len(ctx.Request.TLS.PeerCertificates) == 0 {
            ctx.JSON(http.StatusUnauthorized, gin.H{
                "error": "client_certificate_required",
            })
            return
        }
        
        cert := ctx.Request.TLS.PeerCertificates[0]
        
        // Validate certificate
        if err := validator.ValidateCertificate(cert); err != nil {
            ctx.JSON(http.StatusForbidden, gin.H{
                "error": "invalid_certificate",
                "message": err.Error(),
            })
            return
        }
        
        // Extract subject (use as user identifier)
        subject := cert.Subject.CommonName
        
        // Get Azure token
        azureToken, err := azureClient.GetTokenViaGoSDK(ctx)
        if err != nil {
            ctx.JSON(http.StatusInternalServerError, gin.H{
                "error": "azure_auth_failed",
            })
            return
        }
        
        // Create or verify user in APIM
        uid := fmt.Sprintf("cert-%s", subject)
        userExists, _ := azureClient.UserExistInApim(uid, azureToken)
        
        if !userExists {
            err = azureClient.CreateUserInAPIM(subject, uid, azureToken)
            if err != nil {
                ctx.JSON(http.StatusInternalServerError, gin.H{
                    "error": "user_creation_failed",
                })
                return
            }
        }
        
        // Get APIM SSO token
        ssoToken, err := azureClient.GetSharedAccessTokenFromAPIM(azureToken, uid)
        if err != nil {
            ctx.JSON(http.StatusInternalServerError, gin.H{
                "error": "token_generation_failed",
            })
            return
        }
        
        // Return SSO token
        ctx.JSON(http.StatusOK, gin.H{
            "token": ssoToken,
            "subject": subject,
        })
    }
}
```

## Mutual TLS (mTLS)

### Option 1: APIM Premium Tier with Self-Hosted Gateway

**Architecture:**
```
Client System ◄─mTLS─► Self-Hosted Gateway ◄─► APIM ◄─► Backend
```

**Requirements:**
- APIM Premium tier
- Self-hosted gateway deployed in your network or client network
- Mutual certificate trust

**Configuration:**

1. **Deploy Self-Hosted Gateway**
   ```bash
   # Create gateway in APIM
   az apim gateway create \
     --resource-group <rg-name> \
     --service-name <apim-name> \
     --gateway-id self-hosted-gw-001
   
   # Get gateway token
   az apim gateway token create \
     --resource-group <rg-name> \
     --service-name <apim-name> \
     --gateway-id self-hosted-gw-001 \
     --expiry 2024-12-31
   ```

2. **Configure mTLS on Self-Hosted Gateway**
   
   Docker deployment with mTLS:
   ```yaml
   # docker-compose.yml
   version: '3.8'
   services:
     apim-gateway:
       image: mcr.microsoft.com/azure-api-management/gateway:latest
       ports:
         - "443:8080"
         - "8081:8081"
       environment:
         - config.service.endpoint=<gateway-endpoint>
         - config.service.auth=<gateway-token>
       volumes:
         - ./certs/server.crt:/etc/ssl/certs/server.crt
         - ./certs/server.key:/etc/ssl/private/server.key
         - ./certs/ca.crt:/etc/ssl/certs/ca.crt
       command: >
         --tls-cert /etc/ssl/certs/server.crt
         --tls-key /etc/ssl/private/server.key
         --tls-client-ca /etc/ssl/certs/ca.crt
         --tls-client-auth-required
   ```

### Option 2: Application Gateway + APIM

**Architecture:**
```
Client ◄─mTLS─► Application Gateway ◄─HTTPS─► APIM ◄─► Backend
```

**Benefits:**
- Application Gateway handles mTLS termination
- APIM receives certificate information in headers
- Works with any APIM tier

**Configuration:**

1. **Application Gateway with mTLS**
   ```bicep
   resource appGateway 'Microsoft.Network/applicationGateways@2023-02-01' = {
     name: 'apim-mtls-gateway'
     location: location
     properties: {
       sku: {
         name: 'WAF_v2'
         tier: 'WAF_v2'
       }
       sslCertificates: [
         {
           name: 'server-cert'
           properties: {
             data: serverCertData
             password: serverCertPassword
           }
         }
       ]
       trustedRootCertificates: [
         {
           name: 'client-ca-cert'
           properties: {
             data: clientCaCertData
           }
         }
       ]
       sslProfiles: [
         {
           name: 'mtls-profile'
           properties: {
             clientAuthConfiguration: {
               verifyClientCertIssuerDN: true
             }
             trustedClientCertificates: [
               {
                 id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', 'apim-mtls-gateway', 'client-ca-cert')
               }
             ]
           }
         }
       ]
       httpListeners: [
         {
           name: 'mtls-listener'
           properties: {
             protocol: 'Https'
             sslCertificate: {
               id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', 'apim-mtls-gateway', 'server-cert')
             }
             sslProfile: {
               id: resourceId('Microsoft.Network/applicationGateways/sslProfiles', 'apim-mtls-gateway', 'mtls-profile')
             }
           }
         }
       ]
       requestRoutingRules: [
         {
           name: 'mtls-routing-rule'
           properties: {
             ruleType: 'Basic'
             httpListener: {
               id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'apim-mtls-gateway', 'mtls-listener')
             }
             backendAddressPool: {
               id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'apim-mtls-gateway', 'apim-pool')
             }
           }
         }
       ]
     }
   }
   ```

2. **APIM Policy to Read Certificate from Headers**
   ```xml
   <policies>
     <inbound>
       <base />
       
       <!-- Application Gateway forwards cert info in headers -->
       <set-variable name="clientCertThumbprint" 
                     value="@(context.Request.Headers.GetValueOrDefault("X-ARR-ClientCert-Thumbprint", ""))" />
       
       <set-variable name="clientCertSubject" 
                     value="@(context.Request.Headers.GetValueOrDefault("X-ARR-ClientCert-Subject", ""))" />
       
       <!-- Validate certificate thumbprint -->
       <choose>
         <when condition="@(string.IsNullOrEmpty((string)context.Variables["clientCertThumbprint"]))">
           <return-response>
             <set-status code="401" reason="Certificate required" />
           </return-response>
         </when>
       </choose>
       
     </inbound>
   </policies>
   ```

## Implementation Approaches

### Approach 1: Hybrid Authentication (Recommended)

Support both OAuth 2.0 (for developer portal) and certificate-based (for system integration):

```
┌─────────────────┐                    ┌──────────────────┐
│  Human Users    │──── OAuth 2.0 ────►│                  │
│ (Dev Portal)    │     (Auth0)        │                  │
└─────────────────┘                    │      APIM        │
                                       │                  │
┌─────────────────┐                    │   - API Gateway  │
│  Remote Systems │─── Certificate ───►│   - Policies     │
│  (M2M)          │     / mTLS         │   - Products     │
└─────────────────┘                    └──────────────────┘
```

**APIM Policy for Hybrid Auth:**
```xml
<policies>
  <inbound>
    <base />
    
    <!-- Check authentication type -->
    <choose>
      <!-- OAuth Bearer Token -->
      <when condition="@(context.Request.Headers.ContainsKey("Authorization"))">
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
          <openid-config url="https://your-tenant.auth0.com/.well-known/openid-configuration" />
          <audiences>
            <audience>your-api-audience</audience>
          </audiences>
        </validate-jwt>
      </when>
      
      <!-- Client Certificate -->
      <when condition="@(context.Request.Certificate != null)">
        <!-- Validate certificate as shown earlier -->
        <choose>
          <when condition="@(context.Request.Certificate.Thumbprint != "EXPECTED_THUMBPRINT")">
            <return-response>
              <set-status code="403" reason="Invalid certificate" />
            </return-response>
          </when>
        </choose>
      </when>
      
      <!-- No valid authentication -->
      <otherwise>
        <return-response>
          <set-status code="401" reason="Authentication required" />
          <set-header name="WWW-Authenticate" exists-action="override">
            <value>Bearer realm="API"</value>
          </set-header>
        </return-response>
      </otherwise>
    </choose>
    
  </inbound>
</policies>
```

### Approach 2: Separate APIM Products

Create different products for different authentication methods:

```
APIM Instance
  │
  ├─ Product: "Developer Portal APIs"
  │    └─ Auth: OAuth 2.0 (Auth0)
  │
  └─ Product: "Partner Integration APIs"
       └─ Auth: Client Certificates
```

**Benefits:**
- Clear separation of concerns
- Different rate limits per product
- Independent subscription management

## Best Practices

### 1. Certificate Management

**Certificate Storage:**
- Store certificates in Azure Key Vault
- Use Managed Identity for access
- Enable certificate rotation

```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'apim-certs-kv'
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enabledForDeployment: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
  }
}

resource certificate 'Microsoft.KeyVault/vaults/certificates@2023-02-01' = {
  parent: keyVault
  name: 'client-cert-001'
  properties: {
    attributes: {
      enabled: true
    }
    certificatePolicy: {
      issuerParameters: {
        name: 'Self'
      }
      keyProperties: {
        keySize: 4096
        keyType: 'RSA'
      }
      x509CertificateProperties: {
        subject: 'CN=partner-system-001'
        validityInMonths: 12
      }
    }
  }
}
```

**Certificate Rotation:**
```bash
# Automated rotation script
#!/bin/bash

# Generate new certificate
openssl req -new -x509 -days 365 -key private.key -out new-cert.crt

# Upload to Key Vault
az keyvault certificate import \
  --vault-name apim-certs-kv \
  --name client-cert-001 \
  --file new-cert.pfx

# Update APIM with new thumbprint
THUMBPRINT=$(openssl x509 -in new-cert.crt -fingerprint -noout | cut -d'=' -f2)

# Update APIM named value
az apim nv update \
  --resource-group <rg> \
  --service-name <apim> \
  --named-value-id allowed-thumbprints \
  --value "$THUMBPRINT"
```

### 2. Security Hardening

**TLS Configuration:**
```xml
<!-- In APIM policy -->
<policies>
  <inbound>
    <!-- Enforce TLS 1.2+ -->
    <choose>
      <when condition="@(context.Request.Url.Scheme != "https")">
        <return-response>
          <set-status code="403" reason="HTTPS required" />
        </return-response>
      </when>
    </choose>
    
    <!-- Check TLS version (if available) -->
    <set-header name="Strict-Transport-Security" exists-action="override">
      <value>max-age=31536000; includeSubDomains</value>
    </set-header>
  </inbound>
</policies>
```

**Certificate Pinning:**
- Pin specific CA certificates
- Validate certificate chain
- Check certificate revocation (CRL/OCSP)

### 3. Monitoring and Logging

**Log Certificate Authentication Events:**
```xml
<policies>
  <inbound>
    <base />
    
    <!-- Log certificate details -->
    <choose>
      <when condition="@(context.Request.Certificate != null)">
        <log-to-eventhub logger-id="cert-auth-logger">
          @{
            return new JObject(
              new JProperty("timestamp", DateTime.UtcNow),
              new JProperty("subject", context.Request.Certificate.SubjectName.Name),
              new JProperty("thumbprint", context.Request.Certificate.Thumbprint),
              new JProperty("issuer", context.Request.Certificate.Issuer),
              new JProperty("expiry", context.Request.Certificate.NotAfter),
              new JProperty("api", context.Api.Name),
              new JProperty("operation", context.Operation.Name)
            ).ToString();
          }
        </log-to-eventhub>
      </when>
    </choose>
  </inbound>
</policies>
```

**Application Insights Monitoring:**
```xml
<policies>
  <inbound>
    <base />
    
    <!-- Track custom metric for cert auth -->
    <emit-metric name="certificate-authentications" value="1" namespace="custom-metrics">
      <dimension name="subject" value="@(context.Request.Certificate?.SubjectName.Name ?? "none")" />
      <dimension name="api" value="@(context.Api.Name)" />
    </emit-metric>
  </inbound>
</policies>
```

### 4. Error Handling

**Comprehensive Error Responses:**
```xml
<policies>
  <on-error>
    <base />
    
    <!-- Certificate-specific errors -->
    <choose>
      <when condition="@(context.LastError.Source == "validate-client-certificate")">
        <return-response>
          <set-status code="403" reason="Certificate validation failed" />
          <set-body>@{
            return new JObject(
              new JProperty("error", "invalid_certificate"),
              new JProperty("error_description", context.LastError.Message),
              new JProperty("timestamp", DateTime.UtcNow.ToString("o"))
            ).ToString();
          }</set-body>
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
        </return-response>
      </when>
    </choose>
  </on-error>
</policies>
```

## Integration Patterns

### Pattern 1: Certificate-Based API Gateway

```
Remote System
    │
    │ 1. HTTPS + Client Certificate
    ▼
Application Gateway (mTLS termination)
    │
    │ 2. Forward cert info in headers
    ▼
APIM (Certificate validation policy)
    │
    │ 3. Validate and route
    ▼
Backend API
```

**Use Case:** High-security B2B integrations

### Pattern 2: Token Exchange Service

```
Remote System
    │
    │ 1. Request token with certificate
    ▼
Certificate Auth Service (Extended Identity App)
    │
    │ 2. Validate certificate
    │ 3. Issue JWT token
    ▼
Remote System
    │
    │ 4. Use JWT for API calls
    ▼
APIM (JWT validation)
    │
    ▼
Backend API
```

**Use Case:** Legacy systems that need token-based access

### Pattern 3: Dual-Mode Authentication

```
Developer Portal Users → OAuth 2.0 → APIM → Backend
Partner Systems        → Certificate → APIM → Backend
```

**Use Case:** Mixed human and machine consumers

## Certificate Management

### 1. Certificate Lifecycle

```
┌─────────────────┐
│  Certificate    │
│   Generation    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Distribution  │
│   to Clients    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Monitoring    │
│   Expiry        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Rotation      │
│   (Pre-expiry)  │
└────────┬────────┘
         │
         └─────────► (Repeat)
```

### 2. Automated Certificate Rotation

**Azure Function for Certificate Monitoring:**
```csharp
[FunctionName("MonitorCertificates")]
public static async Task Run(
    [TimerTrigger("0 0 0 * * *")] TimerInfo timer, // Daily
    ILogger log)
{
    var kvClient = new CertificateClient(
        new Uri(Environment.GetEnvironmentVariable("KEY_VAULT_URL")),
        new DefaultAzureCredential()
    );
    
    await foreach (var certProperties in kvClient.GetPropertiesOfCertificatesAsync())
    {
        var cert = await kvClient.GetCertificateAsync(certProperties.Name);
        
        // Check if expiring within 30 days
        if (cert.Value.Properties.ExpiresOn.HasValue &&
            cert.Value.Properties.ExpiresOn.Value.UtcDateTime < DateTime.UtcNow.AddDays(30))
        {
            log.LogWarning($"Certificate {certProperties.Name} expires on {cert.Value.Properties.ExpiresOn}");
            
            // Send alert (e.g., to Azure Monitor, email, Teams)
            await SendExpiryAlert(certProperties.Name, cert.Value.Properties.ExpiresOn.Value);
        }
    }
}
```

### 3. Certificate Revocation

**Implement Certificate Revocation List (CRL) Check:**
```xml
<policies>
  <inbound>
    <base />
    
    <!-- Check certificate revocation -->
    <send-request mode="new" response-variable-name="crlResponse" timeout="10" ignore-error="false">
      <set-url>http://crl.example.com/check/@(context.Request.Certificate.Thumbprint)</set-url>
      <set-method>GET</set-method>
    </send-request>
    
    <choose>
      <when condition="@(((IResponse)context.Variables["crlResponse"]).StatusCode == 200)">
        <return-response>
          <set-status code="403" reason="Certificate revoked" />
        </return-response>
      </when>
    </choose>
  </inbound>
</policies>
```

## Monitoring and Troubleshooting

### Common Issues

**1. Certificate Not Being Sent**
```bash
# Test with curl
curl -v --cert client.crt --key client.key https://apim-endpoint/api

# Check TLS handshake
openssl s_client -connect apim-endpoint:443 -cert client.crt -key client.key -showcerts
```

**2. Certificate Validation Failing**
```bash
# Verify certificate chain
openssl verify -CAfile ca.crt client.crt

# Check certificate details
openssl x509 -in client.crt -text -noout

# Verify thumbprint
openssl x509 -in client.crt -fingerprint -sha256 -noout
```

**3. mTLS Handshake Issues**
```bash
# Debug TLS with detailed output
openssl s_client -connect apim-endpoint:443 \
  -cert client.crt \
  -key client.key \
  -CAfile ca.crt \
  -debug \
  -msg
```

### Diagnostic APIM Policy

```xml
<policies>
  <inbound>
    <base />
    
    <!-- Diagnostic headers -->
    <set-header name="X-Debug-Cert-Present" exists-action="override">
      <value>@(context.Request.Certificate != null ? "true" : "false")</value>
    </set-header>
    
    <choose>
      <when condition="@(context.Request.Certificate != null)">
        <set-header name="X-Debug-Cert-Subject" exists-action="override">
          <value>@(context.Request.Certificate.SubjectName.Name)</value>
        </set-header>
        
        <set-header name="X-Debug-Cert-Thumbprint" exists-action="override">
          <value>@(context.Request.Certificate.Thumbprint)</value>
        </set-header>
        
        <set-header name="X-Debug-Cert-Expiry" exists-action="override">
          <value>@(context.Request.Certificate.NotAfter.ToString("o"))</value>
        </set-header>
      </when>
    </choose>
  </inbound>
</policies>
```

## Recommended Solution for Offsite Remote Systems

Based on enterprise requirements, here's the recommended approach:

### Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Hybrid Authentication                       │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐                  ┌──────────────────┐  │
│  │  Human Users     │                  │ Remote Systems   │  │
│  │ (Dev Portal)     │                  │  (Partners/IoT)  │  │
│  └────────┬─────────┘                  └────────┬─────────┘  │
│           │                                      │            │
│           │ OAuth 2.0                            │ mTLS       │
│           │ (Auth0)                              │ Certificate│
│           │                                      │            │
│           ▼                                      ▼            │
│  ┌──────────────────────────────────────────────────────┐    │
│  │          Azure Application Gateway (WAF)             │    │
│  │          - mTLS Termination                          │    │
│  │          - Certificate Validation                    │    │
│  │          - Forward cert info in headers              │    │
│  └──────────────────┬───────────────────────────────────┘    │
│                     │                                         │
│                     ▼                                         │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              Azure API Management                    │    │
│  │              - Hybrid auth policy                    │    │
│  │              - Certificate validation                │    │
│  │              - OAuth JWT validation                  │    │
│  │              - Rate limiting                         │    │
│  └──────────────────┬───────────────────────────────────┘    │
│                     │                                         │
│                     ▼                                         │
│           ┌─────────────────┐                                │
│           │  Backend APIs   │                                │
│           └─────────────────┘                                │
└───────────────────────────────────────────────────────────────┘
```

### Implementation Steps

1. **Phase 1: Foundation**
   - Deploy Application Gateway with WAF
   - Configure mTLS support
   - Set up certificate management in Key Vault

2. **Phase 2: APIM Integration**
   - Implement hybrid authentication policy
   - Create separate products for cert-based access
   - Configure monitoring and alerting

3. **Phase 3: Client Onboarding**
   - Generate and distribute client certificates
   - Provide integration documentation
   - Set up support and monitoring

### Sample Implementation Timeline

- **Week 1**: Infrastructure setup (App Gateway, Key Vault)
- **Week 2**: APIM policy development and testing
- **Week 3**: Certificate generation and distribution process
- **Week 4**: Pilot with first partner system
- **Week 5**: Monitoring, alerting, and documentation
- **Week 6**: Production rollout

## Conclusion

For offsite remote systems integrating with Azure APIM:

**Recommended Approach:** **Application Gateway with mTLS + APIM Certificate Validation**

**Key Benefits:**
- ✅ Strong cryptographic authentication
- ✅ Works with any APIM tier
- ✅ Supports both human (OAuth) and machine (cert) authentication
- ✅ Certificate management in Azure Key Vault
- ✅ WAF protection included
- ✅ Comprehensive monitoring

**Alternative for Simple Scenarios:** Client certificate validation in APIM policies (if Premium tier and self-hosted gateway is available for true mTLS).

For questions or implementation assistance, refer to the [Technical Solutions Documentation](./TECHNICAL_SOLUTIONS.md) or raise an issue in the repository.
