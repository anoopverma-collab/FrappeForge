#!/usr/bin/env python3
"""Automated tests for frappe_ladder_check.py — run before merging any
change to the checker script, since it's wired as an always-on hook and
a false positive or crash there hits every edit in every bench."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "frappe_ladder_check.py")


def run(path):
	result = subprocess.run(
		[sys.executable, SCRIPT, path], capture_output=True, text=True, timeout=5
	)
	assert result.returncode == 0, f"non-zero exit: {result.stderr}"
	return result.stdout.strip()


def write(tmpdir, rel_path, content):
	full = os.path.join(tmpdir, "apps", rel_path)
	os.makedirs(os.path.dirname(full), exist_ok=True)
	with open(full, "w") as f:
		f.write(content)
	return full


class TestFrappeLadderCheck(unittest.TestCase):
	def setUp(self):
		self.tmpdir = tempfile.mkdtemp()

	def findings(self, rel_path, content):
		path = write(self.tmpdir, rel_path, content)
		out = run(path)
		if not out:
			return ""
		return json.loads(out)["systemMessage"]

	def test_ignores_files_outside_apps(self):
		outside = os.path.join(self.tmpdir, "not_apps", "x.py")
		os.makedirs(os.path.dirname(outside), exist_ok=True)
		with open(outside, "w") as f:
			f.write("frappe.db.sql('select 1')")
		self.assertEqual(run(outside), "")

	def test_ignores_non_py_non_json(self):
		out = write(self.tmpdir, "myapp/notes.md", "frappe.db.sql('select 1')\n")
		self.assertEqual(run(out), "")

	def test_clean_file_produces_no_findings(self):
		content = "import frappe\n\ndef foo():\n\treturn frappe.get_all('Supplier')\n"
		self.assertEqual(self.findings("myapp/clean.py", content), "")

	def test_flags_raw_sql(self):
		content = "import frappe\n\ndef foo():\n\treturn frappe.db.sql('select 1')\n"
		findings = self.findings("myapp/sql.py", content)
		self.assertIn("frappe.db.sql", findings)

	def test_flags_db_call_in_loop(self):
		content = (
			"import frappe\n\n"
			"def foo(vendors):\n"
			"\tfor v in vendors:\n"
			"\t\tif frappe.db.exists('Supplier', v):\n"
			"\t\t\tpass\n"
		)
		findings = self.findings("myapp/loop.py", content)
		self.assertIn("DB call inside a loop", findings)

	def test_does_not_flag_db_call_outside_loop(self):
		content = (
			"import frappe\n\n"
			"def foo(vendors):\n"
			"\tfor v in vendors:\n"
			"\t\tpass\n"
			"\treturn frappe.db.exists('Supplier', vendors[0])\n"
		)
		self.assertEqual(self.findings("myapp/no_loop.py", content), "")

	def test_flags_whitelisted_doc_op_without_permission_check(self):
		content = (
			"import frappe\n\n"
			"@frappe.whitelist()\n"
			"def approve(name):\n"
			"\tdoc = frappe.get_doc('Vendor Onboarding Request', name)\n"
			"\tdoc.save()\n"
		)
		findings = self.findings("myapp/api.py", content)
		self.assertIn("has_permission", findings)

	def test_does_not_flag_whitelisted_method_with_permission_check(self):
		content = (
			"import frappe\n\n"
			"@frappe.whitelist()\n"
			"def approve(name):\n"
			"\tif not frappe.has_permission('Vendor Onboarding Request', 'write'):\n"
			"\t\tfrappe.throw('Not allowed')\n"
			"\tdoc = frappe.get_doc('Vendor Onboarding Request', name)\n"
			"\tdoc.save()\n"
		)
		self.assertEqual(self.findings("myapp/api_ok.py", content), "")

	def test_flags_hand_edited_doctype_json(self):
		content = json.dumps({"doctype": "DocType", "name": "Foo"})
		findings = self.findings("myapp/myapp/doctype/foo/foo.json", content)
		self.assertIn("DocType JSON", findings)

	def test_does_not_flag_test_records_json(self):
		content = json.dumps([{"doctype": "Foo", "field": "value"}])
		out = write(self.tmpdir, "myapp/myapp/doctype/foo/test_records.json", content)
		self.assertEqual(run(out), "")

	def test_flags_top_level_import_in_server_script_field(self):
		content = json.dumps({"doctype": "Server Script", "script": "import os\nfrappe.msgprint('hi')"})
		findings = self.findings("myapp/fixtures/server_script.json", content)
		self.assertIn("top-level import", findings)

	def test_handles_malformed_json_without_crashing(self):
		out = write(self.tmpdir, "myapp/broken.json", "{not valid json")
		self.assertEqual(run(out), "")

	def test_handles_nonexistent_file_without_crashing(self):
		self.assertEqual(run(os.path.join(self.tmpdir, "apps/myapp/missing.py")), "")


if __name__ == "__main__":
	unittest.main()
