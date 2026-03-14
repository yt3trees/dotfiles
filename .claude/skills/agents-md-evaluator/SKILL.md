---
name: agents-md-evaluator
description: "Evaluate and score AGENTS.md, CLAUDE.md, or similar AI agent instruction files for quality and completeness. Use this skill whenever the user asks to review, evaluate, audit, score, check, or improve their AGENTS.md, CLAUDE.md, .cursorrules, or any AI agent configuration file. Also trigger when the user pastes the content of such a file and asks for feedback, or says things like 'how is my CLAUDE.md?', 'rate my AGENTS.md', 'is this good enough?', or 'what am I missing?'. Even if the user just shares the content without explicitly asking for evaluation, suggest running this evaluation."
---

# AGENTS.md / CLAUDE.md Evaluator

Evaluate AI agent instruction files against established best practices. Produces a structured scorecard with actionable improvement suggestions.

This evaluation framework is based on the builder.io article "Improve your AI code output with AGENTS.md" and the broader AGENTS.md community best practices.

## Why This Matters

Without a well-crafted instruction file, AI agents waste time exploring codebases, make assumptions about libraries and patterns, and produce code that doesn't match project conventions. A good AGENTS.md eliminates that discovery phase and gives agents the context they need to be productive from the first prompt.

## Evaluation Process

1. Read the target file (AGENTS.md, CLAUDE.md, etc.)
2. Score each category on a 1-5 scale
3. Calculate an overall score
4. Identify specific missing elements
5. Generate concrete improvement suggestions with examples
6. Output a formatted evaluation report

## Scoring Categories

Evaluate the file across these 8 categories. Each is scored 1-5:

### 1. Do / Don't Rules (技術スタック・規約の明示)

The most fundamental section. Tells agents which libraries, patterns, and conventions to use — and which to avoid. Without this, agents guess, and guesses often miss.

**Score 5 — Excellent:**
- Specific library names with versions (e.g., "use MUI v3", "use React 18")
- Preferred patterns stated (e.g., "use emotion css={{}} prop format", "use mobx for state management")
- Explicit anti-patterns (e.g., "do not hard code colors", "do not add heavy dependencies without approval")
- Styling approach defined (e.g., "use design tokens from DynamicStyles.tsx")

**Score 3 — Adequate:**
- Some libraries mentioned but without versions
- General style guidance but missing specifics
- A few do/don't rules but not comprehensive

**Score 1 — Missing/Minimal:**
- No do/don't section, or only vague statements like "follow best practices"

### 2. Commands (コマンド定義)

File-scoped commands are critical for efficiency. Agents should validate changes on individual files, not run full project builds every time. This is one of the highest-impact sections.

**Score 5 — Excellent:**
- File-scoped lint, format, type-check commands (e.g., `npm run tsc --noEmit path/to/file.tsx`)
- File-scoped test command (e.g., `npm run vitest run path/to/file.test.tsx`)
- Full build command noted as "only when explicitly requested"
- Commands use the project's actual package manager and scripts

**Score 3 — Adequate:**
- Some commands listed but only project-wide (e.g., `npm run build`)
- Missing file-scoped variants
- Test commands present but no lint/format

**Score 1 — Missing/Minimal:**
- No commands section, or only generic commands that don't match the actual project

### 3. Safety & Permissions (安全性とパーミッション)

Defines what agents can do autonomously versus what requires human approval. Prevents unexpected state mutations like unplanned `npm install` or `git push`.

**Score 5 — Excellent:**
- Clear "Allowed without prompt" list (read files, single-file lint, single test, etc.)
- Clear "Ask first" list (package installs, git push, file deletion, full builds, etc.)
- Boundaries match the project's actual risk profile

**Score 3 — Adequate:**
- Some safety mentions but not clearly structured as allow/deny
- Missing either the allowed or ask-first list

**Score 1 — Missing/Minimal:**
- No safety/permissions section

### 4. Project Structure (プロジェクト構造)

A lightweight index that points agents to the right starting files. Without this, agents waste time exploring the codebase every session.

**Score 5 — Excellent:**
- Key entry points identified (routing, layout, sidebar, etc.)
- Component directories mapped
- Config/token file locations specified
- Acts as a "tiny index" for the codebase

**Score 3 — Adequate:**
- Some directory structure mentioned but incomplete
- Missing key entry points or config locations

**Score 1 — Missing/Minimal:**
- No project structure, or just a generic tree dump without guidance

### 5. Good & Bad Examples (良い例・悪い例)

Concrete code examples are one of the most effective ways to guide agents. Showing "copy this pattern" and "avoid this pattern" with actual file references from the codebase eliminates ambiguity.

**Score 5 — Excellent:**
- References to real files in the project as positive examples (e.g., "use functional components like Projects.tsx")
- References to files to avoid copying (e.g., "avoid class-based components like Admin.tsx")
- Pattern examples for common tasks (forms, charts, data fetching, etc.)

**Score 3 — Adequate:**
- Some general guidance on patterns but no specific file references
- "Do X, don't do Y" without concrete examples from the codebase

**Score 1 — Missing/Minimal:**
- No examples section

### 6. API & Documentation References (APIドキュメント参照)

