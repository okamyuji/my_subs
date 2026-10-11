#!/bin/sh
# Blocks personal data from the public repository. Reads the index, so the
# pre-commit hook sees what is staged and CI sees what was pushed.
# --history also scans every commit: a file added and then deleted inside one
# push never reaches the tip, yet stays public in the history.
set -e
team_id='(DEVELOPMENT_TEAM|DevelopmentTeam)(\[[^]]*\])*"?[[:space:]]*=[[:space:]]*"?[A-Z0-9]'
if [ "$1" = "--history" ]; then
  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "浅いクローンでは履歴を検査できません（fetch-depth: 0 で取得してください）" >&2
    exit 1
  fi
  # git log shows no diff for merge commits unless asked.
  leaked=$(git log --all --diff-merges=separate --format= --name-only -- assets/private ios/Flutter/DevelopmentTeam.xcconfig \
    | grep -v -e '^$' -e '^assets/private/\.gitkeep$' | sort -u || true)
  if [ -n "$leaked" ]; then
    echo "履歴に公開してはいけないファイルがあります:" >&2
    echo "$leaked" >&2
    exit 1
  fi
  if git log --all -p --diff-merges=separate --format= -- 'ios/*.pbxproj' 'ios/*.xcconfig' | grep -Eqi "^[+-].*$team_id"; then
    echo "履歴に Team ID が入っています" >&2
    exit 1
  fi
fi
leaked=$(git ls-files assets/private | grep -v '^assets/private/\.gitkeep$' || true)
if [ -n "$leaked" ]; then
  echo "assets/private/ のファイルは commit できません:" >&2
  echo "$leaked" >&2
  exit 1
fi
if git grep --cached -Eqi "$team_id" -- 'ios/*.pbxproj' 'ios/*.xcconfig'; then
  echo "ios/ の追跡ファイルに Team ID が入っています。ios/Flutter/DevelopmentTeam.xcconfig（git 管理外）に移してください" >&2
  exit 1
fi
