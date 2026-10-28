# n8n

Self-hosted n8n (Docker Compose) met drie samenhangende workflows: **AI Inbox Agent**, **Classify email** en **Backlog cleanup**.

```
docker/n8n/
├── docker-compose.yml
├── .env.example                  # template voor .env (echte .env staat in .gitignore)
├── normalize.jq                  # normaliseert een workflow-export voor de repo
└── workflows/                    # exports zonder credential-ID's, instance-metadata of pinData
    ├── ai-inbox-agent.json
    ├── classify-email.json
    └── backlog-cleanup.json
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
   | `N8N_API_URL` | Basis-URL van de n8n API voor n8n-mcp, zonder `/api/v1`. |
   | `N8N_API_KEY` | n8n API-key voor n8n-mcp (**Settings → n8n API**). |

2. Start de container:

   ```bash
   docker compose up -d
   docker compose exec n8n env | grep WEBHOOK   # controle: N8N_WEBHOOK_URL=...
   ```

n8n draait op poort `5678`. Data (workflows, credentials, executions, data tables) staat in het volume `n8n_data`.

## Workflows en samenhang

```
AI Inbox Agent (actief, pollt elke 5 min)        Backlog cleanup (handmatig)
  nieuwe mail Gmail (werk) + Outlook (pers.)       inbox-mail van de laatste 12 maanden,
                │                                  behalve wat al in processed_mails staat
                │                                                 │
                ▼                                                 ▼
        ┌──────────────────── Classify email (sub-workflow) ────────────────────┐
        │  Normalize + prompt ─> Claude: classify ─> Parse AI result            │
        └───────────────────────────────────────────────────────────────────────┘
                │                                                 │
                ▼                                                 ▼
  labels · categorieën · betaalherinneringen     labels · categorieën · betaalherinneringen
                │                                                 │
                └────────────> data table processed_mails <───────┘
```

| Workflow | Bestand | Status | Rol |
|---|---|---|---|
| **AI Inbox Agent** | `workflows/ai-inbox-agent.json` | actief | Pollt Gmail (werk) en Outlook (persoonlijk) elke 5 minuten, laat elke mail classificeren en zet labels, categorieën en betaalherinneringen. Logt verwerkte mail in `processed_mails`. |
| **Classify email** | `workflows/classify-email.json` | actief (sub-workflow) | Gedeelde classificatie: normaliseert een Gmail- of Outlook-mail, vraagt Claude om een categorie en bepaalt het label. Bevat de prompt en de instellingen. |
| **Backlog cleanup** | `workflows/backlog-cleanup.json` | inactief, handmatig | Labelt bestaande inbox-mail van de afgelopen 12 maanden met dezelfde sub-workflow. Slaat mail over die al in `processed_mails` staat. |

Classificatie staat dus op één plek: wijzig je de prompt of de labels in **Classify email**, dan geldt dat voor beide andere workflows.

### Sub-workflow en data table: ID's

De aanroepende nodes verwijzen op ID naar de sub-workflow en de data table:

| Verwijzing | ID op deze instance | Gebruikt door |
|---|---|---|
| Sub-workflow **Classify email** | `Z5CU5y8u5SceiVaq` | AI Inbox Agent: *Classify email* · Backlog cleanup: *Classify Gmail*, *Classify Outlook* |
| Data table **processed_mails** | `vgRGdmoyMQvu195t` | AI Inbox Agent: *Log processed* · Backlog cleanup: *Processed IDs*, *Gmail: log processed*, *Outlook: log processed* |

Op een nieuwe instance krijgen beide andere ID's. Kies ze na import opnieuw in de genoemde nodes.

### Data table `processed_mails`

Alleen de structuur; de inhoud staat niet in de repo.

| Kolom | Type | Inhoud |
|---|---|---|
| `source` | string | `gmail` of `outlook` |
| `messageId` | string | Bericht-ID in Gmail of Outlook |
| `category` | string | Categorie van Claude (`payment_due`, `important`, `promo`, `spam`, `check`) |
| `confidence` | number | Zekerheid van Claude (0–1) |
| `reason` | string | Korte motivatie van Claude |
| `processedAt` | dateTime | Moment van verwerking |

Mail waarbij Claude een fout gaf of een onleesbaar antwoord, wordt niet gelogd en komt bij een volgende run dus opnieuw aan bod.

## Classificatie

**Label-only**: er wordt niets verplaatst of verwijderd.

| Categorie (Claude) | Gmail-label / Outlook-categorie | Extra |
|---|---|---|
| `payment_due` | Te betalen | Ster (Gmail) / vlag (Outlook), agenda-afspraak 2 dagen voor de vervaldatum om 09:00 |
| `important` | geen (blijft gewoon in inbox) | Vacature- en opdrachtmatches vallen hier altijd onder |
| `promo` | Reclame | |
| `spam` | AI-Spam | |
| verdacht of confidence < 0.7 | Te checken | |

## Installatie op een nieuwe instance

### 1. Credentials aanmaken

Maak in n8n (**Credentials → Add credential**) deze credentials aan. De namen komen overeen met de export, zodat je ze na import makkelijk herkent:

| Naam | Type | Gebruikt door |
|---|---|---|
| `Gmail (werk)` | Gmail OAuth2 API | AI Inbox Agent, Backlog cleanup |
| `Outlook (persoonlijk).` | Microsoft Outlook OAuth2 API | AI Inbox Agent, Backlog cleanup |
| `Anthropic API key` | Header Auth, name `x-api-key`, value = API-key | Classify email: *Claude: classify* |
| `Calendar (werk)` | Google Calendar OAuth2 API | AI Inbox Agent, Backlog cleanup |

Gebruik als OAuth redirect URL `<WEBHOOK_URL>rest/oauth2-credential/callback`.

### 2. Gmail-labels en data table aanmaken

- Maak in Gmail de labels **Te betalen**, **Reclame**, **Te checken** en **AI-Spam** aan. Bestaat een label niet, dan faalt de node *Attach label IDs*. Outlook-categorieën worden automatisch gezet.
- Maak in n8n (**Overview → Data tables**) de tabel `processed_mails` aan met de kolommen hierboven.

### 3. Workflows importeren

Importeer **Classify email** eerst, zodat de andere twee ernaar kunnen verwijzen. Via de UI: **Workflows → Import from file**. Of via de CLI:

```bash
for wf in classify-email ai-inbox-agent backlog-cleanup; do
  docker compose cp workflows/$wf.json n8n:/tmp/$wf.json
  docker compose exec n8n n8n import:workflow --input=/tmp/$wf.json
