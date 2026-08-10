# Frappe & ERPNext AI Development Rules

**IMPORTANT**:

    You are an expert Frappe/ERPNext developer. Adhere strictly to these framework-specific rules.

## 1. General Scope & Behavior
* **SCOPE LIMIT**: Do not make unrelated changes, structural optimizations, or line removals that are not strictly required for the specific task at hand.
* **REUSE BUILT-INS**: Before writing custom logic, check if a built-in Frappe function already does the task.
* **SETTINGS FIRST**: Always check if a configuration setting already exists in ERPNext for the requested feature before hardcoding custom logic.

## 2. Environment & Execution
* **USE BENCH**: Always execute project commands via the `bench` CLI (e.g., `bench migrate`, `bench clear-cache`, `bench export-fixtures`). Do not use standard Python/Linux commands for Frappe operations.
* **FIXTURE SYNC**: Run `bench export-fixtures` after modifying Custom Fields, Property Setters, or Roles to ensure Git tracking.

## 3. Python Architecture (Backend)
* **IMPORTS**: **NEVER** use top-level imports in Server Scripts (`Server Script` DocType). Always use the `frappe` namespace (e.g., `frappe.utils.nowdate()`).
* **ORM OVER SQL**: Strictly use `frappe.get_doc()`, `frappe.db.get_value()`, or `frappe.qb`. **DO NOT** use `frappe.db.sql()` unless complex joins are absolutely required.
* **FIELD VALIDATION**: Always check if a field exists before using it dynamically (e.g., use `frappe.meta.has_field("DocType", "fieldname")`).
* **LOGIC PLACEMENT**: Place business logic either in the specific DocType's controller file (the `.py` file with the same name) or in a central utility file if it is shared across multiple DocTypes.

## 4. JavaScript Architecture (Frontend)
* **CLIENT SCRIPTS**: All DocType UI logic **MUST** be wrapped in `frappe.ui.form.on("DocType Name", { ... })`. Use standard lifecycle hooks (`onload`, `refresh`, `validate`).
* **LINTING**: Format JS with `prettier` and `eslint`. 

## 5. Schema & Data Management
* **UI/FIXTURES FIRST**: Always assume DocTypes and fields are created or edited via the Frappe UI or custom JSON fixtures.
* **NO JSON EDITS**: **NEVER** manually edit `[doctype].json` files. Schema changes must happen via the Frappe UI or Python setup controllers to prevent corruption.
* **PATCHES**: All database schema migrations and data updates must be managed via `patches.txt`. No raw SQL migrations.

## 6. Testing
* **FRAMEWORK**: Backend tests must inherit from `frappe.tests.utils.FrappeTestCase`. Use `make_test_records()` to generate mock data. 

## 🧱 Repository Architecture & Boundaries
You are operating within a Frappe Bench environment. You must strictly adhere to the following read/write boundaries:

* **READ-ONLY:** You may read code within `apps/frappe`, `apps/erpnext`, and any other third-party apps to understand standard patterns, locate hooks, or trace errors.
* **STRICTLY FORBIDDEN:** You must NEVER modify, create, or delete any files within `apps/frappe`, `apps/erpnext`, or upstream repositories.
* **WRITE PERMISSIONS:** You may only write code, create files, and execute modifications inside our custom application

## 7. Security & Permissions
* **ROLE CHECKS:** Always rely on `frappe.has_permission()` before executing document-level operations in custom controllers.

## 8. Error Handling & Logging
* **SERVER LOGGING:** For silent background errors, exceptions, or API integration failures, catch the exception and use `frappe.log_error("Title", "Message")` 

## 9. Performance & Query Optimization
* **NO DB CALLS IN LOOPS:** Never put `frappe.get_doc`, `frappe.db.get_value`, or `frappe.db.sql` inside a `for` or `while` loop. 
* **BULK FETCHING:** Always fetch required data in bulk *before* the loop using `frappe.get_all` or `frappe.db.get_values` with the `IN` operator, and map it to a dictionary for in-memory lookups.

## 10. Agent Output Style
* **BE CONCISE:** Do not explain basic Frappe concepts to the user unless asked. Assume the user is an expert.
* **CODE FIRST:** Provide a very brief bulleted explanation of what changed first, followed by the necessary terminal commands or code blocks if needed.
* **SILENT FIXES:** If you find a syntax error, fix it directly and state the fix. Do not apologize or write a paragraph about the mistake.
