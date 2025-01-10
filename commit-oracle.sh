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

selected_commit_message=$(
  aichat "IMPORTANT:
1) Begin immediately with the first commit message—no greetings, no commentary.
2) Your commit messages must be based on the DIFF alone; recent commits and examples are only for context. DO NOT copy or repeat them.
3) Generate between 1 and 5 single-type commits based on the DIFF. If MULTIPLE distinct changes are present, add 1 additional multi-type commit (total up to 6). 
4) Use only these types: feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert.
5) Separate each commit message ONLY with a line containing exactly three hyphens (---), no other text or spacing.
6) For single-type commit: 
   <type>(<optional-scope>): <short description> 
   <optional-body>
   <optional-footer>
7) For a multi-type commit, format it as exactly two lines, each line a conventional commit header, for example:
  <type>(<optional-scope>): <description>
  <type>(<optional-scope>/<optional-scope>): <description>
8) No numbering (e.g., no '1/5'), no extra text, no markdown, no commentary.
9) Do not hallucinate or create low-quality commit-messages.
  It is preferable to have less or no commit messages at all than to receive numerous low-quality ones.

EXAMPLE COMMITS:
feat(auth): add password reset flow

Added secure token generation and email delivery system.

BREAKING CHANGE: Changed password reset API endpoint
---
fix(db): resolve deadlock in transaction handler

Protected critical section with mutex to prevent concurrent access issues.
---
feat(config): add new environment variables
fix(config): correct variable naming

RECENT COMMITS:
$(git log -n 10 --pretty=format:'%h %s')

ANALYZE THIS DIFF:
$(git --no-pager diff --no-color --no-ext-diff --cached)
" |
    awk 'BEGIN {RS="---"} NF {
    sub(/^[[:space:]-]+/, "");  # remove leading spaces/dashes  
    sub(/[[:space:]]+$/, "");   # remove trailing spaces  
    printf "%s%c", $0, 0
  }' |
    fzf --height 20 --border --ansi --read0 --no-sort \
      --with-nth=1 --delimiter='\n' \
      --preview 'echo {}' \
      --preview-window=up:wrap
)

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
