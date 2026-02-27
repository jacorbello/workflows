# CAL x.com Prospects (x_search v6)

Constitutional law prospect scanner that searches X/Twitter for potential case leads.

## Schedule

Runs daily at **8 AM** and **3 PM CST**.

## Pipeline

1. **Build xAI Prompt** — 6 keyword + 6 semantic searches targeting civil rights violations, police misconduct, CPS cases, family court issues
2. **xAI x_search API** — Grok `grok-4-1-fast-reasoning` with `x_search` tool (72-hour window)
3. **Extract Prospects** — Parses JSON results with annotation fallback
4. **Validate & Score** — URL validation, fake handle detection, viability scoring (0-100)
5. **Build Email & PDF** — Styled HTML email + Gotenberg PDF report
6. **Send** — Email via Resend API + webhook backup

## Recipients

- `jacorbello@gmail.com`
- `ccorbello@libertycenter.org`

## Scoring Tiers

| Tier | Score | Meaning |
|------|-------|---------|
| High | 85+ | Strong prospect — clear violation, help-seeking, damages |
| Medium | 65-84 | Worth reviewing |
| Low | <65 | Weak signals |

## Dependencies

- xAI API (Grok with x_search)
- Gotenberg (HTML→PDF) at `192.168.1.91:30300`
- Resend API (email delivery)
- Webhook receiver at `192.168.1.91:30080`
