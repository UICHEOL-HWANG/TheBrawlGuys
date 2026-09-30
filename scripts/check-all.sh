#!/usr/bin/env bash
# Automated part of the per-phase completion check (docs/PHASES.md).
set -euo pipefail
cd "$(dirname "$0")"
./test.sh
./check-sim-purity.sh
./check-colors.sh
./check-docs.sh
./check-secrets.sh
echo "ALL CHECKS PASSED"
