---
description: "Quick check of harmony breaches today"
disable-model-invocation: true
allowed-tools: Bash(python3:*)
---

!`python3 {{PLUGIN_DIR}}/curse-stats.py daily --last 1`

Report today's numbers from the command output above: prompts, harmony breaches, and the
deviation index. Keep it to a line or two. If the breach count is zero, say so cheerfully.
Do not invent numbers that are not in the output.
