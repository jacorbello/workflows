# CAL Prospects v7 Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all audit findings and redesign email/PDF templates with an "Editorial Intelligence" aesthetic for the CAL prospect scanner workflow.

**Architecture:** Single workflow.json file containing all n8n node definitions. Each task modifies specific node(s) within this file. Changes are made by editing the JavaScript code strings inside node `parameters.jsCode` fields or node configuration objects. The file is at `n8n/cal-prospects/workflow.json`.

**Tech Stack:** n8n workflow JSON, inline JavaScript (ES2020), HTML/CSS (email: table-based inline styles; PDF: full CSS via Gotenberg/Chromium)

**Reference:** Audit findings at `docs/audits/2026-02-27-cal-prospects-v6-audit.md`

---

### Task 1: Extract Configuration & Fix Scoring Model

**Fixes:** H10, M2, M1, L5 from audit

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — nodes: `Build xAI Prompt v6`, `Validate & Score v6`, `Build email body`

**Step 1: Add config block to Build xAI Prompt v6**

In the `Build xAI Prompt v6` node's `jsCode`, add a configuration section at the very top before existing code:

```javascript
// ============================================================================
// CAL PROSPECTS v6 — CONFIG
// ============================================================================
const CONFIG = {
  timeWindowHours: 72,
  expectedSearches: { keyword: 6, semantic: 6, total: 12 },
  model: 'grok-4-1-fast-reasoning',
};
```

Then replace `const timeWindowHours = 72;` with `const timeWindowHours = CONFIG.timeWindowHours;` and update the `expectedSearches` return value to use `CONFIG.expectedSearches`. Also add `model: CONFIG.model` to the return json so downstream nodes can reference it.

**Step 2: Extract scoring config in Validate & Score v6**

Replace all magic numbers at the top of the `Validate & Score v6` jsCode with a config object:

```javascript
// ============================================================================
// CAL PROSPECTS v6 — SCORING CONFIG
// ============================================================================
const SCORING = {
  baseScore: 50,
  weights: {
    violationClarity: { max: 20, perMatch: 4 },
    governmentNexus: { max: 20, perMatch: 5 },
    helpSeeking: { strong: 15, weak: 10 },
    firstPerson: 5,
    damages: 10,
    recency: { today: 10, yesterday: 7, thisWeek: 5 },
    specificDetails: { max: 10, officer: 4, department: 3, location: 3 },
    engagement: { highThreshold: 500, lowThreshold: 50, highPenalty: -10, lowBonus: 5 },
  },
  tiers: { high: 85, medium: 65 },
};
```

Then refactor `scoreProspect()` to read from `SCORING` instead of inline numbers. The function structure stays the same — just replace literals with config references.

**Step 3: Extract recipients and sender in Build email body**

Replace the hardcoded arrays with a config block:

```javascript
// ============================================================================
// CONFIG
// ============================================================================
const RECIPIENTS = [
  "jacorbello@gmail.com",
  "ccorbello@libertycenter.org",
];
const SENDER = "CAL Prospect Scanner <prospects@mail.corbello.io>";
```

Update the payload to use `SENDER` and `RECIPIENTS`.

**Step 4: Commit**

```
feat(cal-prospects): extract configuration constants and scoring model
```

---

### Task 2: Security — HTML Escaping

