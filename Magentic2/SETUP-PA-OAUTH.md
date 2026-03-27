# Power Automate OAuth2 Setup — What You Need To Do

This guide covers every manual step required to get the `invokePAFlow` action
working. The TypeSpec and build scripts are already wired up; you just need to
supply the credentials and run the build.

---

## What the flow does

Magentic2 calls your Power Automate flow via an HTTP trigger, authenticated
with OAuth2 against `service.flow.microsoft.com` (not Microsoft Graph). The
token is managed by Microsoft 365 Copilot via the OAuth registration you
create in Teams Developer Portal.

```
Copilot → PAAgentAuth (OAuthPluginVault) → Entra token → PA HTTP trigger
```

---

## Step 1 — Entra app registration (Azure Portal)

You need an Entra app to act as the OAuth client. **Skip if you already have one.**

1. Go to [portal.azure.com](https://portal.azure.com) → **Azure Active Directory** → **App registrations** → **New registration**
2. Name: anything (e.g. `Magentic2-PA-OAuth`)
3. Supported account types: **Single tenant** (`a19f121d-81e1-4858-a9d8-736e267fd4c7`)
4. Redirect URI: leave blank for now (Teams Developer Portal adds it)
5. Click **Register**
6. Note down:
   - **Application (client) ID** — you'll need this in Step 2
7. Go to **Certificates & secrets** → **New client secret**
   - Description: `Teams Dev Portal`
   - Expiry: choose an expiry that suits you
   - **Copy the secret value immediately** — you cannot retrieve it later
8. Go to **API permissions** → **Add a permission** → **APIs my organization uses**
   - Search for `Power Automate`
   - Select `Microsoft Flow Service` (or `Power Automate`)
   - Add the scope: `https://service.flow.microsoft.com//.default`
   - Click **Grant admin consent** (requires admin rights)

> **Note:** The double-slash in `https://service.flow.microsoft.com//.default`
> is intentional — it is the correct format for this service's `.default` scope.

---

## Step 2 — OAuth registration in Teams Developer Portal

This is where the `PAAGENTAUTH_REGISTRATION_ID` comes from. This is **not**
Entra — it is a separate registration in the Teams Developer Portal.

1. Go to [dev.teams.microsoft.com](https://dev.teams.microsoft.com)
2. Navigate to **Tools** → **OAuth client registrations** → **New registration** (or **Add**)
3. Fill in:
   | Field | Value |
   |---|---|
   | **Registration name** | `Magentic2 PA OAuth` (any name) |
   | **Base URL** | `https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com` |
   | **Client ID** | The **Application (client) ID** from Step 1 |
   | **Client secret** | The **secret value** from Step 1 |
   | **Authorization endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/authorize` |
   | **Token endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/token` |
   | **Refresh endpoint** | `https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/token` |
   | **Scope** | `https://service.flow.microsoft.com//.default` |

4. Click **Save**
5. **Copy the Registration ID** shown after saving — it looks like a GUID or base64 string

> **Critical:** The base URL must NOT include `:443`. The URL above is correct.

---

## Step 3 — Fill in `.env.dev`

Open `Magentic2/env/.env.dev` and replace the placeholder:

```
PAAGENTAUTH_REGISTRATION_ID=REPLACE_WITH_TEAMS_DEVELOPER_PORTAL_OAUTH_REGISTRATION_ID
```

Replace the value with the Registration ID you copied in Step 2:

```
PAAGENTAUTH_REGISTRATION_ID=<paste-registration-id-here>
```

The other PA variables are already set:
```
PA_APP_SERVER_URL=https://f97ec0186468e5028db0622bbd110e.5a.environment.api.powerplatform.com
PA_APP_INVOKE_PATH=/powerautomate/automations/direct/workflows/30c2f0f47bec43cc9342181e0662db57/triggers/manual/paths/invoke
```

---

## Step 4 — Regenerate `env.tsp`

`env.tsp` is **auto-generated** — never edit it by hand. After changing `.env.dev`, run:

```bash
cd Magentic2
npm install
npm run generate:env -- dev
```

This reads `env/.env.dev` and writes `src/agent/env.tsp` with all the
`Environment.*` constants that the TypeSpec files reference.

---

## Step 5 — Compile TypeSpec

```bash
npm run compile
```

This generates:
- `appPackage/.generated/declarativeAgent.json`
- `appPackage/.generated/specs/*.json` (OpenAPI specs)
- `appPackage/.generated/*-apiplugin.json` (plugin manifests)

The OpenAPI spec for the PA flow will include `x-ai-auth-reference-id` set to
your `PAAGENTAUTH_REGISTRATION_ID`, which is what the next step reads.

---

## Step 6 — Patch plugin auth

```bash
npm run patch:plugin-auth
```

This reads `x-ai-auth-reference-id` from the generated OpenAPI spec and
patches the plugin manifest to use `OAuthPluginVault` with your Registration
ID. This is what tells Copilot to use your Teams Developer Portal OAuth
registration when calling the flow.

---

## Step 7 — Provision

Use Microsoft 365 Agents Toolkit:

```bash
# Via CLI (if installed)
atk provision --env dev

# Or via VS Code: M365 Agents Toolkit extension → Lifecycle → Provision
```

This runs all the steps above automatically (install → generate:env → compile
→ patch-plugin-auth → zip → validate → upload to Teams Developer Portal).

---

## Step 8 — Verify the redirect URI in Entra

After provisioning, Teams Developer Portal will register a redirect URI for
your Entra app. Go back to **Azure Portal** → your Entra app registration →
**Authentication** and confirm the redirect URI was added. If it is missing,
add it manually (Teams Dev Portal usually shows you the expected URI).

---

## Step 9 — Test in Copilot

1. Open Microsoft 365 Copilot
2. Find and open the **Magentic2dev** agent
3. Say: `send a message via Power Automate`
4. Copilot should prompt you to sign in (first time only)
5. After consent, the flow should be triggered and return a response

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `env.tsp` not found during compile | `generate:env` not run | Run `npm run generate:env -- dev` |
| `x-ai-auth-reference-id` missing in OpenAPI spec | `PAAGENTAUTH_REGISTRATION_ID` is the placeholder value | Fill in the real value in `.env.dev` and re-run steps 4–6 |
| Copilot doesn't prompt for sign-in | Plugin auth not patched | Run `npm run patch:plugin-auth` and re-provision |
| 401 from Power Automate | Scope wrong or admin consent missing | Check Entra app has `service.flow.microsoft.com//.default` with admin consent granted |
| `invalid_client` on token exchange | Client secret wrong or expired | Regenerate secret in Entra, update Teams Developer Portal registration |
| Base URL mismatch error | `:443` in the URL | Ensure `PA_APP_SERVER_URL` has no `:443` suffix |
| Flow not triggered | Wrong flow URL | The flow URL is hardcoded in `invokePAFlow.tsp` — verify the workflow ID matches your flow |

---

## Files changed by this implementation

| File | What changed |
|---|---|
| `src/agent/actions/invokePAFlow.tsp` | **New.** OAuth2 action for the PA HTTP trigger |
| `src/agent/actions/teamsMessage.tsp` | **Deleted.** Replaced by `invokePAFlow.tsp` |
| `src/agent/main.tsp` | Wired `invokePAFlow` instead of `sendTeamsMessage` |
| `env/.env.dev` | Added `PA_APP_SERVER_URL`, `PA_APP_INVOKE_PATH`, `PAAGENTAUTH_REGISTRATION_ID` |
| `src/agent/env.tsp` | **Auto-generated** — regenerated by `npm run generate:env` |
