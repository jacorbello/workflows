# Workflows

Automation workflows for the Corbello homelab and business operations.

## Structure

```
workflows/
├── n8n/                    # n8n workflow definitions
│   ├── cal-prospects/      # CAL constitutional law prospect scanner
│   ├── monitoring/         # Infrastructure & service monitoring
│   └── automation/         # General automation & integrations
├── docs/                   # Workflow documentation & runbooks
└── scripts/                # Helper scripts (export, import, backup)
```

## n8n Instance

- **URL:** https://n8n.corbello.io
- **Version:** 2.9.4
- **Host:** LXC CT 112 on cortech-node5

## Usage

Workflow JSON files can be imported directly into n8n via the UI or API.
