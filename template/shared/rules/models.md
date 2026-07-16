# Models

Default model + effort per engine for the cross-engine roles (research, review, council).
Maintained by hand — edit this table to change defaults; the skills read from here so
model IDs live in one place, not scattered across skills.

**Principle:** the reviewer/advisor must run on a **different engine than the driver**
(model diversity is the point). The driver's own model is whatever you opened the CLI
with — not pinned by this project.

## Per-engine defaults

| Engine | Model | Effort | Invocation |
| --- | --- | --- | --- |
| **Codex** | `gpt-5.6-sol` | `xhigh` | `codex exec -m gpt-5.6-sol -c model_reasoning_effort="xhigh" "<prompt>"` |
| **Claude** | `opus` | `high` | `claude -p --model opus --effort high "<prompt>"` |
| **OpenCode** | `opencode-go/glm-5.2` | default | `opencode run -m opencode-go/glm-5.2 "<prompt>"` |

Same model/effort per engine regardless of role — the role only decides **which
engine(s)** to use:

| Role | Engine(s) |
| --- | --- |
| **Driver** (implementation / TDD) | the CLI you open (not pinned) |
| **Reviewer** (design + code review) | the non-driver engine |
| **Research** (when delegated) | a non-driver, web/synthesis-capable engine |
| **Council advisors** | all three (max diversity) |

## Read-only for reviewers / advisors

A reviewer (`review`) or council advisor must not modify the working tree it's judging.
Invoke it read-only: Codex `--sandbox read-only`; for Claude/OpenCode restrict to
read-only (no write/edit tools). Hand it the diff/plan as text and confirm the
working-tree diff is unchanged afterward.

## Cost note

These are quality-first defaults (top models, high effort) because review/council
decisions are where being wrong is expensive. If cost matters, downgrade here — e.g.
Codex `gpt-5.4-mini`, OpenCode `opencode-go/deepseek-v4-flash`, or a lower `--effort` /
`model_reasoning_effort` — and the skills follow automatically.
