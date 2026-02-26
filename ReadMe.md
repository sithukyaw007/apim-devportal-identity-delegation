# Azure API Management (APIM) Developer portal identity delegation with Keycloak
<p align="center">
  <img src="./src/images/readme.drawio.keycloak.png">
</p>
This project is created as an example for using identity delegation with Keycloak and Azure API Management (APIM) Developer portal.

## 🧭 Solution architecture

```mermaid
flowchart LR
    User((User)) --> Portal["APIM Developer Portal<br/>(hosted or self-hosted)"]
    Portal -->|"Delegation request<br/>operation, returnUrl, salt, sig"| App["Identity App<br/>Go and Gin"]
    App -->|"OIDC auth code flow"| Keycloak["Keycloak<br/>OIDC Provider"]
    Keycloak -->|"Federation (optional)"| Entra["Microsoft Entra ID<br/>members and guests"]
    App -->|"Azure ARM REST<br/>create or find user + shared token"| APIM["Azure API Management"]
    App -->|"signin-sso?token=..."| Portal
    App -->|"DefaultAzureCredential"| AzureCLI["Azure CLI or Managed Identity"]
```

System integration points:
- APIM developer portal delegates sign-in to the app via `GET /delegation` with HMAC signature.
- The app validates the signature using `DELEGATION_KEY` and initiates OIDC with Keycloak.
- Keycloak can federate to Microsoft Entra ID for member/guest users.
- The app uses Azure ARM APIs to create or fetch APIM users and request a shared access token.
- The app redirects back to the portal `signin-sso` endpoint with the shared access token.
- Azure auth uses `DefaultAzureCredential` (Azure CLI locally, Managed Identity in App Service).

## 📝 Demo
### SignUp
- Click on the `Sign Up` button on the top right corner when you are not an existing user in Keycloak.
- Switch to `Sign Up` and fill in the form and click on the `Sign Up` button.

- You will be signed up in Keycloak and also in the APIM instance.

### SignIn
- Click on the `Sign In` button on the top right corner when you are an existing user in Keycloak.
- An user will be added to the APIM instance if the user is not an existing user in the APIM instance.

## Disclaimer

Please note that the setup instructions provided in this README are intended for macOS users. While some steps may be applicable to other operating systems, I cannot guarantee compatibility or provide specific instructions for platforms other than macOS.

