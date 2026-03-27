# Power Automate OAuth2 Setup — What You Need To Do

This guide covers every manual step required to get the `invokePAFlow` action
working. The TypeSpec and build scripts are already wired up.

---

## What the flow does

Magentic2 calls your Power Automate flow via an HTTP trigger, authenticated
with OAuth2 against `service.flow.microsoft.com` (not Microsoft Graph). The
token is managed by Microsoft 365 Copilot via the OAuth registration in Teams
Developer Portal.

```
Copilot → PAAgentAuth (OAuthPluginVault) → Entra token → PA HTTP trigger
```

Flow response shape:
```json
{ "status": "received", "message": "Message sent to Teams" }
```

---

## Confirmed values (already in the repo)

| Variable | Value |
|---|---|
| `PA_APP_SERVER_URL` | `https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com` |
| `PA_APP_INVOKE_PATH` | `/powerautomate/automations/direct/workflows/30c2f0f47bec43cc9342181e0662db57/triggers/manual/paths/invoke` |
| `PAAGENTAUTH_REGISTRATION_ID` | `YTE5ZjEyMWQtODFlMS00ODU4LWE5ZDgtNzM2ZTI2N2ZkNGM3IyNiYmQzMjM0MS1lNjBiLTQ2YmUtOWVkYy1hOTUwM2I1Mzc5MmE=` |
| Entra Client ID | `0e125f12-4719-471f-9c2a-3dacca7f03ac` |
| Token scope | `https://service.flow.microsoft.com//.default` (double-slash) |
| Grant type | `client_credentials` |
| Auth method | Request body parameters, PKCE disabled |

These are **already set** in `.env.dev`. No substitution needed unless you
rotate the client secret (see Step 1).

---

## Step 1 — Entra app (Azure Portal) — already created

The Entra app (`0e125f12-4719-471f-9c2a-3dacca7f03ac`) is already registered.

**If you rotate the client secret:**
1. Go to [portal.azure.com](https://portal.azure.com) → **Azure Active Directory** →
   **App registrations** → find the app by client ID `0e125f12-4719-471f-9c2a-3dacca7f03ac`
2. **Certificates & secrets** → delete the old secret → **New client secret**
3. Copy the new value immediately
4. Update the secret in **Teams Developer Portal** (Step 2)

**Required Entra API permissions (delegated, Power Automate):**
- `Flows.Read.All`
- `Flows.Manage.All`
- Admin consent must be granted

> The double-slash in `https://service.flow.microsoft.com//.default` is
> intentional and critical. Single-slash will break token acquisition.

---

## Step 2 — Teams Developer Portal OAuth registration — already done

Registration ID `YTE5ZjEyMWQtODFlMS00ODU4LWE5ZDgtNzM2ZTI2N2ZkNGM3IyNiYmQzMjM0MS1lNjBiLTQ2YmUtOWVkYy1hOTUwM2I1Mzc5MmE=`
is already in `.env.dev`.

**If you need to re-register or inspect it:**
1. Go to [dev.teams.microsoft.com](https://dev.teams.microsoft.com) →
   **Tools** → **OAuth client registrations**
2. Find or create the registration with:

   | Field | Value |
   |---|---|
   | **Base URL** | `https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com` (**no** `:443`) |
   | **Client ID** | `0e125f12-4719-471f-9c2a-3dacca7f03ac` |
   | **Client secret** | your current Entra secret |
   | **Authorization endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/authorize` |
   | **Token endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/token` |
   | **Refresh endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/token` |
   | **Scope** | `https://service.flow.microsoft.com//.default` |
   | **Auth method** | Request body parameters |
   | **PKCE** | Disabled |

3. If you create a new registration, copy the new Registration ID and update
   `PAAGENTAUTH_REGISTRATION_ID` in `env/.env.dev`, then re-run the build.

---

## Step 3 — Build and provision

Run these commands from the `Magentic2/` directory:

```bash
npm install

# Regenerate env.tsp from .env.dev (MUST run after any .env.dev change)
npm run generate:env -- dev

# Compile TypeSpec → OpenAPI specs + plugin manifests
npm run compile

# Inject fixed api-version=1 into the PA flow OpenAPI spec (not agent-visible)
npm run patch:pa-spec

# Stamp OAuthPluginVault into the plugin manifest
npm run patch:plugin-auth

# Patch the agent version string in the declarative agent JSON
npm run patch:agent-version
```

Then provision:
```bash
# Via CLI
atk provision --env dev

# Or via VS Code: M365 Agents Toolkit → Lifecycle → Provision
```

The `atk provision` command runs all the above steps automatically, then
zips, validates, and uploads the app package to Teams Developer Portal.

---

## Step 4 — Verify the redirect URI in Entra

After provisioning, go to **Azure Portal** → Entra app `0e125f12-4719-471f-9c2a-3dacca7f03ac`
→ **Authentication** and confirm a redirect URI was added by Teams Developer
Portal. If missing, Teams Dev Portal shows the expected URI — add it manually.

---

## Step 5 — Test in Copilot

1. Open Microsoft 365 Copilot
2. Find and open the **Magentic2dev** agent
3. Say something like: `send "hello" via Power Automate`
4. First use: Copilot will ask you to sign in — complete the consent flow
5. The flow should return: `{"status": "received", "message": "Message sent to Teams"}`

---

## How `api-version=1` is handled

The `api-version=1` query param is **not** exposed to the Copilot LLM. Instead:

1. TypeSpec does **not** declare it as an operation parameter (so the agent
   cannot fill or override it)
2. After TypeSpec compilation, `scripts/patch-pa-spec.js` injects it directly
   into the generated OpenAPI spec as a `required` parameter with `enum: ["1"]`
3. The Copilot runtime reads the OpenAPI spec and sends `?api-version=1` on
   every HTTP call automatically

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Compile error: `env.tsp` not found | `generate:env` not run | `npm run generate:env -- dev` |
| `x-ai-auth-reference-id` missing in spec | Compile ran before env was generated | Re-run `generate:env` then `compile` |
| Copilot doesn't prompt for sign-in | Plugin auth not patched | `npm run patch:plugin-auth` then re-provision |
| 401 from Power Automate | Admin consent missing | Grant consent in Azure Portal for `Flows.Read.All` + `Flows.Manage.All` |
| `invalid_client` on token exchange | Client secret expired or wrong | Rotate secret in Entra, update Teams Dev Portal registration |
| Base URL mismatch error | `:443` in URL | `PA_APP_SERVER_URL` must not contain `:443` — already correct in `.env.dev` |
| Flow returns 404 | `api-version` not injected | Run `npm run patch:pa-spec` |
| Flow triggered but no Teams message | Flow logic issue | Test the flow directly in Power Automate with a manual trigger |

---

## Files in this implementation

| File | Purpose |
|---|---|
| `src/agent/actions/invokePAFlow.tsp` | OAuth2 action — PAAgentAuth model, PA HTTP trigger route, request/response models |
| `src/agent/main.tsp` | Wires `invokePAFlow` into the agent |
| `env/.env.dev` | All env vars — `PA_APP_SERVER_URL`, `PA_APP_INVOKE_PATH`, `PAAGENTAUTH_REGISTRATION_ID` |
| `scripts/patch-pa-spec.js` | Injects `api-version=1` into generated OpenAPI spec post-compilation |
| `scripts/patch-plugin-auth.js` | Stamps `OAuthPluginVault` into the plugin manifest |
| `src/agent/env.tsp` | **Auto-generated** by `npm run generate:env` — do not edit by hand |
