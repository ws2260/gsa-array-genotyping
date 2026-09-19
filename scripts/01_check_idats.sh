#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <IDAT_DIR>"
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

IDAT_DIR="$1"

if [[ ! -d "$IDAT_DIR" ]]; then
    echo "ERROR: IDAT directory not found: $IDAT_DIR" >&2
    exit 1
fi

python - "$IDAT_DIR" <<'PY'
import os
import re
import sys
from collections import Counter

root = sys.argv[1]

pattern = re.compile(r"^(.*)_(Grn|Red)\.idat$", re.IGNORECASE)

pairs = {}
unrecognized = []
total_idats = 0

for filename in os.listdir(root):
    path = os.path.join(root, filename)

    if not os.path.isfile(path):
        continue
    if not filename.lower().endswith(".idat"):
        continue

    total_idats += 1
    match = pattern.match(filename)

    if not match:
        unrecognized.append(path)
        continue

    key = match.group(1)
    channel = match.group(2).lower()

    if key not in pairs:
        pairs[key] = Counter()

    pairs[key][channel] += 1

complete = 0
missing_green = 0
missing_red = 0
duplicate_green = 0
duplicate_red = 0

for counts in pairs.values():
    green = counts["grn"]
    red = counts["red"]

    if green == 1 and red == 1:
        complete += 1
    else:
        if green == 0:
            missing_green += 1
        if red == 0:
            missing_red += 1
        if green > 1:
            duplicate_green += 1
        if red > 1:
            duplicate_red += 1

print("=== IDAT PREFLIGHT ===")
print(f"IDAT files:             {total_idats}")
print(f"Array-position IDs:     {len(pairs)}")
print(f"Complete Red/Green:     {complete}")
print(f"Missing Green:          {missing_green}")
print(f"Missing Red:            {missing_red}")
print(f"Duplicate Green:        {duplicate_green}")
print(f"Duplicate Red:          {duplicate_red}")
print(f"Unrecognized filenames: {len(unrecognized)}")

problems = (
    missing_green
    + missing_red
    + duplicate_green
    + duplicate_red
    + len(unrecognized)
)

if total_idats == 0:
    print("ERROR: no IDAT files found.", file=sys.stderr)
    sys.exit(1)

if problems:
    print(
        "ERROR: IDAT pairing problems detected. "
        "Individual filenames are not printed by default.",
        file=sys.stderr,
    )
    sys.exit(1)

if total_idats != complete * 2:
    print(
        "ERROR: IDAT count is inconsistent with complete pairs.",
        file=sys.stderr,
    )
    sys.exit(1)

print("Status: PASS")
PY