## 🛠️ Prerequisites
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Docker](https://docs.docker.com/get-docker/)
- [Go](https://golang.org/doc/install)
- [Bicep VSCode extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)

## 💻 Setup instructions

### 🔒 Configure Keycloak 🔒

Detail steps:
1. Create or use an existing Keycloak realm.
2. Create a confidential client for this app.
3. Set `Valid Redirect URIs` to:
    ```
    http://localhost:3000/callback,
    https://\<your-web-app-name\>.azurewebsites.net/callback,
    https://\<your-portal-host\>/callback
    ```
4. Set `Valid Post Logout Redirect URIs` to:
    ```
    http://localhost:3000,
    https://\<your-web-app-name\>.azurewebsites.net,
    https://\<your-portal-host\>/
    ```
5. Save the changes.
6. Copy the Client ID, Client Secret, and issuer URL into the `.env` file. The issuer URL should look like:
    ```
    https://<your-keycloak-host>/realms/<your-realm>
    ```

### 🔑 Keycloak + Microsoft Entra ID federation (checklist)
Use this when you want Entra member/guest users to sign in through Keycloak.

Keycloak (realm):
1. Open Identity Providers and add a new provider: `OpenID Connect v1.0`.
2. Set the `Alias` to something like `entra`.
3. Choose the Issuer based on your Entra setup:
    - Single-tenant: `https://login.microsoftonline.com/<tenant-id>/v2.0`
    - Multi-tenant: `https://login.microsoftonline.com/organizations/v2.0`
4. Set `Client ID` and `Client Secret` using the Entra app registration below.
5. Set `Default Scopes` to `openid profile email`.
6. Optional: enable `Sync Mode` to `FORCE` so profile changes are updated.
7. Save and note the `Redirect URI` that Keycloak shows for this IdP.

Microsoft Entra (app registration):
1. Create an app registration matching your tenant choice above (single-tenant or multi-tenant).
2. Add the Keycloak IdP redirect URI from the step above.
3. Create a client secret and copy it to Keycloak.
4. Add optional claims in the ID token: `email`, `preferred_username`, and `name`.
5. If you need guest users, enable external collaboration in Entra and assign access to the app.
6. If you need both members and guests from multiple tenants, keep the app multi-tenant and review cross-tenant access settings.

Validation:
1. In Keycloak, test the IdP login and confirm the user profile includes `sub` and `email`.
2. Try logging into the APIM developer portal and confirm the user is created in APIM.

### 🌳 Environment Variables 🌳
To run the environment successfully, rename the `.env.example` file to `.env` and provide the following values:

Here's a brief description of each environment variable:

- `PERSONAL_SUB_ID`: Your Azure subscription ID.
- `SUFFIX`: The suffix for your environment.
- `PUB_EMAIL`: Your public email address.
- `PUB_NAME`: Your public name.
- `DELEGATION_KEY`: Your delegation key. This should be in base64 format. You can generate one [here](https://www.base64encode.org/).
- `ACR_NAME`: The name of your Azure Container Registry (ACR). This should be globally unique.
- `ACR_REPO_NAME`: The name of your ACR repository.
- `IMAGE_TAG`: The tag for the Docker image.
- `KEYCLOAK_CALLBACK_URL`: Your Keycloak callback URL either localhost or your webapp | e.g http://localhost:3000/callback
- `APIM_NAME`: The name of your APIM.
- `APIM_RESOURCE_GROUP`: The name of your resource group.
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID.
- `DEVELOPER_PORTAL_URL`: The APIM developer portal URL (self-hosted or hosted).

Additionally, you will need to obtain the following values from Keycloak:

- `KEYCLOAK_CLIENT_ID`: Your Keycloak client ID.
- `KEYCLOAK_ISSUER`: Your Keycloak issuer URL.
- `KEYCLOAK_CLIENT_SECRET`: Your Keycloak client secret.

Make sure to provide the correct values for these variables to ensure proper authentication and authorization within the environment.

Note: It's important to keep sensitive information, such as personal IDs and secrets, private and secure. Be cautious when sharing your `.env` file or these values with others.

Delegation key

Make sure to add your delegation endpoint in your APIM with either your localhost or your webapp. Should look something like this: http://localhost:3000/delegation
Then generate a delegation key and add it to the env variables in base64 format.

### 🚘 Deploy Azure resources 🚘
- Run the following command to deploy the Azure resources:
    ```bash
    make deploy
    ```
- This will deploy the following resources:
    - Azure Container Registry
    - Azure APIM instance
    - Azure App Service Plan
    - Azure Web App
- This will also set up the following permissions:
    - Give Azure Web App `ACRPull` role access to the Azure Container Registry.
    - Give Azure Web App `Contributor` role access to the Azure APIM instance. This is for creating users in the APIM instance.
- Run `make buildimage` and `make pushimage` to build and push the docker image to the Azure Container Registry.

## 🚀 Usage
### 🌐 Publish developer portal on APIM
Publish your API Management developer portal following the tutorial [here](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-developer-portal-customize#publish-from-the-azure-portal).
If you are using the self-hosted portal, publish it separately and set `DEVELOPER_PORTAL_URL` to your portal's base URL (for example, `https://portal.example.com/`).
### 🔐 Signup and Login to the developer portal!
SignUp will create a user in Keycloak and also create a user in the APIM instance.

Login will authenticate the user with Keycloak and then delegate the user to the APIM instance.

## 🏃‍♂️ Run the app locally
- Create an .env file under `src/identityApp` and provide the following values:
    ```
    PERSONAL_SUB_ID=<your-subscription-id>
    SUFFIX=<your-suffix>
    PUB_EMAIL=<your-public-email>
    PUB_NAME=<your-public-name>
    DELEGATION_KEY=<your-delegation-key-in-base-64>
    ACR_NAME=<globally-unique-acr-name>
    ACR_REPO_NAME=<your-acr-repo-name> | e.g identity
    IMAGE_TAG=<your-image-tag> | e.g latest
    KEYCLOAK_CALLBACK_URL=<your-keycloak-callback-url> | e.g http://localhost:3000/callback
    APIM_NAME=<your-apim-name>
    APIM_RESOURCE_GROUP=<your-apim-resource-group-name>
    AZURE_SUBSCRIPTION_ID=<your-azure-subscription-id>
    DEVELOPER_PORTAL_URL=<your-developer-portal-url>
    KEYCLOAK_ISSUER=<your-keycloak-issuer-url>
    KEYCLOAK_CLIENT_ID=<your-keycloak-client-id>
    KEYCLOAK_CLIENT_SECRET=<your-keycloak-client-secret>
    ```
- Once you've set your Keycloak credentials in the `.env` file, run `go mod vendor` to download the Go dependencies.
- Run `go run main.go` to start the app and navigate to [http://localhost:3000/](http://localhost:3000/).
- If everything is working correctly, you should be able to see the successful login page.

## 📝 Notes
### AzureDefaultCredentials
The AzureDefaultCredentials is used to authenticate with Azure resources.
```go
func GetTokenViaGoSDK(ctx *gin.Context) (string, error) {
	cred, err := azidentity.NewDefaultAzureCredential(nil)

	if err != nil {
		ctx.String(http.StatusInternalServerError, err.Error())
		return "", err
	}

	token, err := cred.GetToken(ctx, policy.TokenRequestOptions{
		Scopes: []string{"https://management.azure.com/.default"},
	})

	if err != nil {
		ctx.String(http.StatusInternalServerError, err.Error())
		return "", err
	}

	return token.Token, nil
}
```
The NewDefaultAzureCredential will attempt to authenticate with each of these credential types, in the following order, stopping when one provides a token:
- EnvironmentCredential
- WorkloadIdentityCredential

    If environment variable configuration is set by the Azure workload identity webhook. Use WorkloadIdentityCredential directly when not using the webhook or needing more control over its configuration.
- ManagedIdentityCredential
- AzureCLICredential

Details can be found [here](https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/azidentity#DefaultAzureCredential)

In the deployed web app we are using the ManagedIdentityCredential.

### 🐛 Debug tips
If you are seeing unexpected errors, please go to Azure web app service and enable `Application logging` in the `App Service Log` page under `Monitor` and using [golang print statements](https://pkg.go.dev/fmt#Println). You should be able to see the logs in the Log Stream.

#### Local debugging guide (commands)
Run these from the repo root unless noted.

1. Log in to Azure (so `DefaultAzureCredential` can use Azure CLI):
    ```bash
    az login
    az account set --subscription <your-subscription-id>
    ```
2. Create and fill the local env file:
    ```bash
    cp .env.sample .env
    ```
3. Start the app locally:
    ```bash
    cd src/identityApp
    go mod vendor
    go run main.go
    ```
4. Basic sanity checks:
    ```bash
    curl -i http://localhost:3000/
    ```
5. If Keycloak redirects fail, verify the issuer metadata is reachable:
    ```bash
    curl -sS ${KEYCLOAK_ISSUER}/.well-known/openid-configuration | head -n 5
    ```
6. Tail the app logs (same terminal where you ran `go run`), then try a login from the portal.

Common issues:
- 403 Forbidden: Make sure the web app has `Contributor` role access to the APIM instance.
- 500 Internal Server Error: make sure the web app is up and running. You can check the logs in the Log Stream.

### 🧭 Keycloak federation troubleshooting
If Entra sign-in fails or returns incomplete claims, check the following:

- Missing `email` or `preferred_username`: add the optional claims in Entra and confirm Keycloak scopes include `email`.
- "invalid_redirect_uri": ensure the redirect URI in Entra matches the Keycloak IdP redirect URI exactly.
- "invalid_client" or "unauthorized_client": verify client ID/secret in Keycloak and app registration settings in Entra.
- Guest users not allowed: enable external collaboration in Entra and confirm the guest user has access to the app.
- Stale profile data: set Keycloak IdP `Sync Mode` to `FORCE` and retry login.

## 🚩 Contact
If you have any questions, please feel free to reach out to me at zoeyzuouk@gmail.com or create an issue in this repo.