#!/usr/bin/env bash
# THE SUITE RUNNER (QA). Until now the studio had no runner in the repo at all --
# every session re-invented a loop over all_test_files.txt, which is a large part
# of why registry drift went unnoticed twice.
#
#   bash tool_run_suite.sh [name-filter]
#
# Runs every test named in all_test_files.txt through the MONARCH_TEST hook, one
# Godot process per test, and exits non-zero if any of them failed.
#
# THREE THINGS THIS RUNNER KNOWS THAT A BARE LOOP DOES NOT
#
# 1. A PARSE ERROR IS NOT A TIMEOUT. A test that does not compile attaches
#    nothing, the menu idles, and the run looks like a six-minute hang. The
#    runner caps each test and says PARSE/HANG instead of letting you guess.
#
# 2. A CRASH AT EXIT IS NOT A TEST FAILURE. Every driver ends by printing
#    "RESULT: ..." and calling get_tree().quit(). If a run exits non-zero and its
#    log has NO RESULT line, the test never reported -- the process died. Since
#    stderr is fully buffered when it is redirected to a file, an abnormal exit
#    silently discards everything after the engine banner, leaving a ~73-byte log
#    (banner + blank line) and exit 1. That is the known `test_arrival_node`
#    transient. It is reported as CRASH, separately from FAIL, and retried once.
#
# 3. THE COUNT MUST MATCH THE REGISTRY. If the number of tests run is not the
#    number of names in all_test_files.txt, the suite covered less than it says.
#    (test_registry_node.gd is the in-engine half of this guard.)

FILTER="${1:-}"
GODOT="${GODOT_BIN:-C:/Users/bacho/Desktop/Godot.exe}"
REPO="$(cd "$(dirname "$0")" && pwd)"
LOGS="${SUITE_LOGS:-$REPO/.suite_logs}"
PER_TEST_TIMEOUT="${SUITE_TIMEOUT:-360}"

cd "$REPO" || exit 2
rm -rf "$LOGS"; mkdir -p "$LOGS"

# PRE-FLIGHT: the import cache. On a checkout with no .godot, the very first
# thing that happens is NOT a slow run -- it is a silent, total one:
#
#   art/fonts/PixelifySans.ttf is unimported -> the preload at
#   mobile/touch_controls.gd:31 fails -> "Cannot infer the type of GAME_FONT
#   constant" (this project's house rule 1, triggered by a missing resource,
#   not by the code) -> the script fails to parse -> it is an AUTOLOAD, so
#   every autoload dies with it -> GameState is Nil -> main_menu.gd:52 throws
#   before it can attach the test driver -> AND THE PROCESS EXITS 0.
#
# Every test in the suite would report ok having run nothing at all. Import
# first, once, so that cannot be the state we measure.
if [ ! -d "$REPO/.godot" ]; then
	echo "note  no .godot import cache — importing once before the suite (this takes a few minutes)"
	"$GODOT" --headless --path . --import > "$LOGS/_import.log" 2>&1 \
		|| { echo "FATAL import failed, see $LOGS/_import.log"; exit 2; }
fi

# PRE-FLIGHT: the .uid siblings. Godot writes a .gd.uid next to every script and
# this repo tracks all of them, so a test committed without its .uid leaves every
# clean clone with a dirty tree the moment it imports. Same shape of drift as the
# registry -- two files that must travel together, and one got left behind. A
# warning, not a failure: it costs nobody a test run, it just rots the tree.
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
	orphans=""
	for gd in $(git -C "$REPO" ls-files 'test_*.gd'); do
		git -C "$REPO" ls-files --error-unmatch "$gd.uid" >/dev/null 2>&1 || orphans="$orphans ${gd%.gd}"
	done
	[ -n "$orphans" ] && echo "warn  tracked test scripts with NO tracked .gd.uid sibling:$orphans"
fi

registered=0
pass=0; fail=0; crash=0
failed_names=""; crashed_names=""

run_one() {   # $1 = test name, $2 = log path
	timeout "$PER_TEST_TIMEOUT" env MONARCH_TEST="res://$1.gd" \
		"$GODOT" --headless --path . > "$2" 2>&1
}

