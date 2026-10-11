#!/bin/sh
# Blocks personal data from the public repository. Reads the index, so the
# pre-commit hook sees what is staged and CI sees what was pushed.
set -e
leaked=$(git ls-files assets/private | grep -v '^assets/private/\.gitkeep$' || true)
if [ -n "$leaked" ]; then
  echo "assets/private/ のファイルは commit できません:" >&2
  echo "$leaked" >&2
  exit 1
fi
if git grep --cached -Eqi '(DEVELOPMENT_TEAM|DevelopmentTeam)(\[[^]]*\])*"?[[:space:]]*=[[:space:]]*"?[A-Z0-9]' -- 'ios/*.pbxproj' 'ios/*.xcconfig'; then
  echo "ios/ の追跡ファイルに Team ID が入っています。ios/Flutter/DevelopmentTeam.xcconfig（git 管理外）に移してください" >&2
  exit 1
fi
