#!/usr/bin/env python3
"""Deterministic, regex-level checks derived from frappe-decision-ladder and
the anti-patterns.md references in ~/.claude-skills/skills/. Only flags what
can be verified from source text alone; anything requiring judgment (e.g.
"does ERPNext core already do this") is out of scope for this script."""
import sys
import re
import json
import os

DB_CALL_RE = re.compile(r"\b(frappe\.get_doc|frappe\.db\.get_value|frappe\.db\.sql|frappe\.db\.exists)\s*\(")
SQL_RE = re.compile(r"frappe\.db\.sql\s*\(")
LOOP_RE = re.compile(r"^(\s*)(for|while)\b")
WHITELIST_RE = re.compile(r"@frappe\.whitelist\s*\(")
DEF_RE = re.compile(r"^(\s*)def\s+\w+\s*\(")
DOC_OP_RE = re.compile(r"\.(save|submit|cancel|delete)\s*\(|frappe\.delete_doc\s*\(")
PERM_RE = re.compile(r"frappe\.has_permission\s*\(|\.check_permission\s*\(")


def check_python(path, lines):
	findings = []

	for i, line in enumerate(lines, 1):
		if SQL_RE.search(line):
			findings.append(
				f"{path}:{i} — frappe.db.sql() used; consider frappe.qb/frappe.get_all "
				f"unless a complex join genuinely needs raw SQL."
			)

	loop_stack = []
	for i, line in enumerate(lines, 1):
		if not line.strip():
			continue
		indent = len(line) - len(line.lstrip(" \t"))
		m = LOOP_RE.match(line)
		while loop_stack and indent <= loop_stack[-1]:
			loop_stack.pop()
		if m:
			loop_stack.append(indent)
			continue
		if loop_stack and DB_CALL_RE.search(line):
			findings.append(
				f"{path}:{i} — DB call inside a loop; bulk-fetch before the loop instead "
				f"(frappe.get_all/get_values with an `in` filter)."
			)

	in_whitelisted = False
	pending_whitelist = False
	func_indent = None
	saw_permission_check = False
	saw_doc_op = None

	def flush():
		if saw_doc_op and not saw_permission_check:
			findings.append(
				f"{path}:{saw_doc_op} — whitelisted method performs a document operation "
				f"with no frappe.has_permission()/check_permission() call found in its body; "
				f"verify permission is enforced elsewhere."
			)

	for i, line in enumerate(lines, 1):
		stripped = line.strip()
		if WHITELIST_RE.match(stripped):
			pending_whitelist = True
			continue
		m = DEF_RE.match(line)
		if m and pending_whitelist:
			if in_whitelisted:
				flush()
			in_whitelisted = True
			func_indent = len(m.group(1))
			saw_permission_check = False
			saw_doc_op = None
			pending_whitelist = False
			continue
		if m and not pending_whitelist and in_whitelisted:
			indent = len(m.group(1))
			if indent <= func_indent:
				flush()
				in_whitelisted = False
			continue
		if in_whitelisted:
			indent = len(line) - len(line.lstrip(" \t"))
			if line.strip() and indent <= func_indent:
				flush()
				in_whitelisted = False
				continue
			if PERM_RE.search(line):
				saw_permission_check = True
			if DOC_OP_RE.search(line) and saw_doc_op is None:
				saw_doc_op = i
	if in_whitelisted:
		flush()

	return findings


def scan_script_field(d, path):
	out = []
	if isinstance(d, dict):
		if isinstance(d.get("script"), str):
			for i, line in enumerate(d["script"].splitlines(), 1):
				if re.match(r"^\s*(import\s|from\s+\S+\s+import\s)", line):
					out.append(
						f"{path} (script field, line {i}) — top-level import inside a "
						f"Server Script; use the frappe namespace instead "
						f"(e.g. frappe.utils.nowdate())."
					)
		for v in d.values():
			out.extend(scan_script_field(v, path))
	elif isinstance(d, list):
		for v in d:
			out.extend(scan_script_field(v, path))
	return out


def check_json(path, content):
	findings = []
	if re.search(r"/doctype/[^/]+/[^/]+\.json$", path) and not os.path.basename(path).startswith("test_"):
		findings.append(
			f"{path} — DocType JSON written/edited directly; project rule is schema "
			f"changes go through the UI/setup controllers, not hand-edited JSON."
		)
	try:
		data = json.loads(content)
	except Exception:
		data = None
	if data is not None:
		findings.extend(scan_script_field(data, path))
	return findings


def main():
	if len(sys.argv) < 2:
		return
	path = sys.argv[1]
	if "/apps/" not in path:
		return
	if not (path.endswith(".py") or path.endswith(".json")):
		return
	if not os.path.isfile(path):
		return
	with open(path, "r", errors="ignore") as f:
		content = f.read()

	if path.endswith(".py"):
		findings = check_python(path, content.splitlines())
	else:
		findings = check_json(path, content)

	if findings:
		msg = (
			f"frappe-decision-ladder (auto-check) flagged {len(findings)} item(s) in "
			f"{os.path.basename(path)}:\n" + "\n".join("- " + f for f in findings)
		)
		print(json.dumps({
			"systemMessage": msg,
			"hookSpecificOutput": {
				"hookEventName": "PostToolUse",
				"additionalContext": msg,
			},
		}))


if __name__ == "__main__":
	main()
