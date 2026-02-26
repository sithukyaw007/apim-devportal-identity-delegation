package logout

import (
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gin-contrib/sessions"
)

// Handler for our logout.
func Handler(ctx *gin.Context) {
	issuer := strings.TrimRight(os.Getenv("KEYCLOAK_ISSUER"), "/")
	if issuer == "" {
		ctx.String(http.StatusInternalServerError, "Missing KEYCLOAK_ISSUER")
		return
	}

	logoutUrl, err := url.Parse(issuer + "/protocol/openid-connect/logout")
	if err != nil {
		ctx.String(http.StatusInternalServerError, err.Error())
		return
	}

	returnTo := os.Getenv("DEVELOPER_PORTAL_URL")
	if err != nil {
		ctx.String(http.StatusInternalServerError, err.Error())
		return
	}

	parameters := url.Values{}
	parameters.Add("post_logout_redirect_uri", returnTo)
	parameters.Add("client_id", os.Getenv("KEYCLOAK_CLIENT_ID"))

	session := sessions.Default(ctx)
	if idToken, ok := session.Get("id_token").(string); ok && idToken != "" {
		parameters.Add("id_token_hint", idToken)
	}
	logoutUrl.RawQuery = parameters.Encode()

	ctx.Redirect(http.StatusTemporaryRedirect, logoutUrl.String())
}
