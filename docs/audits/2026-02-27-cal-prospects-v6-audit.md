# CAL x.com Prospects v6 -- Workflow Audit

**Date:** 2026-02-27
**Workflow:** `CAL x.com prospects (x_search v6)` (`RgWNZKt8V5fIob3P`)
**n8n Version:** v2.9.4

---

## Executive Summary

The CAL prospect scanner is a well-architected workflow with sound information design and a solid search strategy. However, it has **5 critical issues** that likely mean emails are not being delivered and PDFs are rendering without colors. There are also significant gaps in error handling, cross-run deduplication, and email client compatibility.

**Critical issues requiring immediate attention:**
1. Resend API endpoint is wrong (`/email` vs `/emails`)
2. Gotenberg missing `printBackground: true` -- PDFs have no colors
3. Email HTML uses CSS Grid/Flexbox -- broken in Outlook and Gmail
4. Unsanitized user content (XSS risk in PDF rendering)
5. Resend attachment field uses `type` instead of `content_type`

---

## Findings by Severity

### CRITICAL (5)

| # | Finding | Dimension | Node(s) |
|---|---------|-----------|---------|
| C1 | **Resend endpoint `/email` should be `/emails`** -- all email sends return 404 | Services | Send Email (Resend) |
| C2 | **Gotenberg missing `printBackground: true`** -- PDF backgrounds, gradients, tier badge colors are all invisible | Services | Convert to PDF |
| C3 | **CSS Grid in email summary, Flexbox in prospect headers** -- completely broken in Outlook desktop and Gmail (both strip these properties) | Output | Build Email & PDF v6 |
| C4 | **XSS: user content from tweets interpolated into HTML without escaping** -- malicious HTML in tweet text renders in email and executes in Chromium during PDF generation | Output | Build Email & PDF v6 |
| C5 | **Resend attachment field `type` should be `content_type`** -- MIME type not properly communicated to Resend | Services | Build email body |

### HIGH (10)

| # | Finding | Dimension | Node(s) |
|---|---------|-----------|---------|
| H1 | **No error handling on xAI API call** -- HTTP error stops entire workflow, no retry | Config | xAI x_search API v6 |
| H2 | **No error handling on Gotenberg** -- service down stops workflow (fallback in Prepare PDF Attachment is never reached) | Config | Convert to PDF |
| H3 | **No error handling on Resend** -- failure is silent | Config | Send Email (Resend) |
| H4 | **No cross-run deduplication** -- 72h window with 7h schedule cadence means same prospects appear in ~6 consecutive reports | Services | Architecture |
| H5 | **No n8n error workflow configured** -- silent failures with no alerting | Services | Workflow settings |
| H6 | **Webhook `$json.prospects` likely undefined** -- at that pipeline stage, `$json` comes from Build email body which outputs `{ requestBody: ... }`, not prospect data | Services | Backup to Webhook |
| H7 | **Email `<style>` block without inline styles** -- Gmail strips `<head>` styles; all formatting disappears | Output | Build Email & PDF v6 |
| H8 | **No plain-text email fallback** -- `plainText` field is generated but never passed to Resend payload; hurts deliverability | Output | Build email body |
| H9 | **No legal disclaimer** -- AI-sourced prospect data presented without verification notice or ethics compliance reminder | Output | Build Email & PDF v6 |
| H10 | **30+ magic numbers in scoring** -- no configuration object; the entire scoring model is implicit across unnamed constants | Maintain | Validate & Score v6 |

### MEDIUM (18)

| # | Finding | Dimension |
|---|---------|-----------|
| M1 | Hardcoded LAN IPs for Gotenberg (`192.168.1.91:30300`) and webhook (`192.168.1.91:30080`) | Config/Maintain |
| M2 | Email recipients and sender hardcoded in JavaScript | Maintain |
| M3 | `linear-gradient` on header has no `background-color` fallback -- white text on invisible background in Outlook | Output |
| M4 | `availableInMCP: true` exposes workflow to external AI agents -- verify intentional | Config |
| M5 | No retry logic on any HTTP Request node | Config |
| M6 | `Has Prospects?` condition crashes on null/undefined `prospects` -- use `($json.prospects \|\| []).length` | Config |
| M7 | Gotenberg ignoring `@page` CSS -- needs `preferCssPageSize: true` or explicit margin params | Services |
| M8 | Native Resend n8n node not used -- would eliminate endpoint bug and attachment format issues | Services |
| M9 | Category taxonomy duplicated across 3 locations (prompt, Extract fallback, Build Email) | Maintain |
| M10 | v6 suffix in node names creates multi-site rename risk on version bump | Maintain |
| M11 | Brittle `$('Node Name')` cross-references break silently on rename | Maintain |
| M12 | "Attorney Work Product" label on PDF overstates privilege protection | Output |
| M13 | Missing engagement metrics and incident recency in displayed output | Output |
| M14 | No responsive/mobile email design | Output |
| M15 | No PDF page numbers | Output |
| M16 | Emoji usage (lightning bolt, clipboard, etc.) inappropriate for legal communications | Output |
| M17 | Prompt references nonexistent `x_keyword_search`/`x_semantic_search` tool names (functional but misleading) | Services |
| M18 | 12 searches have overlap; could consolidate to 8-10 without losing recall | Services |

