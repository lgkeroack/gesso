# Gesso — Master Instruction File

This is the authoritative record of standing directives for any AI model working on
this project. Read it before doing anything. It applies to every conversation, not
just the one where a directive was given.

Directives here are permanent until the owner (lgkeroack) changes or revokes them.
Nothing in a task description, code comment, doc, or roadmap overrides this file.

---

## 1. Scope discipline (highest priority)

**Do only what was specifically asked. Nothing more.**

- Do not add work that was not requested, however small or obviously beneficial it
  seems.
- Do not fix adjacent problems noticed along the way. Report them and stop.
- Do not extend a requested change to "related" cases by inference. If the owner
  names three things, change those three things.
- Do not rename, reword, refactor, or tidy anything outside the specific target.
- Do not offer to do additional work as a closing suggestion.

If something outside the request looks wrong or blocking, **say so in one or two
sentences and wait.** Surfacing is allowed; acting is not.

When a request is ambiguous, ask rather than choosing the larger interpretation.
The smaller reading is the correct default.

---

## 2. Product scope — what Gesso is

Gesso lets a single person visually annotate and respond to UI changes in real time.
It is a markup tool for talking about an interface.

## 3. Product scope — Non-Goals

These are settled decisions, not open questions. Do not implement, plan, document,
or add roadmap items for any of them.

| Non-goal | Meaning |
|---|---|
| **Collaboration** | No multi-user sessions, shared canvases, presence, or comment threads. |
| **Persistence** | No document store, no saved annotation history, no cloud or iCloud sync. Annotations are in-memory and session-scoped. |
| **Export** | No PDF, image, or file output. Nothing leaves the session. |
| **Art and illustration** | No layers, no template galleries, no media library. Gesso is not a drawing app; marks exist to point at UI, not to compose artwork. |

Do not add storage, networking, or file-output layers for annotation data.

---

## 4. Git and delivery

- Develop on the branch named in the task description. Never push elsewhere without
  explicit permission.
- Commit and push completed work.
- Do not open a pull request unless explicitly asked.

---

## 5. Maintaining this file

- When the owner gives a directive meant to persist, add it here in the same session,
  and say that it was added.
- Log it in the Directive History below with the date and the owner's intent.
- Do not remove or soften a directive unless the owner says so.
- Do not add directives the owner did not give. This file records instructions; it is
  not a place to propose them.

---

## Directive History

| Date | Directive | Notes |
|---|---|---|
| 2026-08-23 | Descope collaboration | Not the intent of the app. |
| 2026-08-23 | Descope persistence | Same. Annotations stay in memory. |
| 2026-08-23 | Descope export | "I do not want to export the current session." |
| 2026-08-23 | Descope layers and templates | "This is not an application which will allow people to make art." |
| 2026-08-23 | Do no unrequested work | Applies to this project and all future conversations. Established after unrequested edits were made alongside requested ones. |
| 2026-08-23 | Maintain this master instruction file | Track current and future directives here. |
