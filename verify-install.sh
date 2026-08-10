#!/bin/bash
# Doctor script: checks every project registered in projects.txt actually has
# working skill wiring, instead of failing silently. Run any time you suspect
# a teammate (or you, on a new machine) got "zero benefit" from this repo
# without any warning that something's misconfigured.
#
# Usage: ~/.claude-skills/verify-install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENTRAL_SKILLS_DIR="$SCRIPT_DIR/skills"
PROJECTS_REGISTRY="$SCRIPT_DIR/projects.txt"

declare -A TOOL_PATHS=(
	["Claude"]=".claude/skills"
	["Kiro"]=".kiro/steering"
	["AmazonQ"]=".amazonq/rules"
)
declare -A TOOL_MEMORY_FILES=(
	["Claude"]="CLAUDE.md"
	["Kiro"]=".kiro/steering/index.md"
	["AmazonQ"]=".amazonq/rules/index.md"
)

TOTAL_FAILURES=0

if [ ! -f "$PROJECTS_REGISTRY" ]; then
	echo "No projects.txt found at $PROJECTS_REGISTRY — nothing registered yet."
	exit 0
fi

CENTRAL_SKILLS=()
if [ -d "$CENTRAL_SKILLS_DIR" ]; then
	for d in "$CENTRAL_SKILLS_DIR"/*/; do
		CENTRAL_SKILLS+=("$(basename "$d")")
	done
fi

while IFS= read -r PROJECT_ROOT; do
	[ -z "$PROJECT_ROOT" ] && continue
	echo "=== $PROJECT_ROOT ==="

	if [ ! -d "$PROJECT_ROOT" ]; then
		echo "  ✗ Project directory does not exist (stale registry entry)"
		TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
		echo ""
		continue
	fi

	FOUND_ANY_TOOL=false
	for TOOL in "${!TOOL_PATHS[@]}"; do
		TARGET_DIR="$PROJECT_ROOT/${TOOL_PATHS[$TOOL]}"
		[ ! -d "$TARGET_DIR" ] && continue
		FOUND_ANY_TOOL=true

		MISSING=()
		BROKEN=()
		for SKILL in "${CENTRAL_SKILLS[@]}"; do
			LINK="$TARGET_DIR/$SKILL"
			if [ ! -e "$LINK" ] && [ ! -L "$LINK" ]; then
				MISSING+=("$SKILL")
			elif [ -L "$LINK" ] && [ ! -e "$LINK" ]; then
				BROKEN+=("$SKILL")
			fi
		done

		if [ ${#MISSING[@]} -eq 0 ] && [ ${#BROKEN[@]} -eq 0 ]; then
			echo "  ✓ $TOOL: all ${#CENTRAL_SKILLS[@]} skills symlinked and resolving"
		else
			[ ${#MISSING[@]} -gt 0 ] && echo "  ✗ $TOOL: missing symlinks for: ${MISSING[*]}" && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
			[ ${#BROKEN[@]} -gt 0 ] && echo "  ✗ $TOOL: broken symlinks (target deleted?) for: ${BROKEN[*]}" && TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
			echo "    Fix: run $SCRIPT_DIR/install-skills.sh from $PROJECT_ROOT"
		fi

		MEMORY_FILE="$PROJECT_ROOT/${TOOL_MEMORY_FILES[$TOOL]}"
		if [ "$TOOL" = "Claude" ]; then
			if [ -f "$MEMORY_FILE" ] && grep -q "index.md" "$MEMORY_FILE"; then
				echo "  ✓ $TOOL: $MEMORY_FILE includes index.md"
			else
				echo "  ✗ $TOOL: $MEMORY_FILE missing or doesn't include index.md — rules silently won't load"
				TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
			fi
		fi
	done

	if [ "$FOUND_ANY_TOOL" = false ]; then
		echo "  ✗ No tool skill directory found (.claude/skills, .kiro/steering, .amazonq/rules) — installer was never run here"
		TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
	fi
	echo ""
done < "$PROJECTS_REGISTRY"

if [ "$TOTAL_FAILURES" -eq 0 ]; then
	echo "All registered projects verified clean."
	exit 0
else
	echo "$TOTAL_FAILURES issue(s) found across registered projects."
	exit 1
fi
