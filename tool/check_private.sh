#!/bin/sh
# Blocks personal data from the public repository. Reads the index, so the
# pre-commit hook sees what is staged and CI sees what was pushed.
# --history also scans every commit: a file added and then deleted inside one
# push never reaches the tip, yet stays public in the history.
# Every git call is captured in a plain assignment so that set -e stops on a
# git failure instead of reading the empty output as "no leak".
set -e
team_id='(DEVELOPMENT_TEAM|DevelopmentTeam)(\[[^]]*\])*"?[[:space:]]*=[[:space:]]*"?[A-Z0-9]'
private_files='^assets/private/\.gitkeep$'
if [ "${1:-}" = "--history" ]; then
  shallow=$(git rev-parse --is-shallow-repository)
  if [ "$shallow" != false ]; then
    echo "浅いクローンでは履歴を検査できません（fetch-depth: 0 で取得してください）" >&2
    exit 1
  fi
  # git log shows no diff for merge commits unless asked, and without
  # --full-history it skips side branches whose changes cancel out.
  names=$(git log --all --full-history --diff-merges=separate --format= --name-only -- assets/private ios/Flutter/DevelopmentTeam.xcconfig)
  leaked=$(printf '%s\n' "$names" | grep -v -e '^$' -e "$private_files" | sort -u || true)
  if [ -n "$leaked" ]; then
    echo "履歴に公開してはいけないファイルがあります:" >&2
    echo "$leaked" >&2
    exit 1
  fi
  patches=$(git log --all --full-history --diff-merges=separate -p --format= -- 'ios/*.pbxproj' 'ios/*.xcconfig')
  if printf '%s\n' "$patches" | grep -Eqi "^[+-].*$team_id"; then
    echo "履歴に Team ID が入っています" >&2
    exit 1
  fi
fi
tracked=$(git ls-files assets/private)
leaked=$(printf '%s\n' "$tracked" | grep -v -e '^$' -e "$private_files" || true)
if [ -n "$leaked" ]; then
  echo "assets/private/ のファイルは commit できません:" >&2
  echo "$leaked" >&2
  exit 1
fi
staged=$(git grep --cached -h -e '' -- 'ios/*.pbxproj' 'ios/*.xcconfig')
if printf '%s\n' "$staged" | grep -Eqi "$team_id"; then
  echo "ios/ の追跡ファイルに Team ID が入っています。ios/Flutter/DevelopmentTeam.xcconfig（git 管理外）に移してください" >&2
  exit 1
fi
