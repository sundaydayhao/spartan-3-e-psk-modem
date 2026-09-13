#!/usr/bin/env bash
# Only volatile configuration of the FPGA on the verified Starter Kit chain.
set -euo pipefail
cd "$(dirname "$0")/.."
test -s build/led_demo.bit || { echo 'Build the demo first.' >&2; exit 1; }
grep -Eq 'Timing errors: +0 +Score: +0' build/led_demo.twr || {
    echo 'Timing check did not pass. Rebuild the demo.' >&2; exit 1;
}
for source in rtl/led_demo.v rtl/lcd_text.v constraints/led_demo.ucf scripts/led_demo.prj scripts/led_demo.xst; do
    if [[ "$source" -nt build/led_demo.bit ]]; then
        echo "Source changed after bitstream generation: $source. Rebuild first." >&2
        exit 1
    fi
done
impact -batch scripts/inspect_jtag.cmd 2>&1 | tee build/jtag-inspect.log
mapfile -t parts < <(sed -n 's/^[[:space:]]*PartName(\([^)]*\)).*/\1/p' build/jtag-chain.cdf)
if [[ "${parts[*]}" != 'xc3s500e xcf04s xc2c64a' ]] ||
   ! grep -q "'1': IDCODE is '01c22093' (in hex)." build/jtag-inspect.log; then
    echo 'Unexpected board/JTAG order. Inspect the chain before programming.' >&2
    exit 1
fi
if [[ "${1:-}" == '--check' ]]; then
    echo 'Preflight passed: current bitstream, timing and XC3S500E at position 1.'
    exit 0
fi
impact -batch scripts/program_jtag.cmd 2>&1 | tee build/program-jtag.log
grep -q "'1': Programmed successfully." build/program-jtag.log
echo 'FPGA programmed. Expected: two LCD text lines, LED0/LED1 on, LED7 blinking.'
