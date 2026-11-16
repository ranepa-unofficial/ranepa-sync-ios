#!/bin/sh
# PreToolUse(Bash): коммиты, теги, PR и релизы в этом репозитории — без атрибуции ИИ.
input=$(cat)
printf '%s' "$input" | grep -qE 'git (commit|tag)|gh (pr|release) (create|edit)' || exit 0
if printf '%s' "$input" | grep -qiE 'co-authored-by|generated with \[?claude|noreply@anthropic\.com'; then
  echo "В этом репозитории коммиты и PR без атрибуции ИИ: убери Co-Authored-By и «Generated with Claude Code»." >&2
  exit 2
fi
exit 0