**Fixes:** C4 from audit (XSS in user content)

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Build Email & PDF v6`

**Step 1: Add escape utility at top of Build Email & PDF v6 jsCode**

```javascript
function esc(s) {
  if (!s) return '';
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
```

**Step 2: Wrap all user-content interpolations**

Find every place where prospect fields are interpolated into HTML and wrap with `esc()`:

- `p.username` → `esc(p.username)`
- `p.constitutional_issue` → `esc(p.constitutional_issue)`
- `p.full_text` → `esc(p.full_text)`
- `p.issue_details` → `esc(p.issue_details)`
- `p.viability_reasoning` → `esc(p.viability_reasoning)`
- `p.category` → `esc(p.category)`
- `p.incident_recency` → `esc(p.incident_recency)`

For `p.post_url` used in `href` attributes, validate it starts with `https://x.com/` or `https://twitter.com/` before inserting. For all other URL contexts, use `esc()`.

For strength factors: `p.strength_factors.map(f => ...)` — wrap `f` with `esc(f)`.

**Step 3: Commit**

```
fix(cal-prospects): add HTML escaping for user-generated content
```

---

### Task 3: Cross-Run Deduplication

**Fixes:** H4 from audit

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Extract Prospects v6`

**Step 1: Add deduplication logic after the existing within-run dedup**

After the existing `seen` Set dedup block, add:

```javascript
// Cross-run deduplication using n8n static data
const staticData = $getWorkflowStaticData('global');
if (!staticData.seenUrls) staticData.seenUrls = {};

const beforeDedup = prospects.length;
prospects = prospects.filter(p => {
  if (staticData.seenUrls[p.post_url]) return false;
  staticData.seenUrls[p.post_url] = Date.now();
  return true;
});
const dedupRemoved = beforeDedup - prospects.length;

// Prune entries older than 7 days
const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
for (const [url, ts] of Object.entries(staticData.seenUrls)) {
  if (ts < cutoff) delete staticData.seenUrls[url];
}
```

Update the stats in the return object to include `dedupRemoved` count.

**Step 2: Commit**

```
feat(cal-prospects): add cross-run deduplication via static data
```

---

### Task 4: Redesign PDF Template — Editorial Intelligence

**Fixes:** M15 (page numbers), M12 (disclaimer), M13 (engagement/recency), M16 (emojis), plus design overhaul

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Build Email & PDF v6`

**Step 1: Replace the entire pdfHtml template**

Replace the `pdfHtml` variable and its construction with the new Editorial Intelligence design. Key design specs:

**Color Palette:**
- Primary navy: `#0f1b2d`
- Gold accent: `#c5a55a`
- Card bg: `#f8f9fa`
- HIGH tier: `#1a5c4c` (teal-green)
- MEDIUM tier: `#946b2d` (amber)
- LOW tier: `#64748b` (slate)
- Text: `#1a1a1a`
- Muted text: `#64748b`

**CSS Structure:**
```css
@page {
  size: A4;
  margin: 0.75in 0.75in 1in 0.75in;
}
body {
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 11pt;
  line-height: 1.7;
  color: #1a1a1a;
  margin: 0;
  padding: 0;
}
.header {
  background: #0f1b2d;
  color: #ffffff;
  padding: 40px 0;
  margin: -0.75in -0.75in 30px -0.75in;
  padding: 40px 0.75in 30px 0.75in;
}
.header h1 {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 11pt;
  font-weight: 400;
  letter-spacing: 3px;
  text-transform: uppercase;
  color: #c5a55a;
  margin: 0 0 8px 0;
}
.header h2 {
  font-family: Georgia, serif;
  font-size: 22pt;
  font-weight: 400;
  color: #ffffff;
  margin: 0 0 15px 0;
}
.header-meta {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 9pt;
  color: rgba(255,255,255,0.6);
  letter-spacing: 1px;
}
.summary-bar {
  display: flex;
  justify-content: space-between;
  border-bottom: 2px solid #0f1b2d;
  padding-bottom: 15px;
  margin-bottom: 30px;
}
.summary-stat {
  text-align: center;
}
.summary-stat .value {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 28pt;
  font-weight: 700;
  color: #0f1b2d;
}
.summary-stat .label {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8pt;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: #64748b;
}
.section-header {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 9pt;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: #0f1b2d;
  border-bottom: 1px solid #c5a55a;
  padding-bottom: 8px;
  margin: 35px 0 20px 0;
}
.prospect-card {
  background: #f8f9fa;
  border-left: 4px solid #1a5c4c;
  padding: 25px 25px 20px 25px;
  margin: 0 0 20px 0;
  page-break-inside: avoid;
  break-inside: avoid;
}
.prospect-card.medium { border-left-color: #946b2d; }
.prospect-card.low { border-left-color: #64748b; }
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 12px;
}
.card-username {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 14pt;
  font-weight: 700;
  color: #0f1b2d;
}
.card-score {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 10pt;
  font-weight: 700;
  padding: 3px 12px;
  border-radius: 3px;
  color: #fff;
}
.card-score.high { background: #1a5c4c; }
.card-score.medium { background: #946b2d; }
.card-score.low { background: #64748b; }
.card-category {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8pt;
  text-transform: uppercase;
  letter-spacing: 2px;
  color: #64748b;
  margin-bottom: 12px;
}
.card-meta {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8.5pt;
  color: #64748b;
  margin-bottom: 12px;
}
.field-label {
  font-weight: 700;
  color: #0f1b2d;
  font-size: 9pt;
  text-transform: uppercase;
  letter-spacing: 1px;
}
.post-text {
  background: #ffffff;
  border-left: 3px solid #c5a55a;
  padding: 15px 20px;
  margin: 12px 0;
  font-style: italic;
  font-size: 10.5pt;
  line-height: 1.6;
  color: #374151;
}
.factors {
  margin-top: 12px;
}
.factor {
  display: inline-block;
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8pt;
  background: #e2e8f0;
  color: #374151;
  padding: 2px 8px;
  border-radius: 2px;
  margin: 2px 4px 2px 0;
}
.card-url {
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 9pt;
  color: #2563eb;
  word-break: break-all;
  margin-top: 12px;
}
.disclaimer {
  margin-top: 40px;
  padding: 15px 20px;
  border: 1px solid #e2e8f0;
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8pt;
  color: #64748b;
  line-height: 1.5;
}
.footer {
  margin-top: 30px;
  padding-top: 15px;
  border-top: 1px solid #c5a55a;
  font-family: -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif;
  font-size: 8pt;
  color: #64748b;
  text-align: center;
}
```

**HTML Structure:**
```html
<div class="header">
  <h1>CAL Constitutional Law Firm</h1>
  <h2>Prospect Intelligence Brief</h2>
  <div class="header-meta">
    ${date} · ${time} CST · Last ${timeWindowHours} hours · ${searchCalls}/${expectedSearches} searches · Run #${executionId}
  </div>
</div>

<div class="summary-bar">
  <div class="summary-stat">
    <div class="value">${validated}</div>
    <div class="label">Prospects</div>
  </div>
  <div class="summary-stat">
    <div class="value">${high}</div>
    <div class="label">High</div>
  </div>
  <div class="summary-stat">
    <div class="value">${medium}</div>
    <div class="label">Medium</div>
  </div>
  <div class="summary-stat">
    <div class="value">${low}</div>
    <div class="label">Low</div>
  </div>
</div>

<!-- For each tier section: -->
<div class="section-header">HIGH PRIORITY (${count})</div>

<!-- For each prospect: -->
<div class="prospect-card high">
  <div class="card-header">
    <span class="card-username">${esc(username)}</span>
    <span class="card-score high">${tier} (${score})</span>
  </div>
  <div class="card-category">${esc(category)}</div>
  <div class="card-meta">${esc(incident_recency)} · ${likes} likes · ${replies} replies</div>

  <p><span class="field-label">Issue</span><br>${esc(constitutional_issue)}</p>

  ${full_text ? `<div class="post-text">"${esc(full_text)}"</div>` : ''}

  ${issue_details ? `<p><span class="field-label">Details</span><br>${esc(issue_details)}</p>` : ''}

  ${viability_reasoning ? `<p><span class="field-label">Assessment</span><br>${esc(viability_reasoning)}</p>` : ''}

  <div class="factors">
    <span class="field-label">Factors</span>
    ${factors.map(f => `<span class="factor">${esc(f)}</span>`).join('')}
  </div>

  <div class="card-url">${esc(post_url)}</div>
</div>

<!-- After all prospects: -->
<div class="disclaimer">
  <strong>NOTICE:</strong> This report is generated by an automated monitoring system. All prospect information is sourced from publicly available social media posts and has not been independently verified. Viability scores are algorithmic estimates and do not constitute legal analysis. Any outreach to identified individuals must comply with applicable rules of professional conduct regarding solicitation.
</div>

<div class="footer">
  CONFIDENTIAL — For Internal Use Only · CAL v6 · Report #${executionId}
</div>
```

**Step 2: Update the `buildCard()` helper function**

The existing `buildCard(p, tier)` function should be replaced to match the new template structure above. Include engagement metrics and incident recency which were previously omitted.

**Step 3: Verify the date/time formatting** uses the same `date` and `time` variables already defined at the top of the node.

**Step 4: Commit**

```
feat(cal-prospects): redesign PDF template — editorial intelligence
```

---

### Task 5: Redesign Email Template — Table-Based for Client Compatibility

**Fixes:** C3, H7, M3, M14, M16 from audit

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Build Email & PDF v6`

**Step 1: Replace the entire email `html` template**

The email template must be built entirely with:
- `<table>` layout (no Grid, no Flexbox)
- Inline `style` attributes on every element
- Solid `background-color` (no gradients as primary — use as progressive enhancement only)
- VML-safe patterns for Outlook

**Design tokens (inline everywhere, no CSS variables):**
- Navy: `#0f1b2d`
- Gold: `#c5a55a`
- Card bg: `#f8f9fa`
- HIGH teal: `#1a5c4c`
- MEDIUM amber: `#946b2d`
- LOW slate: `#64748b`
- Text: `#1a1a1a`
- Muted: `#64748b`

**Email HTML structure:**

```html
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CAL Prospect Intelligence Brief</title>
  <!--[if mso]>
  <style>table { border-collapse: collapse; }</style>
  <![endif]-->
</head>
<body style="margin:0; padding:0; background-color:#f0f0f0; font-family:Georgia,'Times New Roman',serif;">

<!-- Outer wrapper for centering -->
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f0f0f0;">
<tr><td align="center" style="padding:20px 0;">

<!-- Inner container 640px -->
<table width="640" cellpadding="0" cellspacing="0" border="0" style="max-width:640px; width:100%; background-color:#ffffff;">

  <!-- HEADER: Dark navy block -->
  <tr>
    <td style="background-color:#0f1b2d; padding:30px 35px 25px 35px;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:11px; letter-spacing:3px; text-transform:uppercase; color:#c5a55a; padding-bottom:6px;">
            CAL Constitutional Law Firm
          </td>
        </tr>
        <tr>
          <td style="font-family:Georgia,serif; font-size:24px; color:#ffffff; padding-bottom:12px;">
            Prospect Intelligence Brief
          </td>
        </tr>
        <tr>
          <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:11px; color:rgba(255,255,255,0.5); letter-spacing:1px;">
            ${date} · ${time} CST
          </td>
        </tr>
      </table>
    </td>
  </tr>

  <!-- ALERT BANNER (if high priority) -->
  <!-- Only shown when hasHighPriority is true -->
  <tr>
    <td style="background-color:#1a5c4c; padding:12px 35px; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:13px; font-weight:700; color:#ffffff; text-align:center; letter-spacing:1px;">
      ${highCount} HIGH-PRIORITY PROSPECT${highCount > 1 ? 'S' : ''} IDENTIFIED
    </td>
  </tr>

  <!-- SUMMARY STATS: 4-column table -->
  <tr>
    <td style="padding:25px 35px; border-bottom:2px solid #0f1b2d;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0">
        <tr>
          <td width="25%" align="center" style="padding:8px;">
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:28px; font-weight:700; color:#0f1b2d;">${validated}</div>
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:9px; text-transform:uppercase; letter-spacing:2px; color:#64748b;">Prospects</div>
          </td>
          <td width="25%" align="center" style="padding:8px;">
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:28px; font-weight:700; color:#1a5c4c;">${high}</div>
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:9px; text-transform:uppercase; letter-spacing:2px; color:#64748b;">High</div>
          </td>
          <td width="25%" align="center" style="padding:8px;">
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:28px; font-weight:700; color:#946b2d;">${medium}</div>
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:9px; text-transform:uppercase; letter-spacing:2px; color:#64748b;">Medium</div>
          </td>
          <td width="25%" align="center" style="padding:8px;">
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:28px; font-weight:700; color:#0f1b2d;">${searches}</div>
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:9px; text-transform:uppercase; letter-spacing:2px; color:#64748b;">Searches</div>
          </td>
        </tr>
      </table>
    </td>
  </tr>

  <!-- PDF NOTE -->
  <tr>
    <td style="padding:15px 35px; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:12px; color:#64748b; text-align:center; border-bottom:1px solid #e2e8f0;">
      Detailed report attached as PDF
    </td>
  </tr>

  <!-- PROSPECT CARDS -->
  <!-- For each prospect (High + Medium only, max 10): -->
  <tr>
    <td style="padding:20px 35px 0 35px;">

      <!-- Prospect Card -->
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f8f9fa; border-left:4px solid #1a5c4c; margin-bottom:15px;">
        <tr>
          <td style="padding:20px;">
            <!-- Header row: username + badge -->
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:16px; font-weight:700; color:#0f1b2d;">
                  ${esc(username)}
                </td>
                <td align="right">
                  <span style="display:inline-block; background-color:#1a5c4c; color:#ffffff; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:11px; font-weight:700; padding:3px 10px; border-radius:3px;">
                    ${tier} (${score})
                  </span>
                </td>
              </tr>
            </table>
            <!-- Category -->
            <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:10px; text-transform:uppercase; letter-spacing:2px; color:#64748b; padding:8px 0;">
              ${esc(category)}
            </div>
            <!-- Issue -->
            <div style="font-family:Georgia,serif; font-size:14px; color:#1a1a1a; line-height:1.5; padding-bottom:12px;">
              ${esc(constitutional_issue).substring(0, 200)}${issue.length > 200 ? '...' : ''}
            </div>
            <!-- Factors -->
            <div>
              ${factors.map(f => `<span style="display:inline-block; font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:10px; background-color:#e2e8f0; color:#374151; padding:2px 8px; margin:2px 2px; border-radius:2px;">${esc(f)}</span>`).join('')}
            </div>
            <!-- Link -->
            <div style="padding-top:12px;">
              <a href="${post_url}" style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:12px; color:#2563eb; text-decoration:none; font-weight:600;" target="_blank">View Original Post</a>
            </div>
          </td>
        </tr>
      </table>

    </td>
  </tr>

  <!-- FOOTER -->
  <tr>
    <td style="padding:25px 35px; border-top:1px solid #c5a55a; text-align:center;">
      <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:10px; color:#64748b;">
        CONFIDENTIAL — For Internal Use Only
      </div>
      <div style="font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif; font-size:10px; color:#94a3b8; padding-top:4px;">
        CAL Prospect Scanner · ${searchCalls} searches · ${tokens} tokens
      </div>
    </td>
  </tr>

</table>
</td></tr></table>
</body>
</html>
```

**Step 2: Update email subject line** — remove emoji, use clean format:

```javascript
const subject = hasHighPriority
  ? `CAL Brief: ${highPriority.length} HIGH-PRIORITY + ${summary.validated - highPriority.length} more — ${date}`
  : `CAL Brief: ${summary.validated || 0} prospects — ${date}`;
```

**Step 3: Commit**

```
feat(cal-prospects): redesign email template — table-based editorial intelligence
```

---

### Task 6: Fix Resend Integration

**Fixes:** C5, H8 from audit

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Build email body`

**Step 1: Fix attachment field name and add plain-text body**

In the `Build email body` node's jsCode, update the payload construction:

```javascript
const payload = {
  from: SENDER,
  to: RECIPIENTS,
  subject: input.subject,
  html: input.html,
  text: input.plainText,
  attachments: [{
    filename: input.pdfAttachment.filename,
    content: input.pdfAttachment.content,
    content_type: input.pdfAttachment.contentType
  }]
};
```

**Step 2: Improve the plainText content in Build Email & PDF v6**

Replace the single-line `plainText` with a more useful summary:

```javascript
let plainLines = [`CAL Prospect Intelligence Brief — ${date}, ${time} CST\n`];
plainLines.push(`${summary.validated || 0} prospects found (${summary.by_tier?.high || 0} high, ${summary.by_tier?.medium || 0} medium, ${summary.by_tier?.low || 0} low)\n`);

for (const p of prospects.filter(p => p.viability_tier !== 'Low').slice(0, 10)) {
  plainLines.push(`---`);
  plainLines.push(`${p.username} — ${p.viability_tier} (${p.viability_score}) — ${p.category}`);
  plainLines.push(`${p.constitutional_issue || ''}`);
  plainLines.push(`${p.post_url}\n`);
}

plainLines.push(`---\nDetailed report attached as PDF.\nCONFIDENTIAL — For Internal Use Only`);
const plainText = plainLines.join('\n');
```

**Step 3: Commit**

```
fix(cal-prospects): fix Resend attachment field and add plain-text body
```

---

### Task 7: Fix Gotenberg Configuration

**Fixes:** M7 from audit, improved PDF rendering

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — node: `Convert to PDF`

**Step 1: Add Gotenberg form parameters**

In the `Convert to PDF` node's `bodyParameters.parameters` array, add these additional form fields after the existing `files` parameter:

```json
{
  "parameterType": "formData",
  "name": "preferCssPageSize",
  "value": "true"
},
{
  "parameterType": "formData",
  "name": "printBackground",
  "value": "true"
},
{
  "parameterType": "formData",
  "name": "generateDocumentOutline",
  "value": "true"
}
```

This ensures:
- `preferCssPageSize: true` — honors the `@page { size: A4; margin: 0.75in }` CSS
- `printBackground: true` — renders all background colors (explicitly, even if current behavior seems to work)
- `generateDocumentOutline: true` — creates PDF bookmarks from `<h2>` headings

**Step 2: Commit**

```
fix(cal-prospects): add Gotenberg PDF rendering params
```

---

### Task 8: Add Error Handling & Fix Webhook

**Fixes:** H1, H2, H3, H5, H6, M5, M6 from audit

**Files:**
- Modify: `n8n/cal-prospects/workflow.json` — nodes: `xAI x_search API v6`, `Convert to PDF`, `Send Email (Resend)`, `Backup to Webhook`, `Has Prospects?`, workflow settings

**Step 1: Add `continueOnFail` to HTTP nodes**

For each of the three HTTP Request nodes (`xAI x_search API v6`, `Convert to PDF`, `Send Email (Resend)`) and the webhook node (`Backup to Webhook`), add `"onError": "continueRegularOutput"` to the node's `parameters.options` object. In n8n v2.9.4, this is done by setting:

```json
"options": {
  "response": { ... },
  "timeout": ...,
  "batching": { "batch": { "batchSize": 1 } }
}
```

Actually, in n8n HTTP Request v4.2+, error handling is configured via the node-level `onError` field, not inside parameters. Add to each HTTP Request node:

```json
"onError": "continueRegularOutput"
```

This means if the node errors, it passes the error data downstream instead of halting the workflow.

**Step 2: Fix the Has Prospects? condition**

Change the leftValue expression from:
```
={{ $json.prospects.length }}
```
to:
```
={{ ($json.prospects || []).length }}
```

**Step 3: Fix webhook payload**

In the `Backup to Webhook` node, change `$json.prospects` and `$json.summary` to reference the correct upstream node. The webhook is connected from `Build email body`, but the prospect data comes from `Prepare PDF Attachment`. Change the jsonBody to:

```javascript
={{ JSON.stringify({ source: 'n8n-cal-prospects-v6', timestamp: $now.toISO(), prospects: $('Prepare PDF Attachment').first().json.prospects, summary: $('Prepare PDF Attachment').first().json.summary, hasHighPriority: $('Prepare PDF Attachment').first().json.hasHighPriority, workflow_execution_id: $execution.id }) }}
```

**Step 4: Commit**

```
fix(cal-prospects): add error handling, fix webhook payload and null safety
```

---

### Task 9: Update Audit Document & README

**Files:**
- Modify: `docs/audits/2026-02-27-cal-prospects-v6-audit.md`
- Modify: `n8n/cal-prospects/README.md`

**Step 1: Add resolution notes to audit**

Add a "Resolution Status" section at the bottom of the audit doc noting which findings were fixed in v7.

**Step 2: Update README**

Update the README to reflect changes:
- Note the redesigned templates
- Update the dependencies section if any changed
- Note the deduplication feature
- Note the error handling additions

**Step 3: Commit**

```
docs(cal-prospects): update audit and README with v7 changes
```

---

## Execution Order

Tasks can be executed mostly sequentially. Dependencies:
- Task 1 (config extraction) should be done first — later tasks reference the config pattern
- Task 2 (HTML escaping) must be done before Tasks 4 & 5 (template redesigns) since the templates use `esc()`
- Task 3 (dedup) is independent
- Tasks 4 & 5 (templates) can be done in either order but both modify the same node — do sequentially
- Task 6 (Resend fix) depends on Task 5 (email template) for the improved plainText
- Task 7 (Gotenberg) is independent
- Task 8 (error handling) is independent
- Task 9 (docs) should be last

**Recommended order:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

## Verification

After all tasks, verify the workflow.json is valid:
1. `cat workflow.json | python3 -c "import json,sys; json.load(sys.stdin); print('Valid JSON')"` — confirms no JSON syntax errors
2. Visual review of the HTML templates by extracting and opening in a browser
3. Import into n8n and run a manual execution to verify end-to-end
