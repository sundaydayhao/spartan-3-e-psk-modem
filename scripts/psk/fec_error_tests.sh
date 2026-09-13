#!/usr/bin/env bash
set -euo pipefail
cd /home/ise/fpga-project
for mode in 22 24 26; do
    bash scripts/psk/fec_test.sh "$mode" 3000 "fec-error-$mode"
done
bash scripts/psk/fec_test.sh 22 3000 fec-midstream-22 1500
