# CAL x.com Prospects (x_search v7)

Constitutional law prospect scanner that searches X/Twitter for potential case leads.

## Schedule

Runs daily at **8 AM** and **3 PM CST**.

## Pipeline

1. **Search Config v7** — Configurable search categories and time window (see [Search Configuration](#search-configuration) below)
2. **Build xAI Prompt** — Assembles keyword + semantic search pairs from enabled categories (up to 14 searches when all enabled)
3. **xAI x_search API** — Grok `grok-4-1-fast-reasoning` with `x_search` tool
4. **Extract Prospects** — Parses JSON results with annotation fallback, cross-run deduplication via n8n static data (7-day window)
5. **Validate & Score** — URL validation, fake handle detection, configurable viability scoring (0-100)
6. **Build Email & PDF** — Editorial Intelligence styled templates: table-based email (Outlook/Gmail safe) + Gotenberg PDF report with HTML escaping on all user content
7. **Send** — Email via Resend API (with plain-text fallback) + webhook backup. Error handling on all HTTP nodes (`continueRegularOutput`).

## Search Configuration

The **Search Config v7** node provides toggleable search categories and a configurable time window. Each enabled category generates one keyword search and one semantic search.

| Category | Toggle | Description |
|----------|--------|-------------|
| Police Encounters | `policeEncounters` | Unlawful arrests, excessive force, rights violations during stops |
| CPS / Parental Rights | `cpsParentalRights` | CPS overreach, parental rights termination, family court issues |
| Police Misconduct | `policeMisconduct` | Officer complaints, cover-ups, department accountability |
| Civil Rights General | `civilRightsGeneral` | Discrimination, due process violations, broad civil rights issues |
| First Amendment | `firstAmendment` | Speech restrictions, protest crackdowns, press freedom violations |

**Time window:** `timeWindowHours` (default: **72** hours) — controls how far back x_search looks for posts.

All categories are **enabled by default**. With all 5 categories on, the prompt assembles **14 total searches** (7 keyword + 7 semantic, including 2 bonus keyword searches for high-value categories).

## Recipients

- `jacorbello@gmail.com`
- `ccorbello@libertycenter.org`

## Scoring Tiers

Scoring weights are configurable via the `SCORING` config object in the Validate & Score node.

| Tier | Score | Meaning |
|------|-------|---------|
| High | 85+ | Strong prospect — clear violation, help-seeking, damages |
| Medium | 65-84 | Worth reviewing |
| Low | <65 | Weak signals |

## Dependencies

- xAI API (Grok with x_search)
- Gotenberg (HTML to PDF) at `192.168.1.91:30300` — with `printBackground`, `preferCssPageSize`, `generateDocumentOutline`
- Resend API (email delivery)
- Webhook receiver at `192.168.1.91:30080`

## v7 Redesign (2026-02-27)

Changes from the v6 audit (`docs/audits/2026-02-27-cal-prospects-v6-audit.md`):

- **Search Config node** — dedicated `Search Config v7` Set node with toggleable search categories (5 categories, 14 searches when all enabled) and configurable `timeWindowHours`
- **Config extraction** — scoring weights, recipients, sender, model name extracted to config objects
- **HTML escaping** — all user content (tweet text, usernames, etc.) escaped to prevent XSS
- **Cross-run dedup** — prospects deduplicated across runs via `$getWorkflowStaticData`, 7-day expiry
- **PDF redesign** — Editorial Intelligence aesthetic: dark navy header, gold accents, engagement/recency display, legal disclaimer
- **Email redesign** — Table-based layout with inline styles for Outlook/Gmail compatibility
- **Resend fix** — attachment `content_type` field, plain-text body added
- **Gotenberg fix** — `printBackground`, `preferCssPageSize`, `generateDocumentOutline` params
- **Error handling** — `continueRegularOutput` on all HTTP nodes, null safety on prospects check
- **Webhook fix** — payload now references correct upstream node data
