param webApplication string
param keycloakClientId string
param keycloakIssuer string
param keycloakCallbackUrl string
param apimName string 
param rgName string 
param developerPortalUrl string 
param apimResourceUri string
// param azureClientId string
param azureTenantId string = subscription().tenantId
param subscriptionId string = subscription().subscriptionId

// @secure()
// param azureClientSecret string = ''

@description('The Keycloak client secret is stored in a key vault and retrieved using a user assigned identity')
@secure()
param keycloakClientSecret string = ''

@description('The APIM delegation key is stored in a key vault and retrieved using a user assigned identity')
@secure()
param delegationKey string = ''

resource appSettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: '${webApplication}/appsettings'
  properties: {
    KEYCLOAK_CLIENT_ID: keycloakClientId
    KEYCLOAK_ISSUER: keycloakIssuer
    AZURE_TENANT_ID: azureTenantId
    AZURE_SUBSCRIPTION_ID: subscriptionId
    KEYCLOAK_CALLBACK_URL: keycloakCallbackUrl
    KEYCLOAK_CLIENT_SECRET: keycloakClientSecret
    DELEGATION_KEY: delegationKey
    APIM_NAME: apimName
    APIM_RESOURCE_GROUP: rgName
    APIM_RESOURCE_URI: apimResourceUri
    DEVELOPER_PORTAL_URL: developerPortalUrl
    // AZURE_CLIENT_ID: azureClientId
    // AZURE_CLIENT_SECRET: azureClientSecret
  }
}
