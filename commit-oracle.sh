#!/bin/bash

# Check if the current directory is a Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This is not a Git repository."
  exit 1
fi

# Check if there are any staged changes
if git diff --cached --quiet; then
  echo "No staged changes detected. Nothing to commit."
  exit 0
fi

selected_commit_message=$(aichat "IMPORTANT: Generate exactly 5 NEW commit messages based on the provided diff, plus 1 additional multi-type message if appropriate.

ANALYZE THIS DIFF AND GENERATE APPROPRIATE COMMIT MESSAGES:
$(git --no-pager diff --no-color --no-ext-diff --cached)

RECENT COMMITS FOR REFERENCE:
$(git log -n 10 --pretty=format:'%h %s')

OUTPUT RULES:
- Start IMMEDIATELY with the first commit message
- Separate messages ONLY with three hyphens (---)
- NO markdown, NO numbering, NO extra text
- Messages must be relevant to the actual diff provided
- Generate completely new messages, DO NOT copy examples
- If multiple distinct changes are present, add a 6th message combining max 2 types

COMMIT MESSAGE FORMAT:
<type>[optional scope]: <description>
[optional body]
[optional footer]

For multi-type commits (if needed), use format:
<type>[optional scope]: <description>
<type>[optional scope]: <description>

FORMAT EXAMPLES (DO NOT COPY THESE - CREATE NEW ONES BASED ON THE DIFF):
feat(auth): add password reset flow

Added secure token generation and email delivery system.

BREAKING CHANGE: Changed password reset API endpoint
---
fix(db): resolve deadlock in transaction handler

Protected critical section with mutex to prevent concurrent access issues.
---
feat(config): add new environment variables
fix(config): correct variable naming

Your response must:
1. Start directly with first commit message
2. Be based on the actual diff content
3. Use conventional commit format
4. NOT copy example messages
5. Include a 6th multi-type message ONLY if the diff contains multiple distinct changes" |
  awk 'BEGIN {RS="---"} NF {sub(/^\n+/, ""); printf "%s%c", $0, 0}' |
  fzf --height 20 --border --ansi --read0 --no-sort \
    --with-nth=1 --delimiter='\n' \
    --preview 'echo {}' \
    --preview-window=up:wrap)

if [ -z "$selected_commit_message" ]; then
  echo "No commit message selected."
  exit 0
fi

COMMIT_MSG_FILE=$(mktemp)
printf "%s" "$selected_commit_message" >"$COMMIT_MSG_FILE"

# Store initial checksum
CHECKSUM_BEFORE=$(shasum "$COMMIT_MSG_FILE" | awk '{ print $1 }')

# Open the editor
"${EDITOR:-vim}" "$COMMIT_MSG_FILE"

# Store checksum after editing
CHECKSUM_AFTER=$(shasum "$COMMIT_MSG_FILE" | awk '{ print $1 }')

# Compare checksums
if [ "$CHECKSUM_BEFORE" != "$CHECKSUM_AFTER" ]; then
  # Proceed with commit
  git commit -F "$COMMIT_MSG_FILE"
else
  echo "Commit message was not saved or modified, commit aborted."
  exit 0
fi

# Clean up
rm -f "$COMMIT_MSG_FILE"