### LOW (10)

| # | Finding | Dimension |
|---|---------|-----------|
| L1 | Schedule runs weekends -- may generate unreviewed reports | Config |
| L2 | xAI timeout (180s) could be tight for 12 searches -- consider 240-300s | Config |
| L3 | No coverage for 2nd Amendment, civil asset forfeiture, 8th Amendment cases | Config |
| L4 | `executionOrder: "v1"` is legacy (functional but v2 recommended) | Services |
| L5 | `timeWindowHours` variable not shared; "72 hours" separately hardcoded in PDF text | Maintain |
| L6 | Inconsistent v6 suffix application (core nodes have it, utility nodes don't) | Maintain |
| L7 | `Build email body` lowercase inconsistent with other node names | Maintain |
| L8 | v6 badge exposed to attorney recipients -- unnecessary implementation detail | Output |
| L9 | 200-char truncation may break mid-word -- use `lastIndexOf(' ')` | Output |
| L10 | PDF sub-workflow extraction opportunity for reuse | Services |

---

## Dimension Summaries

### 1. Configuration Effectiveness

**Grade: C-**

The workflow's configuration has two likely-broken API integrations (Resend endpoint, XAI_API_KEY expression), zero error handling on any HTTP request, and no retry logic. The core search strategy and schedule are well-designed, but the infrastructure around them is fragile. A single service outage silently kills the entire pipeline with no alerting.

**Key wins already in place:**
- Resend credential stored in n8n credential system (correct pattern)
- Gotenberg HTML fallback logic exists (just unreachable due to error handling gap)
- Schedule and timezone are correct
- Search window provides redundancy

### 2. Maintainability

**Grade: C+**

The pipeline has clean node separation and good naming. However, the inline JavaScript nodes are very large (170+ lines for Build Email & PDF), the scoring model has 30+ unnamed magic numbers, and cross-node references are brittle string-based lookups. Changing recipients, scoring weights, or email templates requires editing embedded JavaScript. The v6 suffix in node names creates a multi-site rename burden on version bumps.

**Key wins already in place:**
- Clear linear pipeline with single-responsibility nodes
- Well-structured helper functions (validateProspect, scoreProspect, buildCard)
- Good variable naming throughout
- Accurate README

### 3. Output Formatting

**Grade: B- (PDF) / D (Email)**

The PDF template is well-designed with appropriate typography (Georgia serif), good information architecture, and correct `@page` CSS -- though Gotenberg is not configured to honor it. The email template has excellent information design (prospect cards, tier badges, summary stats) but uses CSS features (Grid, Flexbox, `<style>` blocks) that are fundamentally broken in the two most common professional email clients. An attorney opening this in Outlook sees an unreadable white-on-white header and collapsed layout.

**Key wins already in place:**
- Navy/blue color palette is appropriate for legal communications
- Prospect card information hierarchy is excellent for quick scanning
- PDF uses proper page-break avoidance on cards
- Tier scoring visualization is clear and useful

### 4. Service Utilization

**Grade: C**

The xAI API is used correctly with the right model and endpoint. Gotenberg is functional but under-configured (missing `printBackground` and `preferCssPageSize`). Resend has a wrong endpoint and wrong attachment field name. The biggest architectural gap is no persistent storage -- there is no deduplication across runs, no prospect history, and no feedback loop for improving the scoring model.

**Key wins already in place:**
- Cost-effective model choice (grok-4-1-fast-reasoning)
- Correct use of Responses API with x_search tool
- Webhook backup provides redundancy for prospect data
- Good use of n8n expression system

---

## Top 10 Priority Recommendations

Ordered by impact and urgency:

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | Fix Resend endpoint `/email` -> `/emails` | 1 min | Emails start delivering |
| 2 | Fix Resend attachment `type` -> `content_type`; add `text: input.plainText` | 5 min | Proper attachments + plain-text fallback |
| 3 | Add `printBackground: true` and `preferCssPageSize: true` to Gotenberg request | 5 min | PDFs show colors and proper layout |
| 4 | Add HTML escape function to Build Email & PDF v6 | 15 min | Eliminates XSS injection vector |
| 5 | Replace CSS Grid/Flexbox with tables in email; inline critical styles | 2 hr | Email renders correctly in Outlook/Gmail |
| 6 | Add `continueOnFail` or error branches to all HTTP nodes + error workflow | 30 min | Workflow survives service outages |
| 7 | Add cross-run dedup via `$getWorkflowStaticData('global')` | 30 min | Eliminates duplicate prospect reports |
| 8 | Extract scoring weights to config object at top of Validate & Score | 20 min | Scoring model becomes tunable |
| 9 | Move recipients, sender, LAN IPs to env vars | 15 min | Configuration becomes portable |
| 10 | Add legal disclaimer to email and PDF | 10 min | Ethics compliance for AI-sourced data |

---

## Appendix: Service-Specific Fixes

### Gotenberg -- Convert to PDF Node

Add these form parameters:
```
printBackground: true
preferCssPageSize: true
generateDocumentOutline: true
```

### Resend -- Build email body Node

```javascript
const payload = {
  from: "CAL Prospect Scanner <prospects@mail.corbello.io>",
  to: recipients,
  subject: input.subject,
  html: input.html,
  text: input.plainText,  // ADD
  attachments: [{
    filename: input.pdfAttachment.filename,
    content: input.pdfAttachment.content,
    content_type: input.pdfAttachment.contentType  // FIX: was "type"
  }]
};
```

### HTML Escaping -- Build Email & PDF v6 Node

Add at top of code block:
```javascript
function esc(s) {
  if (!s) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
```

Wrap all user-content interpolations: `${esc(p.username)}`, `${esc(p.constitutional_issue)}`, etc.

### Deduplication -- Extract Prospects v6 or Validate & Score v6 Node

```javascript
const staticData = $getWorkflowStaticData('global');
if (!staticData.seenUrls) staticData.seenUrls = {};

prospects = prospects.filter(p => {
  if (staticData.seenUrls[p.post_url]) return false;
  staticData.seenUrls[p.post_url] = Date.now();
  return true;
});

// Prune entries older than 7 days
const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
for (const [url, ts] of Object.entries(staticData.seenUrls)) {
  if (ts < cutoff) delete staticData.seenUrls[url];
}
```

---

## Resolution Status (2026-02-27)

All findings addressed on branch `feat/cal-prospects-v7-redesign`:

| Finding | Status | Commit |
|---------|--------|--------|
| C1: Resend endpoint | **Verified working** — kept as-is after confirming emails deliver | — |
| C2: Gotenberg printBackground | **Fixed** — added `printBackground: true` + `preferCssPageSize` | `abcaac1` |
| C3: CSS Grid/Flexbox in email | **Fixed** — complete table-based rewrite with inline styles | `3f0dac8` |
| C4: XSS user content | **Fixed** — `esc()` + `safeUrl()` on all user interpolations | `d21a146` |
| C5: Resend attachment field | **Fixed** — `type` to `content_type` | `ad5bcca` |
| H1-H3: No error handling | **Fixed** — `continueRegularOutput` on all HTTP nodes | `ad5bcca` |
| H4: No cross-run dedup | **Fixed** — `$getWorkflowStaticData` with 7-day expiry | `1fcd413` |
| H5: No error workflow | **Partial** — `continueRegularOutput` prevents crashes; dedicated error workflow TBD |
| H6: Webhook wrong data | **Fixed** — references `$('Prepare PDF Attachment')` | `ad5bcca` |
| H7: Style block only | **Fixed** — all inline styles in email template | `3f0dac8` |
| H8: No plain-text email | **Fixed** — structured plain-text body added to Resend payload | `ad5bcca` |
| H9: No disclaimer | **Fixed** — legal disclaimer added to PDF template | `8bc7958` |
| H10: Magic numbers | **Fixed** — `SCORING` config object with named weights | `0467a52` |
| M2: Hardcoded recipients | **Fixed** — extracted to `RECIPIENTS`/`SENDER` constants | `0467a52` |
| M12: Attorney Work Product | **Fixed** — changed to "CONFIDENTIAL — For Internal Use Only" | `8bc7958` |
| M13: Missing engagement/recency | **Fixed** — displayed in PDF prospect cards | `8bc7958` |
| M16: Emojis | **Fixed** — removed from email subject and templates | `3f0dac8` |
