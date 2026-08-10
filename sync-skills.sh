#!/bin/bash
# Non-interactive sync: for every project in projects.txt, for every tool
# directory that ALREADY exists there (signal that the project uses that
# tool), symlink any central skill missing from it. Never prompts, never
# removes anything, never adds a new tool a project didn't already opt into.
# Safe to run unattended from a post-merge hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENTRAL_SKILLS_DIR="$SCRIPT_DIR/skills"
PROJECTS_REGISTRY="$SCRIPT_DIR/projects.txt"

declare -A TOOL_PATHS=(
	["Claude"]=".claude/skills"
	["Kiro"]=".kiro/steering"
	["AmazonQ"]=".amazonq/rules"
)

[ ! -f "$PROJECTS_REGISTRY" ] && exit 0
[ ! -d "$CENTRAL_SKILLS_DIR" ] && exit 0

while IFS= read -r PROJECT_ROOT; do
	[ -z "$PROJECT_ROOT" ] && continue
	[ ! -d "$PROJECT_ROOT" ] && continue

	for TOOL in "${!TOOL_PATHS[@]}"; do
		TARGET_DIR="$PROJECT_ROOT/${TOOL_PATHS[$TOOL]}"
		[ ! -d "$TARGET_DIR" ] && continue

		for SKILL_DIR in "$CENTRAL_SKILLS_DIR"/*/; do
			SKILL="$(basename "$SKILL_DIR")"
			LINK="$TARGET_DIR/$SKILL"
			if [ ! -e "$LINK" ] && [ ! -L "$LINK" ]; then
				ln -s "$CENTRAL_SKILLS_DIR/$SKILL" "$LINK"
				echo "  + synced $SKILL -> $LINK"
			fi
		done
	done
done < "$PROJECTS_REGISTRY"
