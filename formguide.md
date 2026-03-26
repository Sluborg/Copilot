# Form Link Generation

## Purpose

After generating a JSON payload, produce a clickable hyperlink that prefills the Magentic prompt form. The user clicks the link → form opens with payload prefilled → submits → Flow executes. This is now used for logging agent memory, learnings, and self-improvement entries to the AgentLog SharePoint list.

## Base URL

```
https://forms.office.com/Pages/ResponsePage.aspx?id=HRKfoeGBWEip2HNuJn_Ux-Oj326AqwNJjQ447zeZuQtUNUFLVjhNRTNYQTMxQVZRQVBGNFhLQ0VRNC4u
```

## Parameters

| Parameter | Value |
|-----------|-------|
| `rc0f86772ec754af6bac37f8c821ff4c7` | The JSON payload (URL-encoded, curly braces double-encoded) |
| `r88e9674ecf024638a95a11f54a6848e6` | `734dffd7-b11a-4718-8a50-81abe023d9fb` (fixed key) |

## Encoding Rules

1. URL-encode the entire JSON payload
2. Replace `%7B` with `%257B` (double-encode opening curly brace)
3. Replace `%7D` with `%257D` (double-encode closing curly brace)

This is required because MS Forms interprets `{...}` as template syntax. Double-encoding preserves the braces as literal characters in the form field.


## Example: AgentLog Memory Entry

Given payload:
```json
{
	"logTitle": "AgentLog: Learning — Graph Auth Fails for Delegated",
	"source": "SharePoint",
	"operation": "CreateMemoryEntry",
	"fields": [
		{ "EntryType": "Learning" },
		{ "Title": "Graph Auth Fails for Delegated" },
		{ "Content": "Delegated permissions on /me endpoints fail for background agents. Use PA proxy pattern instead." },
		{ "Tags": "graph,entra,permissions,workaround" },
		{ "AgentVersion": "v1640" },
		{ "Confidence": 0.95 },
		{ "RelatedTo": "Entra/Graph auth setup" },
		{ "SessionId": "ses-20260326-001" }
	],
	"sharePointData": {
		"siteUrl": "https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev",
		"listInternalName": "AgentLog"
	}
}
```

Encoded value for `rc0f86772ec754af6bac37f8c821ff4c7`:
```
%257B%22logTitle%22%3A%22AgentLog%3A%20Learning%20%E2%80%94%20Graph%20Auth%20Fails%20for%20Delegated%22%2C%22source%22%3A%22SharePoint%22%2C%22operation%22%3A%22CreateMemoryEntry%22%2C%22fields%22%3A%5B%257B%22EntryType%22%3A%22Learning%22%257D%2C%257B%22Title%22%3A%22Graph%20Auth%20Fails%20for%20Delegated%22%257D%2C%257B%22Content%22%3A%22Delegated%20permissions%20on%20%2Fme%20endpoints%20fail%20for%20background%20agents.%20Use%20PA%20proxy%20pattern%20instead.%22%257D%2C%257B%22Tags%22%3A%22graph%2Centra%2Cpermissions%2Cworkaround%22%257D%2C%257B%22AgentVersion%22%3A%22v1640%22%257D%2C%257B%22Confidence%22%3A0.95%257D%2C%257B%22RelatedTo%22%3A%22Entra%2FGraph%20auth%20setup%22%257D%2C%257B%22SessionId%22%3A%22ses-20260326-001%22%257D%5D%2C%22sharePointData%22%3A%257B%22siteUrl%22%3A%22https%3A%2F%2Ffujitsuswe.sharepoint.com%2Fsites%2FSE-LuborgDev%22%2C%22listInternalName%22%3A%22AgentLog%22%257D%257D
```

## Output Format

Present the link inside a code block. Do NOT use a clickable hyperlink — Teams will break the URL by auto-linking, unfurling, or rewriting it.

````
```
https://forms.office.com/Pages/ResponsePage.aspx?id=...&rc0f86772ec754af6bac37f8c821ff4c7={encoded_payload}&r88e9674ecf024638a95a11f54a6848e6=734dffd7-b11a-4718-8a50-81abe023d9fb
```
````

User action: double-click the link in the code block → right-click → Open link.