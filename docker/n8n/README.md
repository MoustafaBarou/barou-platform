# n8n

Self-hosted n8n (Docker Compose) met de workflow **AI Inbox Agent**.

```
docker/n8n/
├── docker-compose.yml
├── .env.example                  # template voor .env (echte .env staat in .gitignore)
└── workflows/
    └── ai-inbox-agent.json       # export zonder credential-ID's of secrets
```

## n8n starten

1. Maak `.env` aan op basis van het voorbeeld en vul de waarden in:

   ```bash
   cp .env.example .env
   openssl rand -hex 32   # waarde voor N8N_ENCRYPTION_KEY
   ```

   | Variabele | Doel |
   |---|---|
   | `N8N_ENCRYPTION_KEY` | Versleutelt opgeslagen credentials. Bewaar hem goed: zonder deze sleutel zijn bestaande credentials onleesbaar. |
   | `WEBHOOK_URL` | Publieke basis-URL van n8n (met `/` aan het eind). Compose geeft hem door als `N8N_WEBHOOK_URL`; nodig voor webhooks en OAuth-redirects. |

2. Start de container:

   ```bash
   docker compose up -d
   docker compose exec n8n env | grep WEBHOOK   # controle: N8N_WEBHOOK_URL=...
   ```

n8n draait op poort `5678`. Data (workflows, credentials, executions) staat in het volume `n8n_data`.

## AI Inbox Agent

Classificeert nieuwe mail met Claude en zet labels, categorieën en betaalherinneringen. **Label-only**: er wordt niets verplaatst of verwijderd.

```
Gmail (werk) ─────┐                                                    ┌─> Gmail: label (+ ster bij betalingen)
                  ├─> Normalize + prompt ─> Claude ─> Parse AI result ─┼─> Outlook: categorie (+ vlag bij betalingen)
Outlook (pers.) ──┘                                                    └─> Google Calendar: betaalherinnering
```

Beide triggers pollen elke 5 minuten.

| Categorie (Claude) | Gmail-label / Outlook-categorie | Extra |
|---|---|---|
| `payment_due` | Te betalen | Ster (Gmail) / vlag (Outlook), agenda-afspraak 2 dagen voor de vervaldatum om 09:00 |
| `important` | geen (blijft gewoon in inbox) | Vacature- en opdrachtmatches vallen hier altijd onder |
| `promo` | Reclame | |
| `spam` | AI-Spam | |
| verdacht of confidence < 0.7 | Te checken | |

### 1. Credentials aanmaken

Maak in n8n (**Credentials → Add credential**) deze credentials aan. De namen komen overeen met de export, zodat je ze na import makkelijk herkent:

| Naam | Type | Gebruikt door |
|---|---|---|
| `Gmail (werk)` | Gmail OAuth2 API | Gmail (work), Gmail: get labels, Gmail: add label |
| `Outlook (persoonlijk).` | Microsoft Outlook OAuth2 API | Outlook (personal), Outlook: set category |
| `Anthropic API key` | Header Auth, name `x-api-key`, value = API-key | Claude: classify |
| `Calendar (werk)` | Google Calendar OAuth2 API | Calendar: reminder |

Gebruik als OAuth redirect URL `<WEBHOOK_URL>rest/oauth2-credential/callback`.

### 2. Gmail-labels aanmaken

Maak in Gmail de labels **Te betalen**, **Reclame**, **Te checken** en **AI-Spam** aan. Bestaat een label niet, dan faalt de node *Attach label IDs*. Outlook-categorieën worden automatisch gezet.

### 3. Workflow importeren

Via de UI: **Workflows → Import from file** → `workflows/ai-inbox-agent.json`.

Of via de CLI:

```bash
docker compose cp workflows/ai-inbox-agent.json n8n:/tmp/ai-inbox-agent.json
docker compose exec n8n n8n import:workflow --input=/tmp/ai-inbox-agent.json
```

### 4. Credentials koppelen, testen en activeren

1. Open de workflow en kies bij elke node met een credential (7 nodes) de juiste credential.
2. Stuur een testmail en klik **Execute workflow**; controleer per node de output.
3. Klik **Publish** om de workflow te activeren.

### Instellingen

| Wat | Waar |
|---|---|
| Drempel voor "Te checken", dagen herinnering vooraf | `CONFIG` in node **Parse AI result** |
| Labelnamen per categorie | `LABELS` in node **Parse AI result** |
| Classificatieregels (systeemprompt) | `system` in node **Normalize + prompt** |
| Claude-model (`claude-haiku-5-5`) en `max_tokens` | `requestBody` in node **Normalize + prompt** |
| Poll-interval | De trigger-nodes **Gmail (work)** en **Outlook (personal)** |

### Export bijwerken

Na een wijziging in n8n de export verversen, zonder credential-ID's en instance-metadata:

```bash
docker compose exec n8n n8n export:workflow --all --output=/tmp/export.json
docker compose cp n8n:/tmp/export.json /tmp/export.json
jq '.[] | select(.name == "AI Inbox Agent")
  | {name, nodes: (.nodes | map(if .credentials then .credentials |= map_values(del(.id)) else . end)),
     connections, settings: {executionOrder: .settings.executionOrder}, pinData: {}, active: false, tags: []}' \
  /tmp/export.json > workflows/ai-inbox-agent.json
rm /tmp/export.json
```

Controleer daarna met `git diff` dat er geen ID's of secrets in staan.