while IFS= read -r raw; do
	name="$(printf '%s' "$raw" | tr -d '\r' | tr -d '[:space:]')"
	[ -z "$name" ] && continue
	registered=$((registered+1))
	if [ -n "$FILTER" ] && [ "${name#*$FILTER}" = "$name" ]; then continue; fi

	log="$LOGS/$name.log"

	# A REGISTERED NAME WITH NO FILE COSTS A FULL TIMEOUT AND SAYS NOTHING.
	# main_menu.gd guards the hook on ResourceLoader.exists(), so a missing script
	# attaches no driver, the menu idles, and this reads as a six-minute hang. Cost
	# nothing to check first, and say the true thing. (test_registry_node.gd is the
	# in-engine half of this; here it saves the six minutes.)
	if [ ! -f "$name.gd" ]; then
		fail=$((fail+1)); failed_names="$failed_names $name"
		printf 'FAIL  %-32s NO SUCH FILE — registered in all_test_files.txt, not on disk\n' "$name"
		continue
	fi

	run_one "$name" "$log"; rc=$?

	# A PASS IS A REPORTED PASS. Exit 0 is not evidence on its own: if the
	# autoloads fail to instantiate, main_menu.gd throws before it can attach the
	# driver and the process still exits 0, so a suite that trusts the exit code
	# reports ok for every test having run none of them. Every driver ends by
	# printing "RESULT:", so demand it in both directions, not only on failure.
	if [ "$rc" -eq 0 ]; then
		if grep -q 'RESULT:' "$log"; then
			pass=$((pass+1)); printf 'ok    %s\n' "$name"; continue
		fi
		crash=$((crash+1)); crashed_names="$crashed_names $name"
		printf 'CRASH %-32s exit 0 but NO RESULT — it never reported, so it never ran\n' "$name"
		grep -m 3 -iE 'parse error|autoload|base .Nil.' "$log" | sed 's/^/        /'
		continue
	fi

	if [ "$rc" -eq 124 ]; then
		# never call this a slow test until the parse question is settled
		if "$GODOT" --headless --path . --check-only --script "res://$name.gd" 2>&1 \
			| grep -qi 'parse error'; then
			fail=$((fail+1)); failed_names="$failed_names $name"
			printf 'FAIL  %-32s PARSE ERROR (it never ran; the timeout is the symptom)\n' "$name"
			"$GODOT" --headless --path . --check-only --script "res://$name.gd" 2>&1 \
				| grep -i 'parse error' | head -3 | sed 's/^/        /'
		else
			fail=$((fail+1)); failed_names="$failed_names $name"
			printf 'FAIL  %-32s HANG (compiles, never reached quit())\n' "$name"
		fi
		continue
	fi

	if ! grep -q 'RESULT:' "$log"; then
		# died before it could report -- retry once before believing it
		printf 'retry %-32s (exit %s, %s bytes, no RESULT line)\n' "$name" "$rc" "$(wc -c < "$log")"
		run_one "$name" "$log"; rc=$?
		if [ "$rc" -eq 0 ]; then
			pass=$((pass+1)); printf 'ok    %-32s (passed on retry — transient)\n' "$name"; continue
		fi
		if ! grep -q 'RESULT:' "$log"; then
			crash=$((crash+1)); crashed_names="$crashed_names $name"
			printf 'CRASH %-32s exit %s, %s bytes, no RESULT — the process died, the test did not fail\n' \
				"$name" "$rc" "$(wc -c < "$log")"
			continue
		fi
	fi

	fail=$((fail+1)); failed_names="$failed_names $name"
	printf 'FAIL  %s\n' "$name"
	grep '^FAIL' "$log" | head -8 | sed 's/^/        /'
done < all_test_files.txt

ran=$((pass+fail+crash))
echo "-------------------------------------------------------------"
echo "PASS $pass   FAIL $fail   CRASH $crash   (of $registered registered)"
[ -n "$failed_names" ]  && echo "failed: $failed_names"
[ -n "$crashed_names" ] && echo "crashed:$crashed_names"
if [ -z "$FILTER" ] && [ "$ran" -ne "$registered" ]; then
	echo "*** RAN $ran OF $registered REGISTERED TESTS — the suite covered less than it claims ***"
	exit 3
fi
echo "logs: $LOGS"
[ "$fail" -eq 0 ] && [ "$crash" -eq 0 ]
