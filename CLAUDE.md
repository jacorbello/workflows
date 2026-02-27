# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

n8n workflow automation repository for the Corbello homelab and business operations. Contains workflow JSON definitions that are imported into n8n (https://n8n.corbello.io, v2.9.4, LXC CT 112 on cortech-node5).

## Repository Structure

- `n8n/<workflow-name>/` — Each workflow gets its own directory with a `workflow.json` and `README.md`
- `docs/` — Runbooks and documentation
- `scripts/` — Helper scripts (export, import, backup)

There is no build system, package manager, or test framework. This is a pure workflow definition repository.

## Working with Workflows

Workflow JSON files are n8n export format. They can be imported via the n8n UI or API. When editing `workflow.json` files, preserve the n8n schema structure (nodes, connections, settings, pinData).

## Conventions

- **Commits:** Conventional commit format with scope — `feat(cal-prospects):`, `chore:`, etc.
- **Workflow naming:** Include version suffix (e.g., "x_search v6")
- **Node naming:** Descriptive names with version suffix (e.g., "Build xAI Prompt v6", "Extract Prospects v6")
- **Credentials:** Never committed. API keys use environment variable placeholders (e.g., `XAI_API_KEY`). Secrets go in `.env`, `credentials/`, or `secrets/` (all gitignored).
- **Timezone:** America/Chicago (CST) for all schedules

## Active Workflows

### CAL x.com Prospects (`n8n/cal-prospects/`)
Constitutional law prospect scanner. Searches X/Twitter via xAI Grok `x_search` for civil rights case leads, validates and scores them (0-100), generates PDF reports via Gotenberg, and emails via Resend. Runs at 8 AM and 3 PM CST.

**External dependencies:** xAI API, Gotenberg (`192.168.1.91:30300`), Resend API, webhook receiver (`192.168.1.91:30080`).