Points agents to where API docs live and shows how to use typed clients. Prevents agents from guessing API structures or creating raw fetch calls when typed clients exist.

**Score 5 — Excellent:**
- Doc file locations specified (e.g., `./api/docs/*.md`)
- Key endpoints documented with typed client usage
- MCP server references where applicable
- Data fetching patterns specified (e.g., "use app/api/client.ts, do not fetch in components")

**Score 3 — Adequate:**
- Some API references but incomplete
- Missing typed client guidance

**Score 1 — Missing/Minimal:**
- No API documentation references

### 7. Size & Focus (サイズとフォーカス)

The file should be concise and scoped. Overly long files dilute the most important rules. The ideal AGENTS.md is under 60 lines for most projects, and under 500 lines even for large ones. Large repos benefit from hierarchical nested files in subdirectories.

**Score 5 — Excellent:**
- Concise and focused — every line earns its place
- Under 100 lines (or clearly structured with headers if longer)
- References external files for deep detail rather than inlining everything
- Mentions nested AGENTS.md strategy for monorepos if applicable

**Score 3 — Adequate:**
- Reasonable length but some bloat or repetition
- Could be more focused

**Score 1 — Poor:**
- Extremely long (500+ lines) without clear structure
- OR extremely short (under 10 lines) and missing key sections
- Lots of generic filler that doesn't help the agent

### 8. Iterability & Maintenance (反復性と保守性)

The file should be treated as a living document. Rules should be added when you see the same mistake twice. Guidance should evolve as the project evolves.

**Score 5 — Excellent:**
- Rules feel specific to actual problems encountered (not generic template copy-paste)
- PR checklist or workflow guidance included
- "When stuck" guidance provided
- Evidence of project-specific iteration (e.g., references to specific version quirks)

**Score 3 — Adequate:**
- Some project-specific rules but mixed with generic advice
- Partially feels like a template

**Score 1 — Poor:**
- Clearly a template with placeholder text
- No evidence of project-specific customization

## Output Format

Generate the evaluation as a structured report. Use Japanese for the report since the primary audience is Japanese-speaking developers.

```
# AGENTS.md 評価レポート

## 📊 総合スコア: [X] / 40 ([ランク])

ランク基準:
- S (36-40): エージェントが即座に生産的に動ける理想的な状態
- A (28-35): 高品質。いくつかの改善余地あり
- B (20-27): 実用的だが重要な改善ポイントあり
- C (12-19): 基本的な指示のみ。多くのセクションが不足
- D (1-11): ほぼ効果なし。根本的な見直しが必要

## 📋 カテゴリ別スコア

| カテゴリ | スコア | 判定 |
|---------|--------|------|
| 1. Do/Don'tルール | [X]/5 | [emoji] |
| 2. コマンド定義 | [X]/5 | [emoji] |
| 3. 安全性とパーミッション | [X]/5 | [emoji] |
| 4. プロジェクト構造 | [X]/5 | [emoji] |
| 5. 良い例・悪い例 | [X]/5 | [emoji] |
| 6. APIドキュメント参照 | [X]/5 | [emoji] |
| 7. サイズとフォーカス | [X]/5 | [emoji] |
| 8. 反復性と保守性 | [X]/5 | [emoji] |

判定: ⭐ = 5, ✅ = 3-4, ⚠️ = 2, ❌ = 1

## 🔍 詳細評価

### [各カテゴリの詳細コメント]
- 良い点
- 改善点
- 具体的な改善提案（コード例つき）

## 🚀 優先改善アクション（TOP 3）

最もインパクトの大きい改善を3つ、具体的なコード例とともに提示する。

## 💡 追加のヒント

プロジェクトの特性に応じた追加アドバイス（モノレポなら階層化、大規模なら分割など）。
```

## Evaluation Tips

When evaluating, keep these principles in mind:

- **Specificity over generality**: "use MUI v3" is better than "use our UI library". Score higher for concrete, actionable instructions.
- **File references over descriptions**: "copy the pattern in Projects.tsx" beats "use functional components". Real file paths anchor the agent in the actual codebase.
- **File-scoped over project-wide**: `npm run tsc --noEmit path/to/file.tsx` beats `npm run build`. File-scoped commands are dramatically faster.
- **Earned rules over template rules**: Rules that feel like they were born from real mistakes score higher than generic best-practice lists. The best AGENTS.md files have a "battle-tested" quality.
- **Concise over comprehensive**: A tight 50-line file with high-signal rules beats a 300-line file padded with obvious guidance.

## Handling Different File Types

This evaluation applies to:
- `AGENTS.md` — the open standard for AI coding agents
- `CLAUDE.md` — Claude Code's project-specific instruction file
- `.cursorrules` — Cursor's equivalent
- `.builderrules` — Builder.io's format
- Any similar AI agent instruction file

When evaluating CLAUDE.md specifically, also check:
- Whether it references external docs rather than duplicating content
- Whether it uses Claude-specific features appropriately (e.g., permission modes)

## If the File Doesn't Exist Yet

If the user doesn't have an AGENTS.md yet, skip the evaluation and instead:
1. Ask about their tech stack, project structure, and common pain points
2. Generate a starter AGENTS.md based on best practices
3. Then evaluate the generated file so they can iterate
