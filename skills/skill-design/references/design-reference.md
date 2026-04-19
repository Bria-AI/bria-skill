# Skill Design — Extended Reference

## Domain-Level Effectiveness (from SkillsBench)

Skills help the most in high-knowledge domains where procedural details are hard to derive from general training:

| Domain | Skills Improvement |
|--------|-------------------|
| Healthcare | +51.9pp |
| Finance | +42.8pp |
| Energy | +38.6pp |
| Manufacturing | +35.2pp |
| Media & Content | +24.1pp |
| Software Engineering | +4.5pp (lowest — models already know this) |

**Implication:** If your skill covers an esoteric API, specialized workflow, or domain-specific tool, the procedural
knowledge has high leverage. Generic software tasks benefit less.

---

## Complexity Categories (Measured)

The benchmark categorized skills into four complexity levels:

| Category | Definition | Pass Rate Impact |
|----------|-----------|-----------------|
| **Detailed** | Focused, step-by-step, specific API patterns | **+18.8pp** |
| **Compact** | Short, dense, high signal-to-noise | +17.1pp |
| **Standard** | Average depth, some specificity | +10.1pp |
| **Comprehensive** | Exhaustive, covers everything | **–2.9pp** |

The comprehensive category actively hurts performance because agents struggle to extract relevant
information from lengthy content, and exhaustive skills consume context budget without providing
actionable guidance.

---

## Anti-Pattern Gallery

### ❌ Flat capability table (comprehensive, hurts)
```markdown
| Need | Capability | Use Case |
|------|------------|----------|
| Generate from text | FIBO Generate | Hero images, banners... |
| Edit with text | FIBO-Edit | Change colors, objects... |
| Remove background | RMBG-2.0 | Cutouts, overlays... |
... (18 more rows)
```

### ✅ Decision tree (detailed, helps)
```markdown
## What to Do

Remove background / transparent PNG? → POST /v2/image/edit/remove_background
Generate from scratch?               → POST /v2/image/generate
Edit with text instruction?          → POST /v2/image/edit  (--key images required)
Lifestyle product shot?              → POST /v1/product/lifestyle_shot_by_text
Anything else?                       → See references/capabilities.md
```

---

### ❌ Inlined boilerplate (comprehensive, hurts)
```markdown
## Authenticate
```bash
for i in $(seq 1 60); do
  TOKEN_RESPONSE=$(curl -s -X POST "..." \
    -d "grant_type=..." \
    -d "device_code=$DEVICE_CODE")
  ACCESS_TOKEN=$(printf '%s' "$TOKEN_RESPONSE" | sed -n '...')
  if [ -n "$ACCESS_TOKEN" ]; then
    ...
  fi
  sleep 5
done
```
(30 more lines)
```

### ✅ Delegated to helper script (compact, helps)
```markdown
## Authenticate
```bash
source <SKILL_DIR>/references/code-examples/auth.sh
bria_auth   # prints SIGN_IN_URL and USER_CODE, polls automatically
```
Show user: **[Sign in here]({SIGN_IN_URL})** — code is pre-filled.
```

---

### ❌ Vague procedural guidance (self-generated style, no benefit)
```markdown
## How to Process Data
Use pandas for data processing. Apply the appropriate transformation functions.
Make sure to handle edge cases.
```

### ✅ Specific procedural guidance (detailed, helps)
```markdown
## How to Process Data
```python
import pandas as pd
df = pd.read_csv(input_path, encoding='utf-8-sig')  # handles BOM
df['date'] = pd.to_datetime(df['date'], format='%Y-%m-%d', errors='coerce')
df = df.dropna(subset=['date', 'value'])             # drop unverifiable rows
df.to_csv(output_path, index=False)
```
Common failure: `encoding='utf-8-sig'` is required for Excel-exported CSVs (BOM prefix).
```

---

## Skill Quantity Strategy

When multiple skills are available for a task, 2–3 is the sweet spot:

- **1 skill:** Good (+17.8pp) — enough for focused tasks
- **2–3 skills:** Best (+18.6pp) — allows specialization without overload
- **4+ skills:** Poor (+5.9pp) — agent context gets saturated, conflicting guidance emerges

**Strategy:** Split a large skill into 2 focused ones rather than making one comprehensive skill.
Example: `bria-ai` (core generation/editing) + `bria-ai-products` (lifestyle shots, product integrate).

---

## Skill Injection Mechanics

Skills are loaded from agent-specific directories at runtime:

| Agent Harness | Skills Path |
|---------------|-------------|
| Claude Code | `~/.claude/skills/<skill-name>/` |
| Codex CLI | `~/.codex/skills/<skill-name>/` |
| Gemini CLI | `~/.gemini/skills/<skill-name>/` |
| Generic agents | `~/.agents/skills/<skill-name>/` |

Agents discover skills by reading `SKILL.md` frontmatter (`name`, `description`). Instructions never
reference which skill to use — agents must apply them autonomously based on description matching.

**Implication for description writing:** The `description` field is your only hook for skill selection.
Include explicit trigger phrases: what the user will say, what the task will involve, specific tool names.

---

## Leakage Prevention Checklist

A skill must NOT contain:
- [ ] Task-specific filenames, paths, or identifiers
- [ ] Exact command sequences that solve a specific benchmark instance
- [ ] Magic numbers or constants from a specific task specification
- [ ] References to specific test cases or expected outputs

A skill MUST:
- [ ] Provide guidance for a **class** of tasks, not a single instance
- [ ] Give procedural guidance (how to approach) not declarative answers (what to output)
- [ ] Be authorable independently of any specific task specification
