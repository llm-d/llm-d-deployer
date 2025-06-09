
# 🔐 Simple JWT Authentication Gateway API Key

⚠️ Dev only: This inline-JWKS, single-shared-secret approach is for local or sandbox testing. For production deployments, consider:

- Asymmetric Key Algorithms (RS256/ES256): Use an asymmetric algorithm like RS256. This involves a private key to sign tokens and a public key, which Istio uses to verify them. This is more secure as the private key never leaves your identity provider.
- Identity Provider (IdP) Integration: Integrate with a dedicated identity provider like Keycloak, Okta, or Auth0. These services manage user authentication, token issuance, and key management.
- Use jwksUri: Configure Istio's RequestAuthentication to fetch the JSON Web Key Set (JWKS) from your identity provider's public-facing endpoint (jwksUri). This allows for seamless key rotation and management without needing to update your Istio configuration.

To use this, ensure Istio is used in the sample deployment [values.yaml](../charts/llm-d/values.yaml) file as the `gatewayClassName`.
The following is the manual process to add an API key to the gateway. The [quickstart](README.md) installer will perform this process
for you with the `--gateway-api-key <SECRET>` flag.

An example installation invocation would be:

```bash
# example API key was generated from: openssl rand -hex 32
./llmd-installer.sh --values-file examples/base/base.yaml --gateway-api-key f59f73eff3357c3754b9b60671f16ffcec9b1a301498fa18c928bb753d4b385a
```

You would then test the running stack by supplying the key. To create and sign the API key for the Istio gateway see the
commands in the manual installation portion [Generate and Use a JWT](#generate-and-use-a-jwt)

```bash
./test-request.sh --api-key eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImRldi1rZXkifQ.eyJpc3MiOiJkZXYiLCJzdWIiOiJkZXYtdXNlciJ9.S6AKJ6CRs5nbrhHPshc2KnikNkjLp9isg6xlR4kSecQ
```

## Manual Installation

The steps automated in the installer are as the following.

### 1) Pick your raw HS256 secret

This can be any short string (example: `openssl rand -hex 32`):

```bash
# e.g.
DEV_SECRET='f59f73eff3357c3754b9b60671f16ffcec9b1a301498fa18c928bb753d4b385a'
```

### 2) Base64-URL-encode it for Istio’s inline JWKS

```bash
BASE64URL_K=$(echo -n "$DEV_SECRET" \
  | openssl base64 -A \
  | tr '+/' '-_' \
  | tr -d '=')

echo "Use this value in your RequestAuthentication:"
echo "$BASE64URL_K"
```

### 3) Add it to your `RequestAuthentication` CR

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: llm-d-dev-jwt
  namespace: llm-d
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: inference-gateway
  jwtRules:
  - issuer: "dev"
    jwks: |
      {
        "keys":[
          {
            "kty":"oct",
            "kid":"dev-key",
            "use":"sig",
            "alg":"HS256",
            "k":"<PASTE_YOUR_BASE64URL_K_HERE>"
          }
        ]
      }
```

Apply it:

```bash
kubectl apply -f secure-gateway-dev.yaml
```

---

## Generate and Use a JWT

Run this to build a minimal `iss=dev, sub=dev-user` HS256-signed JWT and immediately run your smoke tests:

```bash
DEV_SECRET='f59f73eff3357c3754b9b60671f16ffcec9b1a301498fa18c928bb753d4b385a'   # your raw secret
# 1) create header & payload
HEADER=$(echo -n '{"alg":"HS256","typ":"JWT","kid":"dev-key"}' \
         | openssl base64 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(echo -n '{"iss":"dev","sub":"dev-user"}' \
         | openssl base64 | tr '+/' '-_' | tr -d '=')
# 2) sign it
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" \
           | openssl dgst -binary -sha256 -hmac "$DEV_SECRET" \
           | openssl base64 | tr '+/' '-_' | tr -d '=')
# 3) assemble & run tests
JWT="$HEADER.$PAYLOAD.$SIGNATURE"

echo "Generated dev JWT:"
echo "$JWT"
echo

# now smoke-test your gateway with the new token:
./test-request.sh --minikube --namespace llm-d --api-key "$JWT"
```

This will send `Authorization: Bearer <above_JWT>` on all requests in `test-request.sh`.

## Uninstall the resources

To list the Istio JWT auth resources you’ve applied in your llm-d namespace:

```bash
# List both RequestAuthentication and AuthorizationPolicy
kubectl get requestauthentication,authorizationpolicy -n llm-d
```

To remove the installed resources (this is automated in the installer `--uninstall`):

```bash
kubectl delete requestauthentication llm-d-dev-jwt \
               authorizationpolicy llm-d-dev-authz \
               -n llm-d
# Or from the manifest file
kubectl delete -f helpers/k8s/secure-gateway-dev.yaml -n llm-d
```
