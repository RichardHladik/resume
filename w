#!/bin/sh
inotifywait -m -e close_write,moved_to --format %e/%f . |
while IFS=/ read -r events file; do
	if echo "$file" | grep -q -E '\.tex$'; then
		make
	fi
done
