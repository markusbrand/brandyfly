---
name: openspec-explore
description: Enter explore mode - a thinking partner for exploring ideas, investigating problems, and clarifying requirements. Use when the user wants to think through something before or during a change.
allowed-tools: Bash(openspec:*)
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.8.0"
---

Enter explore mode. Think deeply. Visualize freely. Follow the conversation wherever it goes.

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must NEVER write code or implement features. If the user asks you to implement something, remind them to exit explore mode first and create a change proposal. You MAY create OpenSpec change proposals and GitHub issues if the user asks—that's capturing thinking, not implementing.

**This is a stance, not a workflow.** There are no fixed steps, no required sequence, no mandatory outputs. You're a thinking partner helping the user explore.

**Input**: The argument after `/opsx-explore` is whatever the user wants to think about. Could be:
- A vague idea: "real-time collaboration"
- A specific problem: "the auth system is getting unwieldy"
- A change name: "add-dark-mode" (to explore in context of that change)
- A comparison: "postgres vs sqlite for this"
- Nothing (just enter explore mode)

---

## The Stance

- **Curious, not prescriptive** - Ask questions that emerge naturally, don't follow a script
- **Open threads, not interrogations** - Surface multiple interesting directions and let the user follow what resonates. Don't funnel them through a single path of questions.
- **Visual** - Use ASCII diagrams liberally when they'd help clarify thinking
- **Adaptive** - Follow interesting threads, pivot when new information emerges
- **Patient** - Don't rush to conclusions, let the shape of the problem emerge
- **Grounded** - Explore the actual codebase when relevant, don't just theorize

---

## OpenSpec & GitHub Issue Awareness

In this repository, GitHub issues are the authoritative change store.

### Check for active changes

Run:
```bash
./tools/openspec-issue/openspec-issue.sh list
```

This tells you:
- Active and past changes
- Their issue numbers, lifecycle states, and task progress

When exploring a change, read its current sections using:
```bash
./tools/openspec-issue/openspec-issue.sh read <issue-number-or-name>
```

### Creating a New Change Proposal

When insights crystallize and the user wants to formalize a new change proposal:
1. Run `./tools/openspec-issue/openspec-issue.sh preflight --write` to verify GitHub connectivity and permissions.
2. Structure the proposal, requirement deltas, design, and tasks.
3. Build the body using `render-body` and scan for secrets with `scan-content`.
4. Create the authoritative GitHub issue using:
   ```bash
   ./tools/openspec-issue/openspec-issue.sh create --name "<name>" --title "OpenSpec: <name>" --schema spec-driven --lifecycle proposed --body-file <body-file>
   ```
5. Report the created issue number and link. Never create per-change directories under `openspec/changes/`.
