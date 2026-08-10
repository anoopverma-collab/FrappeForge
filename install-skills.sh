#!/bin/bash

# =============================================================================
# install-skills.sh (v4 - Multi-LLM + Registry + Detailed Reporting)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENTRAL_SKILLS_DIR="$SCRIPT_DIR/skills"
PROJECTS_REGISTRY="$SCRIPT_DIR/projects.txt"
PROJECT_ROOT="$(pwd)"

# 0. Wire up the tracked post-merge hook (idempotent — safe to re-run)
if [ -d "$SCRIPT_DIR/.git" ]; then
    (cd "$SCRIPT_DIR" && git config core.hooksPath githooks)
fi

# 1. Define Supported Tools
declare -A TOOL_PATHS=(
    ["Claude"]=".claude/skills"
    ["Kiro"]=".kiro/steering"
    ["AmazonQ"]=".amazonq/rules"
)

# 2. Interactive Toggle Menu (no external dependencies)
options=("Claude" "Kiro" "AmazonQ")
selections=(true true false)
SELECTED_TOOLS=()

echo -e "\033[1;34m? \033[1;37mSelect which LLM you use, the skills will be setup accordingly.\033[0m"
echo -e "  \033[90mThis is multi-select: press a number to toggle, Enter to confirm.\033[0m"
echo -en "\033[s"

while true; do
    echo -en "\033[u\033[J"

    max_len=0
    for opt in "${options[@]}"; do
        [ ${#opt} -gt $max_len ] && max_len=${#opt}
    done

    for i in "${!options[@]}"; do
        label="${options[$i]}"
        path="${TOOL_PATHS[$label]}"
        padded=$(printf "%-${max_len}s" "$label")
        if [ "${selections[$i]}" = true ]; then
            echo -e "  \033[32m[x]\033[0m $((i+1)). $padded \033[90m($path)\033[0m"
        else
            echo -e "  \033[90m[ ] $((i+1)). $padded ($path)\033[0m"
        fi
    done

    read -n 1 -p "Toggle (1-${#options[@]}) or Enter to finish: " key

    case $key in
        1) selections[0]=$([ "${selections[0]}" = true ] && echo false || echo true) ;;
        2) selections[1]=$([ "${selections[1]}" = true ] && echo false || echo true) ;;
        3) selections[2]=$([ "${selections[2]}" = true ] && echo false || echo true) ;;
        "")
            echo -e "\n"
            break
            ;;
    esac
done

# Build the final list
for i in "${!options[@]}"; do
    [ "${selections[$i]}" = true ] && SELECTED_TOOLS+=("${options[$i]}")
done

if [ ${#SELECTED_TOOLS[@]} -eq 0 ]; then
    echo "No tools selected. Exiting."
    exit 1
fi

echo ""
echo "======================================"
echo "  Central AI Rules — Deployment       "
echo "======================================"
echo ""

# 3. Execution & Reporting
for TOOL in "${SELECTED_TOOLS[@]}"; do
    TARGET_DIR="$PROJECT_ROOT/${TOOL_PATHS[$TOOL]}"
    mkdir -p "$TARGET_DIR"
    echo "--- Configuring $TOOL (${TOOL_PATHS[$TOOL]}) ---"

    linked=()
    skipped=()
    conflicts=()

    for skill_path in "$CENTRAL_SKILLS_DIR"/*/; do
        [ -d "$skill_path" ] || continue
        skill_path="${skill_path%/}"
        skill_name=$(basename "$skill_path")
        target="$TARGET_DIR/$skill_name"

        if [ -L "$target" ]; then
            skipped+=("$skill_name")
        elif [ -d "$target" ]; then
            conflicts+=("$skill_name")
        else
            ln -sfn "$skill_path" "$target"
            linked+=("$skill_name")
        fi
    done

    if [ ${#linked[@]} -gt 0 ]; then
        echo "  Linked:"
        for s in "${linked[@]}"; do echo "    + $s"; done
        echo ""
    fi

    if [ ${#skipped[@]} -gt 0 ]; then
        echo "  Already linked (skipped):"
        for s in "${skipped[@]}"; do echo "    = $s"; done
        echo ""
    fi

    if [ ${#conflicts[@]} -gt 0 ]; then
        echo "  Conflicts — real folders found with same name as central skills:"
        echo "    These were NOT symlinked. Delete the folder and re-run to use the"
        echo "    central version, or keep the folder to use your local version."
        echo ""
        for s in "${conflicts[@]}"; do echo "    ! $TARGET_DIR/$s"; done
        echo ""
    fi
done

# 4. Project Registry
echo "Registering project..."
touch "$PROJECTS_REGISTRY"
if grep -qxF "$PROJECT_ROOT" "$PROJECTS_REGISTRY"; then
    echo "  (already registered)"
else
    echo "$PROJECT_ROOT" >> "$PROJECTS_REGISTRY"
    sort -u -o "$PROJECTS_REGISTRY" "$PROJECTS_REGISTRY"
    echo "  ✓ Registered: $PROJECT_ROOT"
fi
echo ""

# 5. Smart .gitignore Update
echo "Updating .gitignore..."
for TOOL in "${SELECTED_TOOLS[@]}"; do
    IGNORE_PATH="${TOOL_PATHS[$TOOL]}"
    if [ -f "$PROJECT_ROOT/.gitignore" ]; then
        if grep -q "^$IGNORE_PATH" "$PROJECT_ROOT/.gitignore"; then
            echo "  = $IGNORE_PATH (already in .gitignore)"
        else
            echo "$IGNORE_PATH" >> "$PROJECT_ROOT/.gitignore"
            echo "  + $IGNORE_PATH (added to .gitignore)"
        fi
    else
        echo "$IGNORE_PATH" > "$PROJECT_ROOT/.gitignore"
        echo "  + .gitignore created with $IGNORE_PATH"
    fi
done

echo -e "\nDone. Your skills are synced and the project is registered."
