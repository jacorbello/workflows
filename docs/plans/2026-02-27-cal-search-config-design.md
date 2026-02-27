# CAL Workflow: Configurable Search Parameters

**Date:** 2026-02-27
**Status:** Approved
**Branch:** feat/cal-prospects-v7-redesign

## Problem

The Build xAI Prompt v6 node has all 12 searches (6 keyword + 6 semantic) and the 72-hour time window hardcoded. There is no way to adjust which constitutional areas are searched or what time range is used without editing the node's JavaScript directly.

## Solution

Add a new **Search Config v7** Set node between the Schedule Trigger and Build xAI Prompt. This node exposes editable fields in the n8n UI for toggling search categories and adjusting the time window.

## Search Config v7 Node

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `timeWindowHours` | Number | `72` | How far back to search |
| `policeEncounters` | Boolean | `true` | 4th Amendment — police stops, warrantless search/arrest |
| `cpsParentalRights` | Boolean | `true` | CPS removal + family court |
| `policeMisconduct` | Boolean | `true` | Brutality, excessive force, false arrest |
| `civilRightsGeneral` | Boolean | `true` | Broad civil rights + attorney-seeking |
| `firstAmendment` | Boolean | `true` | Speech, protest, religion (NEW) |

## Connection Change

```
Schedule Trigger → Search Config v7 → Build xAI Prompt v7 → xAI API → ...
```

## Category-to-Search Mapping

### Police Encounters (4th Amendment)
- **KW1:** `(police OR cops OR officer) (help OR lawyer OR advice OR sue OR rights) lang:en -filter:retweets`
- **KW2:** `(arrested OR detained OR searched) (me OR my OR I) (rights OR illegal OR warrant OR reason) lang:en -filter:retweets`
- **SEM1:** "person describing being arrested or searched by police without a warrant, telling their own story, seeking help or legal advice"
- **SEM2:** "person whose constitutional rights were violated by police or government, first person account, recent incident, asking what to do"

### CPS / Parental Rights
- **KW3:** `(CPS OR "child protective services" OR "child welfare") (children OR kids OR son OR daughter OR custody) lang:en -filter:retweets`
- **KW4:** `("family court" OR custody OR "parental rights") (unfair OR corrupt OR help OR advice OR lawyer) lang:en -filter:retweets`
- **SEM3:** "parent whose children were taken or removed by CPS or child protective services, first person account of what happened, asking for help"
- **SEM4:** "person dealing with unfair family court, lost custody unfairly, false allegations, seeking legal help or advice"

### Police Misconduct
- **KW5:** `("police misconduct" OR "excessive force" OR "police brutality" OR "false arrest") lang:en -filter:retweets`
- **SEM5:** "someone who was beaten, hurt, or mistreated by police officers, describing their own experience, looking for advice or a lawyer"

### Civil Rights General
- **KW6:** `("civil rights" OR "constitutional rights" OR "4th amendment") (lawyer OR attorney OR violated OR help) lang:en -filter:retweets`
- **SEM6:** "someone actively looking for a civil rights lawyer or attorney to help with police misconduct, false arrest, or government overreach"

### First Amendment (NEW)
- **KW7:** `("free speech" OR "first amendment" OR protest OR censored) (arrested OR rights OR help OR lawyer) lang:en -filter:retweets`
- **SEM7:** "person whose free speech or protest rights were violated by police or government, arrested for protesting, first person account seeking legal help"

## Build xAI Prompt v7 Changes

The prompt builder reads config from the Set node and conditionally assembles search blocks:

1. Define each category's searches as template objects keyed by config field name
2. Filter to only enabled categories
3. Dynamically number the searches and build prompt sections
4. Calculate `expectedSearches` based on enabled count (not hardcoded 12)

## Downstream Impact

- **Extract Prospects v6:** No changes. Reads `expectedSearches` from prompt node (now dynamic).
- **Validate & Score v6:** No changes. Already handles First Amendment category. Scoring is category-agnostic.
- **Build Email & PDF v6:** No changes. Renders whatever prospects come through.
- **All other nodes:** No changes.

## What Does NOT Change

- Scoring logic, email template, PDF template
- Gotenberg, Resend, webhook integrations
- Prompt structure (instructions, focus criteria, exclusions, output format, verification section)
- Cross-run deduplication logic
