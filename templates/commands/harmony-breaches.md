---
description: "Quick check of harmony breaches today"
tools: ["Bash"]
---

# Harmony Breaches Today

```bash
BIOMASS_DATA_DIR="{{DATA_DIR}}" python3 {{PLUGIN_DIR}}/curse-stats.py daily --last 1 | grep -E "(Total|Index)" || echo "No harmony breaches today! 🌿"
```
