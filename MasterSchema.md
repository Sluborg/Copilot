# MasterSchema – Power Automate Contract

Schema version: 1.0.0

## Purpose

This document is the authoritative source of truth for payload construction in the Magentic2 Power Automate flow.
The agent must follow this document exactly when building payloads for invokePAFlow.
If this document is retrieved, it takes precedence over any memory or instructions.
Do not invent properties outside this schema. Omit optional properties when not needed.

---

## Non-negotiable rules

- Payload MUST be a single minified JSON line — no whitespace, no newlines
- NEVER HTML-encode characters — write `<` and `>` literally, never as `&lt;` or `&gt;`
- SchemaXml must contain raw XML exactly as written — never escape angle brackets
- siteUrl must never end with a trailing slash
- Agent must never invent fields outside this schema

---

## Full schema (authoritative)

```json
{
  "source": "SharePoint | Teams",
  "operation": "<see per-source operation list below>",
  "logTitle": "<optional string>",
  "description": "<optional string>",
  "method": "<optional string>",
  "fields": "<optional array — see per-operation notes>",
  "sharePointData": "<required when source is SharePoint>",
  "teamsData": "<required when source is Teams>",
  "metadata": {
    "priority": "<optional string>",
    "requestedBy": "<optional string>"
  }
}
```

---

## SharePoint

**Required:** `source: "SharePoint"`, `operation`, `sharePointData.siteUrl`

### sharePointData shape

```json
{
  "siteUrl": "<required, no trailing slash>",
  "listDisplayName": "<optional>",
  "listInternalName": "<optional>",
  "listId": "<optional>",
  "configuration": "<optional, used for CreateList>",
  "query": "<optional, used for Read>"
}
```

### Default siteUrl

`https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev`

### Other known siteUrls

- `https://fujitsu.sharepoint.com/sites/Europe-AIforAll/Internal`
- `https://fujitsuswe-my.sharepoint.com/personal/stefan_lunneborg_fujitsu_com`
- `https://fujitsu.sharepoint.com/teams/SE-c93771c5`

### SharePoint operations

| Operation | fields required? | Notes |
|---|---|---|
| CreateRow | Yes — field name/value pairs | Multiple rows → multiple objects in fields array |
| UpdateRow | Yes — field name/value pairs | Include row ID |
| RemoveRow | No | |
| GetRow | No | |
| GetSchema | No — omit fields entirely | Use to discover column names before other ops |
| CreateList | Yes — `{ InternalName, SchemaXml, ShowInDefaultView }` | Also requires `configuration` in sharePointData |
| AddColumn | Yes — `{ InternalName, SchemaXml, ShowInDefaultView }` | |
| ModifyColumn | Yes | |
| RemoveColumn | No | |
| Read | No | Use `query` in sharePointData to filter |

### SchemaXml format

Write angle brackets literally. Never escape them.

Correct: `<Field DisplayName='MyColumn' Name='MyColumn' StaticName='MyColumn' Type='Text' Required='FALSE' />`

---

## Teams

**Required:** `source: "Teams"`, `operation`, `teamsData`

### teamsData shape

```json
{
  "message": "<optional string>",
  "receivers": ["<optional array of email strings>"],
  "conversationId": "<optional>",
  "channelId": "<optional>",
  "sendAs": "User | Flowbot",
  "chatType": "all | group | meeting | oneOnOne",
  "nickname": ["<optional array of strings>"],
  "meetingId": "<optional>",
  "meetingDate": "<optional>",
  "searchText": "<optional>"
}
```

### Teams operations

| Operation | Notes |
|---|---|
| SendToUser | Requires `receivers` and `message` |
| CreateChat | Requires `receivers` |
| SendToChat | Requires `conversationId` and `message` |
| ListChats | Use `chatType` to filter |

---

## Examples (non-authoritative — for pattern reference only)

### CreateRow — two rows

```json
{"source":"SharePoint","operation":"CreateRow","sharePointData":{"siteUrl":"https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev","listDisplayName":"Boxers"},"fields":[{"Title":"Muhammed Ali"},{"Title":"Mike Tyson"}]}
```

### GetSchema — discover columns before writing

```json
{"source":"SharePoint","operation":"GetSchema","sharePointData":{"siteUrl":"https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev","listDisplayName":"Boxers"}}
```

### CreateList — with one column

```json
{"logTitle":"CreateList: MyList","source":"SharePoint","operation":"CreateList","sharePointData":{"siteUrl":"https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev","listDisplayName":"MyList","listInternalName":"MyList","configuration":{"listTitle":"MyList","listDescription":"","baseTemplate":100,"contentTypesEnabled":false,"allowContentTypes":false}},"fields":[{"InternalName":"MyColumn","SchemaXml":"<Field DisplayName='MyColumn' Name='MyColumn' StaticName='MyColumn' Type='Text' Required='FALSE' />","ShowInDefaultView":true}],"metadata":{"priority":"Normal","requestedBy":"Stefan"}}
```

### SendToUser — Teams message

```json
{"source":"Teams","operation":"SendToUser","teamsData":{"receivers":["stefan.lunneborg@fujitsu.com"],"message":"Hello from Magentic2","sendAs":"Flowbot"}}
```
