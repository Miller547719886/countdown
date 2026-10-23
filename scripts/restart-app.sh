#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$project_dir/dist/截点.app"
process_name=Jiedian
wait_seconds=${JIEDIAN_RESTART_TIMEOUT:-10}
open_attempts=${JIEDIAN_OPEN_ATTEMPTS:-5}

printf '%s\n' 'Building the latest version...'
sh "$project_dir/scripts/build-app.sh"

old_pids=$(pgrep -x "$process_name" || true)
if [ -n "$old_pids" ]; then
    printf '%s\n' 'Stopping the current instance...'
    kill $old_pids
fi

elapsed=0
while pgrep -x "$process_name" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$wait_seconds" ]; then
        printf '%s\n' "Timed out waiting for $process_name to exit." >&2
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

printf '%s\n' 'Starting the rebuilt app...'
attempt=1
started=0
while [ "$attempt" -le "$open_attempts" ]; do
    if open "$app_dir" >/dev/null 2>&1; then
        started=1
        break
    fi
    sleep 1
    attempt=$((attempt + 1))
done

if [ "$started" -ne 1 ]; then
    printf '%s\n' "Failed to open $app_dir." >&2
    exit 1
fi

elapsed=0
while ! pgrep -x "$process_name" >/dev/null 2>&1; do
    if [ "$elapsed" -ge "$wait_seconds" ]; then
        printf '%s\n' "The app did not start within ${wait_seconds}s." >&2
        exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

printf '%s\n' "Restarted $app_dir"
