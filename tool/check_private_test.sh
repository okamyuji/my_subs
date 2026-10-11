#!/bin/sh
# Regression test for check_private.sh. Builds leak histories in throwaway
# clones of this repository and expects each one to be rejected.
# set -e makes a failing setup step fail the test instead of quietly
# testing a different history.
set -eu
REPO=$(cd "$(dirname "$0")/.." && pwd)
CHECK=$REPO/tool/check_private.sh
W=$(mktemp -d)
trap 'cd / && rm -rf "$W"' EXIT
P=ios/Runner.xcodeproj/project.pbxproj
failed=0

# A pull_request checkout is a detached merge ref with no local branch, so the
# clone gets an explicit main.
fresh() {
  cd / && rm -rf "$W/c" "$W/s" && git clone -q "$REPO" "$W/c" && cd "$W/c" &&
    git checkout -q -B main && git config core.hooksPath /dev/null &&
    git config commit.gpgsign false && git config user.email t@example.invalid &&
    git config user.name t
}
# expect <dir> <want> <name> [args]; want "nz" accepts any failure, such as
# git's own exit code. SHIM puts a failing git first on PATH.
expect() {
  got=0
  (cd "$1" && PATH="${SHIM:-}$PATH" sh "$CHECK" ${4---history} >/dev/null 2>&1) || got=$?
  if [ "$got" = "$2" ] || { [ "$2" = nz ] && [ "$got" -ne 0 ]; }; then
    echo "ok   $3"
  else
    echo "FAIL $3 (exit $got, want $2)"
    failed=1
  fi
}
evil_merge() {
  git checkout -q side && git commit -q --allow-empty -m "s$1" && git checkout -q main
  git merge -q --no-ff --no-commit side >/dev/null 2>&1
}
team_id_line() { printf '\t\tDEVELOPMENT_TEAM = "XQ7ZK2M4PA";\n' >> $P && git add $P; }

fresh
expect "$W/c" 0 "clean history passes"
expect "$W/c" 0 "clean index passes" ""
echo '{}' > assets/private/i.json && git add -f assets/private/i.json
expect "$W/c" 1 "staged private file is rejected" ""

fresh
team_id_line
expect "$W/c" 1 "staged quoted team id is rejected" ""

fresh
git rm -q -- 'ios/*.pbxproj' 'ios/*.xcconfig'
expect "$W/c" 0 "index without ios project files passes" ""

fresh
echo '{}' > assets/private/a.json && git add -f assets/private/a.json && git commit -q -m leak
git rm -q assets/private/a.json && git commit -q -m remove
expect "$W/c" 1 "file added then removed"

fresh
team_id_line && git commit -q -m tid -- $P && git revert --no-edit HEAD >/dev/null
expect "$W/c" 1 "team id added then reverted"

fresh
git branch side
evil_merge 1 && echo '{}' > assets/private/m.json && git add -f assets/private/m.json && git commit -q -m merge-add
evil_merge 2 && git rm -q assets/private/m.json && git commit -q -m merge-remove
expect "$W/c" 1 "file added and removed inside merges"

fresh
git branch side
evil_merge 1 && team_id_line && git commit -q -m merge-add
evil_merge 2 && git checkout -q HEAD~1 -- $P && git add $P && git commit -q -m merge-remove
expect "$W/c" 1 "team id added and removed inside merges"

fresh
git checkout -q -b side
echo '{}' > assets/private/x.json && git add -f assets/private/x.json && git commit -q -m add
git rm -q assets/private/x.json && git commit -q -m rm
git checkout -q main && git commit -q --allow-empty -m m && git merge -q --no-ff -m merge side && git branch -q -D side
expect "$W/c" 1 "file added and removed on a merged side branch"

fresh
echo '{}' > assets/private/s.json && git add -f assets/private/s.json && git commit -q -m leak
git rm -q assets/private/s.json && git commit -q -m remove
git clone -q --depth 1 "file://$W/c" "$W/s"
expect "$W/s" 1 "shallow clone is rejected"

# Each git call must stop the check when it fails, so each one gets its own case.
fresh
mkdir "$W/shim"
printf '#!/bin/sh\ncase " $* " in $FAIL_ON) exit 129;; esac\nexec "%s" "$@"\n' "$(command -v git)" > "$W/shim/git"
chmod +x "$W/shim/git"
SHIM="$W/shim:"
export FAIL_ON
for FAIL_ON in '* rev-parse *' '* --name-only *' '* -p *' '* ls-files assets/private *' '* ls-files -- *' '* grep *'; do
  expect "$W/c" nz "failing git ($FAIL_ON) is not a pass"
done

exit $failed
