#!/usr/bin/env bash

# generate-deployment-packages.sh
# Creates .zip distribution packages for all skills in the skills/ directory.
# Each package contains SKILL.md, README.md, and metadata.json.
# File timestamps are set to the last git commit date for the skill.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"
TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Generating deployment packages..."
echo "Repo root: $REPO_ROOT"
echo "Skills directory: $SKILLS_DIR"
echo

# Find all skill directories (containing SKILL.md)
for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -f "${skill_dir}SKILL.md" ]]; then
        skill_name=$(basename "$skill_dir")
        zip_file="${SKILLS_DIR}/${skill_name}.zip"

        echo "Packaging $skill_name..."

        # Get last commit timestamp for this skill
        commit_ts=$(git log -1 --format=%ct -- "$skill_dir" 2>/dev/null || echo "0")
        if [[ "$commit_ts" == "0" ]]; then
            echo "  Warning: No git history found, using current time"
            commit_ts=$(date +%s)
        fi

        commit_date=$(date -r "$commit_ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$commit_ts" "+%Y-%m-%d %H:%M:%S")
        echo "  Last commit: $commit_date"

        # Create temp dir for this skill
        skill_temp="$TEMP_DIR/$skill_name"
        rm -rf "$skill_temp"
        mkdir -p "$skill_temp"

        # Copy skill files
        for file in SKILL.md README.md metadata.json; do
            if [[ -f "${skill_dir}${file}" ]]; then
                cp "${skill_dir}${file}" "$skill_temp/"

                # Set file times to commit timestamp
                # macOS: touch -t [[[[cc]yy]mm]dd]HH.MM[.SS]
                # Linux: touch -d @timestamp
                if [[ "$(uname)" == "Darwin" ]]; then
                    touch_date=$(date -r "$commit_ts" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$commit_ts" +%Y%m%d%H%M.%S)
                    touch -t "$touch_date" "$skill_temp/$file"
                else
                    touch -d "@$commit_ts" "$skill_temp/$file"
                fi
            fi
        done

        # Create zip from temp dir (files at root, no directory prefix)
        (
            cd "$skill_temp"
            zip -q -j "$zip_file" SKILL.md README.md metadata.json 2>/dev/null || true
        )

        # Verify the zip was created
        if [[ -f "$zip_file" ]]; then
            size=$(du -h "$zip_file" | cut -f1)
            echo "  Created: $zip_file ($size)"
        else
            echo "  Warning: Failed to create $zip_file"
        fi
    fi
done

echo
echo "Done!"
