---
name: frappe-decision-ladder
description: Framework-aware "write the least code necessary" ladder for Frappe/ERPNext, plus a full best-practices sweep across every sibling skill's anti-patterns reference. Three workflows are described below — a diff review, a whole-app audit, and a full sweep combining both with every other skill's anti-pattern checks — for catching avoidable custom code and best-practice violations before or after they're written. Apply before adding a new DocType, Server Script, Client Script, Report, or override, and any time unnecessary/duplicate/non-idiomatic Frappe code needs to be checked for. A companion PostToolUse hook (`hooks/frappe_ladder_check.py`) runs a deterministic subset of these checks automatically on every Edit/Write under `apps/*/` — see "Automatic checks" below for what it can and can't catch on its own.
---

# Frappe Decision Ladder

> **TL;DR:** Before writing new Frappe/ERPNext code, this skill checks whether a config option, built-in, or existing pattern already does the job. Ask for a **review** (a diff), an **audit** (a whole app), or a **sweep** (both plus every other skill's best-practice checks) and get back a report of what could be leaner. A small deterministic subset of this also runs *automatically* on every file edit via a hook (see below) — the rest is judgment-based and only runs when asked or relevance-matched.

## Automatic checks (hook, not judgment)

`skills/frappe-decision-ladder/hooks/frappe_ladder_check.py` in this repo is a companion script, wired via a `PostToolUse` hook on `Write|Edit`, that runs unconditionally — no asking required — whenever a `.py`/`.json` file under `apps/*/` is touched. It flags, by regex/text pattern only:

- `frappe.db.sql()` usage
- `frappe.get_doc`/`frappe.db.get_value`/`frappe.db.sql`/`frappe.db.exists` calls textually inside a `for`/`while` loop
- Whitelisted methods with a document operation (`.save`/`.submit`/`.cancel`/`.delete`) and no visible `has_permission`/`check_permission` call in the same function
- Directly edited DocType `.json` files
- Top-level `import`s inside a Server Script's `script` field

**What it can't do:** anything requiring cross-file or semantic reasoning — a DB call hidden behind a helper function invoked from a loop (rather than inline in the loop body), or "does ERPNext core already validate this" (the kind of finding Workflow 1/3 catch by actually reading and reasoning about other code). Those rungs of the ladder stay judgment-based: they only run on explicit ask or when this skill gets relevance-matched, never unconditionally. The hook is the cheap, always-on floor; the workflows above are the deeper, occasional ceiling — neither replaces the other.

Wiring the hook into a project requires a `PostToolUse`/`Write|Edit` entry in `settings.json` pointing at this script (global `~/.claude/settings.json` if your session's project root differs from where the Frappe apps live, project-level `.claude/settings.json` otherwise) — that wiring is local machine config, not part of this repo, so set it up per machine.

Same philosophy as generic "minimal code" linters (fewer lines, less to maintain, less surface area for bugs), but the rungs are Frappe/ERPNext-specific: this framework ships an enormous amount of behavior as *configuration* (Workflow, Property Setter, Custom Field, Permission Rule, Notification, Print Format, Web Form) rather than code, and duplicating that in a controller or Server Script is the single most common source of avoidable bloat in this stack.

## How It Works

1. **The Ladder** (below) is an ordered checklist walked *before* writing any new DocType, controller, script, or override — config-first, custom-code last.
2. **Workflows 1 and 2** apply that ladder after the fact — to a diff, or to a whole app at rest — flagging any rung that got skipped, with the concrete built-in/config alternative named.
3. **Workflow 3** widens the pass: it maps the files touched to the matching `anti-patterns.md` in each sibling skill (controllers, hooks, server scripts, queries, permissions, etc.), so one request returns unnecessary-code findings *and* best-practice/optimization findings together.
4. **The Decision Log** (below) closes the loop — when the ladder is walked and no rung actually applies, that reasoning gets written down once per app, so the next audit doesn't re-litigate a settled exception.

## Benefits

- **Fewer duplicate DocTypes/logic across a multi-app bench.** This bench alone runs `frappe`, `erpnext`, `lms`, `hrms`, `insights`, `gate_pass`, `india_compliance`, `payments`, `saadaa_custom`, `flex_dimensions`, `builder`, `saadaa_v2`, and `vendor_lifecycle` side by side — real risk of reinventing something a sibling app already ships.
- **Faster review.** A reviewer sees the ladder reasoning (or a decision-log entry) instead of having to re-derive "was this custom code actually necessary?" from scratch.
- **Smaller upgrade/maintenance surface.** Config (Workflow, Property Setter, Notification) survives framework upgrades for free; hand-rolled controller/script logic has to be re-verified every `bench update`.
- **One pass covers two concerns.** Workflow 3 catches avoidable bloat and best-practice/perf violations together, instead of two separate review passes.
- **Institutional memory.** The decision log gives new team members and future audits the "why" behind an exception without having to track down or re-interview whoever wrote the original code.
- **Complements, doesn't duplicate, the other 11 skills** — it reuses their `anti-patterns.md` content rather than re-documenting Frappe syntax from scratch.

## The Ladder

Before writing anything — DocType, controller method, Server Script, Client Script, Report, override — walk down until something answers "yes":

1. **Does this need to exist at all?** Is the requirement already satisfied by a core doctype, a standard report, or an existing workflow state? (e.g. "notify manager on submit" → Notification doctype, not a `on_submit` hook.)
2. **Is it pure configuration?** Custom Field, Property Setter, Workflow, Assignment Rule, Notification, Print Format, Web Form, Permission Rule, Role Permission Manager. None of these need a line of Python/JS.
3. **Does it already exist in this app or a sibling installed app?** Grep `hooks.py`, `*/doctype/`, `*/report/`, `*/workflow/` across all apps in this bench before adding a new one — `bench --site <site> list-apps` first so you know what's actually installed.
4. **Is there a Frappe/ERPNext standard-library call that does this?** `frappe.utils.*`, `frappe.desk.*`, `frappe.model.*`, `frappe.share`, `frappe.workflow.*`, `frappe.query_builder` — before hand-rolling date math, permission checks, or SQL.
5. **Can an existing hook be extended instead of a new file created?** A new `doc_events` entry in the app's existing `hooks.py`, or one more condition in an existing Server Script, beats a new file when the logic is a few lines.
6. **Can it be a Property Setter / one-line Client Script instead of a controller method?** e.g. `frm.set_df_property` in an existing Client Script beats a new `.js` file; a fetch/mandatory-depends-on config beats `validate()` code.
7. **Only then**, write the minimum: one controller method placed in the DocType's own `.py` (per this repo's rule — logic lives in the controller or a shared util, never a new module for one function).

## Examples by rung

Each of these is a realistic instance of that specific rung firing — what got skipped, and what should have been used instead.

**Rung 1 — does this need to exist at all?**
Requirement: "email the Vendor Lifecycle Manager whenever a Vendor Onboarding Request is submitted."
- ❌ A `doc_events` hook on `"Vendor Onboarding Request": {"on_submit": "...send_email(doc)"}` that builds and sends an email manually.
- ✅ A **Notification** doctype: document type = Vendor Onboarding Request, event = Submit, recipient = a role/user. Zero code.

**Rung 2 — is it pure configuration?**
Requirement: "`vendor_category` should be mandatory only when `onboarding_type` is 'New Vendor'."
- ❌ `def validate(self): if self.onboarding_type == "New Vendor" and not self.vendor_category: frappe.throw(...)`
- ✅ **Property Setter** on the `vendor_category` field: `mandatory_depends_on = "eval:doc.onboarding_type=='New Vendor'"`. Set once via Customize Form, no controller code at all.

**Rung 3 — does it already exist in this app or a sibling installed app?**
Real, verified finding from this bench: `vendor_lifecycle/deboarding_guard.py::block_disabled_supplier_on_order` throws an error if a Supplier is disabled, for Purchase Order.
- ❌ Custom `doc_events["Purchase Order"]["validate"]` hook re-implementing the block.
- ✅ ERPNext core already does this — `accounts_controller.py:294` calls `self.validate_party()` → `validate_party_frozen_disabled()` (`erpnext/accounts/party.py:821`), which throws `PartyDisabled` for Purchase Order, Purchase Receipt, and Purchase Invoice unconditionally. The custom hook for those three doctypes is dead code; only the Request for Quotation case (not covered by core) was actually needed.

**Rung 4 — is there a stdlib call that does this?**
Requirement: "get the date 90 days before today."
- ❌ `import datetime; cutoff = datetime.date.today() - datetime.timedelta(days=90)`, or manually string-formatting dates.
- ✅ `frappe.utils.add_days(frappe.utils.nowdate(), -90)` — handles the site's date format and timezone the way the rest of Frappe expects.

**Rung 5 — can an existing hook be extended instead of a new file?**
Requirement: "also block disabled suppliers on Material Request."
- ❌ A new `vendor_lifecycle/material_request_guard.py` file with its own `block_disabled_supplier_on_material_request` function.
- ✅ One more line in the existing `doc_events` dict in `hooks.py`, pointing at the *existing* `deboarding_guard.block_disabled_supplier_on_order` function (it's already generic over doctype) — no new file.

**Rung 6 — can it be a Property Setter / one-line Client Script instead of a controller method?**
Requirement: "hide the `esign_provider` field on Vendor Sign Off until `status` is 'Pending Signature'."
- ❌ A `refresh()` handler in a full custom `.js` file that calls `frm.toggle_display(...)` with hand-written conditionals.
- ✅ The field's **Depends On** property (`eval:doc.status=="Pending Signature"`) set via Customize Form — no JS file needed at all.

**Rung 7 — only then, write the minimum**
Requirement: "create a daily satisfaction survey for every active vendor past its cadence window" (`vendor_lifecycle/tasks.py::create_pending_satisfaction_surveys` — genuinely needs custom code; no rung above applies).
- ❌ What's actually in the file right now: `frappe.db.exists(...)` called once per vendor inside the `for vendor in active_vendors:` loop — real code, correctly justified at rung 7, but not yet *minimal*.
- ✅ One bulk query before the loop (`frappe.get_all(..., filters={"vendor": ["in", active_vendors], ...}, pluck="vendor")` turned into a set) — this is what Workflow 1/3's "optimization opportunity" category catches even after a rung is correctly chosen; reaching rung 7 doesn't mean the ladder's job is done, it means the *optimization* pass (anti-patterns sweep) still applies.

## Workflow 1: reviewing a diff

1. Run `git diff` (or `git diff <base>...HEAD` if the user names a range) inside the relevant app directory under `apps/`.
2. For each changed hunk that adds new DocTypes, Server Scripts, Client Scripts, Reports, or controller methods, walk the ladder above and ask which rung it should have stopped at.
3. Also check it against the existing repo rules already enforced here: ORM over `frappe.db.sql()`, no top-level imports in Server Scripts, `frappe.has_permission()` before document ops, no `frappe.get_doc`/`frappe.db.get_value`/`frappe.db.sql` inside loops (bulk-fetch instead), `frappe.meta.has_field()` before dynamic field access, no hand-edited DocType JSON.
4. Before flagging anything, check the app's `decision-log.md` (see below) for an existing entry covering this DocType/module — a documented, still-valid exception is not a fresh finding.
5. Report findings as: `file:line` — what was added, which rung it should have used instead, and the concrete built-in/config alternative (name the doctype/API, don't just say "use a built-in").
6. Don't flag genuinely necessary custom code — only flag where a lower-effort framework-native option was skipped. If the user overrides a finding with a reason, that's a new decision-log entry, not a dismissal.

## Workflow 2: auditing a whole app

1. Identify the app directory (ask if ambiguous — there may be several apps in `apps/`).
2. Look for the same signals at rest rather than in a diff:
   - Server Scripts or Client Scripts duplicating logic already in the app's own `hooks.py`/controllers.
   - Custom DocTypes duplicating a core or already-installed sibling-app DocType (compare field sets, not just names — `Gate Entry`/`gate_pass` vs core Stock Entry is a real example to watch for in this bench).
   - `frappe.db.sql()` where `frappe.qb`/`frappe.get_all` would do.
   - Manual permission filtering in a report/list query instead of a Permission Query Condition hook.
   - Client Scripts re-implementing what a Property Setter or standard fetch/mandatory-depends-on could do.
3. Cross-check each candidate finding against `decision-log.md` first — same rule as Workflow 1.
4. Summarize as a punch list grouped by DocType/module, most-impactful first (a duplicated DocType outranks a missed one-liner).

## Workflow 3: full sweep — decision ladder + every sibling skill's anti-patterns

This is the umbrella pass: one ask covers "is this code unnecessary" (Workflows 1/2 above) *and* "is this code idiomatic/optimized per ERPNext best practice", by pulling in every `anti-patterns.md` across the central skills library instead of relying on whichever single skill's description happens to match. Use for a diff (default) or a whole app if the user asks for one.

1. Determine the file types touched (in the diff, or across the target app if doing a whole-app sweep) and load only the relevant anti-patterns references — don't load all eleven if only controllers and hooks changed:

   | Files touched | Read this reference |
   |---|---|
   | `*/doctype/*/*.py` (controllers) | `~/.claude-skills/skills/frappe-syntax-controllers/references/anti-patterns.md` |
   | `*/doctype/*/*.js` (client scripts) | `~/.claude-skills/skills/frappe-syntax-clientscripts/references/anti-patterns.md` |
   | `hooks.py` | `~/.claude-skills/skills/frappe-syntax-hooks/references/anti-patterns.md` |
   | `doc_events` entries specifically | `~/.claude-skills/skills/frappe-syntax-hooks-events/references/anti-patterns.md` |
   | Server Script doctype records / `.py` meant to run as one | `~/.claude-skills/skills/frappe-syntax-serverscripts/references/anti-patterns.md` |
   | `@frappe.whitelist()` methods | `~/.claude-skills/skills/frappe-syntax-whitelisted/references/anti-patterns.md` |
   | Scheduler events / `frappe.enqueue` calls | `~/.claude-skills/skills/frappe-syntax-scheduler/references/anti-patterns.md` |
   | `report.py` / Query Reports | `~/.claude-skills/skills/frappe-impl-reports/references/anti-patterns.md` |
   | Custom dialogs, List View extensions, realtime | `~/.claude-skills/skills/frappe-impl-ui-components/references/anti-patterns.md` |
   | `frappe.db.sql`, `frappe.qb`, any query code | `~/.claude-skills/skills/frappe-core-database/references/anti-patterns.md` |
   | Permission queries, `has_permission`, user permissions | `~/.claude-skills/skills/frappe-core-permissions/references/anti-patterns.md` |

   (`doctype-patterns` has no `anti-patterns.md` — its `SKILL.md` itself covers DocType structure; read that directly if a new DocType is involved.)
2. Walk the changed/existing code against the Ladder (this file) for unnecessary-code findings, and against each loaded reference for best-practice/optimization violations — same pass, not two separate reports.
3. Merge into one report grouped by severity, not by source skill:
   - **Unnecessary code** — a ladder rung was skipped (cite the rung and the concrete built-in/config alternative).
   - **Best-practice violation** — contradicts a named anti-pattern (cite which reference file and the correct pattern to use instead).
   - **Optimization opportunity** — correct but inefficient (e.g. query in a loop, missing bulk fetch) — cite the reference's recommended pattern.
4. Same rule as Workflow 1: don't invent findings to pad the report — an empty category is a fine outcome.

## Decision Log

The ladder will sometimes be walked and genuinely find nothing — the custom code is warranted, no config surface or built-in covers it. That outcome is worth writing down once so it isn't re-argued every future review.

**Role it plays:**
- **Avoids re-litigation.** Without a record, every future `review`/`audit`/`sweep` re-flags the same justified exception, wasting review time and eroding trust in the audit itself.
- **Audit trail.** For compliance-sensitive Frappe deployments (this bench already runs `india_compliance`), a written rationale for why something is custom code, not config, is itself useful documentation.
- **Reviewer context.** A PR reviewer sees *why* a rung was skipped instead of having to ask the author or re-derive it themselves.
- **Feeds back into Workflows 1–3.** Both workflows check this log before reporting a finding (see the steps above) — it's the mechanism that makes repeated audits get cheaper over time instead of noisier.

**Where it lives:** `<app>/decision-log.md` at the root of the app being worked on (e.g. `apps/vendor_lifecycle/decision-log.md`). Create it on first use if it doesn't exist.

**Entry format** — one row per justified exception:

| Date | DocType/Module | Requirement | Rungs considered & why rejected | Chosen implementation |
|---|---|---|---|---|
| 2026-08-10 | Vendor Onboarding Request | Notify procurement on submit | Rung 2 (Notification doctype) rejected — needs conditional recipient logic based on vendor category, which Notification's condition field can't express cleanly | `on_submit` hook calling a shared notify util |

**When to add an entry:**
- The ladder was walked in full and no rung applied — write it down at the point the custom implementation is committed, not deferred to later.
- A `review`/`audit`/`sweep` finding is deliberately overridden with a reason — that reason becomes the entry; the finding doesn't just get dismissed silently.

## Non-negotiables (do not relax these to save lines)

Never trade away validation, permission checks, or error logging for brevity — the ladder is about picking the *right* implementation surface, not about skipping correctness. Follow every rule in this project's root skill index (`~/.claude-skills/index.md`) — this skill sits on top of those, not in place of them.
