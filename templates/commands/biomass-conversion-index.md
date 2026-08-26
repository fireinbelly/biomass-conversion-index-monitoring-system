---
description: "Show biomass conversion index statistics from your prompts"
argument-hint: '[daily|weekly|monthly|hourly] [--last N] [--start YYYY-MM-DD --end YYYY-MM-DD]'
disable-model-invocation: true
allowed-tools: Bash(python3:*)
---

!`python3 {{PLUGIN_DIR}}/curse-stats.py $ARGUMENTS`

Present the command output above to the user verbatim, inside a fenced code block so the
alignment survives. Do not summarize it, re-sort it, or drop rows. If it is empty or an
error, say exactly that rather than inventing numbers.
