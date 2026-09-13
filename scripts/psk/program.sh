#!/usr/bin/env bash
# Program only the volatile XC3S500E; the PROM and CPLD stay in bypass.
set -euo pipefail
cd "$(dirname "$0")/../.."
test -s build/psk/psk_rx_top.bit
grep -Eq 'Timing errors: +0 +Score: +0' build/psk/psk_rx_top.twr
sha256sum -c build/psk/validated.sha256
impact -batch scripts/inspect_jtag.cmd 2>&1 | tee build/psk/jtag-inspect.log
mapfile -t parts < <(sed -n 's/^[[:space:]]*PartName(\([^)]*\)).*/\1/p' build/jtag-chain.cdf)
if [[ "${parts[*]}" != 'xc3s500e xcf04s xc2c64a' ]] ||
   ! grep -q "'1': IDCODE is '01c22093' (in hex)." build/psk/jtag-inspect.log; then
    echo 'Unexpected JTAG chain; programming stopped.' >&2; exit 1
fi
if [[ "${1:-}" == '--check' ]]; then exit 0; fi
impact -batch scripts/psk/program_jtag.cmd 2>&1 | tee build/psk/program-jtag.log
grep -q "'1': Programmed successfully." build/psk/program-jtag.log
echo 'PASS receiver programmed into FPGA SRAM'
