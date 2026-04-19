---
name: skill-design
description: >
  Evidence-based guidelines for writing, reviewing, and improving agent skills (SKILL.md files).
  Based on SkillsBench (arxiv 2602.12670), a benchmark of 7,308 agent trajectories across 84 tasks.
  Use this skill when creating a new skill, auditing an existing one, or deciding how to structure
  procedural knowledge for an AI agent. Triggers on: write a skill, improve a skill, review a skill,
  skill quality, SKILL.md, agent skill design, how to structure skills.
license: MIT
metadata:
  author: Bria AI
  version: "1.0.0"
  source: "arxiv 2602.12670 — SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks"
---

# Agent Skill Design — Evidence-Based Guidelines

Based on SkillsBench (2026): 84 tasks × 7 model configurations × 7,308 trajectories.
Curated skills raised pass rates by **+16.2pp** on average. The design choices below are backed by measured deltas.

---

## Key Empirical Findings

| Finding | Measured Impact |
|---------|----------------|
| Curated skills vs. no skills | **+16.2pp** average pass rate |
| Self-generated skills vs. no skills | **–1.8pp** (models cannot reliably author procedural knowledge) |
| 2–3 skills per task (optimal) | **+18.6pp** |
| 4+ skills per task | +5.9pp (diminishing returns) |
| Detailed complexity | **+18.8pp** |
| Compact complexity | +17.1pp |
| Comprehensive/exhaustive documentation | **–2.9pp** (hurts performance) |
| Smaller model + skill vs. larger model alone | Haiku 4.5 + skill (27.7%) beats Opus 4.5 without skill (22.0%) |

**Core insight:** Skills close procedural gaps. They work best when the task requires concrete steps, constraints, and verifier-facing details — not broad conceptual knowledge.

---

## Decision Tree — How to Design a Skill

```
Is the SKILL.md over ~2,000 tokens?
  YES → Split: keep core flow in SKILL.md, move reference tables/recipes to references/
  NO  → Continue

Does the skill list capabilities in a flat table?
  YES → Replace with a decision tree (user intent → specific action/endpoint)
  NO  → Continue

Does the skill include 50+ lines of boilerplate shell/code?
  YES → Extract to references/code-examples/, reference with source <SKILL_DIR>/...
  NO  → Continue

Does the skill describe HOW to approach a class of tasks (procedural)?
  NO  → Add step-by-step flows; remove vague guidance like "use pandas for data processing"
  YES → Continue

Does the skill include common failure modes with fixes?
  NO  → Add a "Common Failures" section (see template below)
  YES → You're done
```

---

## Quality Rubric (Target ≥ 9/12)

Score each dimension 0–3. Ecosystem mean is 6.2/12; top-quartile skills score ≥9/12.

| Dimension | 0 | 1 | 2 | 3 |
|-----------|---|---|---|---|
| **Completeness** | Missing required parts | Has SKILL.md only | Has SKILL.md + some refs | Full structure with examples |
| **Clarity** | Hard to follow | Some structure | Clear sections | Scannable, well-organized |
| **Specificity** | Vague ("use library X") | Mentions APIs/commands | Specific patterns with args | Exact calls, decision trees |
| **Examples** | None | Partial/broken | Working examples | Runnable examples + edge cases |

---

## SKILL.md Structure Template

```markdown
---
name: <skill-name>
description: >
  One focused paragraph. Include explicit trigger keywords so agents
  select this skill correctly. State WHAT it does, not just WHEN.
license: MIT
metadata:
  author: ...
  version: "1.0.0"
---

# Title

One-line summary. Link to external docs if they exist.

## When to Use This Skill
- Bullet list of trigger phrases ("user says X", "task involves Y")

## Setup / Prerequisites  (if any)
- Step-by-step only; no prose

## Decision Tree — What to Do
(Map user intent → specific action. Do not use a flat capability table.)

## How To [Core Operation]
(2–4 runnable examples with exact commands/calls)

## Common Failures
- **symptom** → fix (be specific)
```

---

## What Drives Performance

**Include:**
- Explicit decision trees mapping intent → endpoint/action
- Runnable code examples (exact flags, arguments, field names)
- Step-by-step auth/setup flows with branching on output (`READY` / `ERROR` / etc.)
- Common failure modes with actionable fixes — these directly address verifier-facing errors
- References to helper scripts rather than inlining 50+ lines of boilerplate

**Exclude from SKILL.md (move to `references/`):**
- Comprehensive capability tables (18+ rows)
- Use-case galleries ("what you can build")
- Prompt recipe collections
- Full API parameter docs
- Exhaustive option lists

**Never include:**
- Task-specific filenames, paths, or magic numbers
- Exact sequences that solve a single specific instance
- Vague guidance without concrete API patterns (e.g., "use the SDK appropriately")

---

## Size Guidelines

| Part | Target |
|------|--------|
| SKILL.md | 1,000–2,000 tokens (~4–8 KB) |
| Total skill (incl. references) | ≤ 10,000 tokens |
| Files in skill directory | Median 1–5 files |
| Skills per task | **2–3 optimal** |

Ecosystem median SKILL.md: ~1,569 tokens. Benchmark top-quartile: ~2,087 tokens mean.
Context budget per task: ~8K tokens — plan accordingly when combining multiple skills.

---

## Self-Generated Skills Don't Work

Do not rely on the agent to generate its own skills before solving a task. SkillsBench found:

- Self-generated skills: **–1.8pp** average (worse than no skills)
- Failure mode 1: Agent identifies the need but generates imprecise procedures (lists libraries without API patterns)
- Failure mode 2: For high-domain-knowledge tasks, agent fails to recognize what specialized knowledge is even needed

Skills require **human-curated domain expertise**. The value is in the curation, not the format.

---

## Resources

- **[Full Design Reference](references/design-reference.md)** — Extended examples, anti-pattern gallery, domain-specific notes
- **[SkillsBench Paper](https://arxiv.org/abs/2602.12670)** — Source research (Li et al., 2026)