done
```

### 4. Koppelen, testen en activeren

1. Kies bij elke node met een credential de juiste credential.
2. Kies in de nodes uit de ID-tabel hierboven de sub-workflow **Classify email** en de data table **processed_mails**.
3. Stuur een testmail en klik in **AI Inbox Agent** op **Execute workflow**; controleer per node de output.
4. Publiceer **Classify email** en **AI Inbox Agent**. **Backlog cleanup** start je handmatig; begin met `COUNT_ONLY = true` voor een telling en kostenschatting.

## Instellingen

| Wat | Waar |
|---|---|
| Drempel voor "Te checken", dagen herinnering vooraf | `CONFIG` in node **Parse AI result** (Classify email) |
| Labelnamen per categorie | `LABELS` in node **Parse AI result** (Classify email) |
| Classificatieregels (systeemprompt) | `system` in node **Normalize + prompt** (Classify email) |
| Claude-model (`claude-haiku-5-5`) en `max_tokens` | `requestBody` in node **Normalize + prompt** (Classify email) |
| Poll-interval | De trigger-nodes **Gmail (work)** en **Outlook (personal)** (AI Inbox Agent) |
| Omvang en tempo van de backlog-run | Node **Settings** in Backlog cleanup: `LIMIT` (0 = alles), `BATCH_SIZE`, `WAIT_SECONDS`, `OUTLOOK_BATCH_SIZE`, `OUTLOOK_WAIT_SECONDS`, `COUNT_ONLY` |

## Werkafspraak: wijzigen, exporteren, PR

De live instance is leidend; de repo volgt. Elke wijziging gaat zo:

1. **Drift-check (read-only) vooraf.** Controleer dat live en repo gelijk zijn voordat je iets wijzigt. Is er drift, exporteer en commit die dan eerst apart, zodat je eigen wijziging niet vermengd raakt met onbekende wijzigingen.
2. **Wijzigen via n8n-mcp** (vanuit Claude Code) of in de n8n-UI. Test met **Execute workflow** en publiceer.
3. **Exporteren naar de repo** met dezelfde normalisatie.
4. **Secret-check en PR.** Controleer `git diff` op credential-ID's en secrets en dien in met `scripts/submit-change.sh`.

### Drift-check en export

Beide stappen gebruiken `normalize.jq`. `n8n export:workflow` leest alleen uit de database en wijzigt niets in n8n. Run vanuit `docker/n8n/`:

```bash
# Ophalen (read-only) naar een tijdelijke map buiten de repo
tmp=$(mktemp -d)
docker compose exec n8n n8n export:workflow --all --output=/tmp/wf-export.json
docker compose cp n8n:/tmp/wf-export.json "$tmp/all.json"
docker compose exec n8n rm -f /tmp/wf-export.json

# Normaliseren per workflow
for pair in "AI Inbox Agent:ai-inbox-agent" "Classify email:classify-email" "Backlog cleanup:backlog-cleanup"; do
  jq -S --arg n "${pair%%:*}" '.[] | select(.name == $n)' "$tmp/all.json" \
    | jq -S -f normalize.jq > "$tmp/${pair##*:}.json"
done

# Drift-check: lege uitvoer betekent geen drift
for wf in ai-inbox-agent classify-email backlog-cleanup; do
  diff -u "workflows/$wf.json" "$tmp/$wf.json"
done

# Export: alleen na een bewuste wijziging (of om drift vast te leggen)
cp "$tmp"/{ai-inbox-agent,classify-email,backlog-cleanup}.json workflows/
rm -rf "$tmp"
```

`export:workflow` exporteert de draft-versie. Publiceer een wijziging dus voordat je exporteert, anders legt de repo iets vast dat niet live draait.

n8n-mcp's `n8n_get_workflow` (mode `full`) levert na `normalize.jq` exact dezelfde bestanden op, als alternatief voor de CLI.
