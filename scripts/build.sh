#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for tool in xst ngdbuild map par trce bitgen; do
    command -v "$tool" >/dev/null || { echo "Missing ISE tool: $tool. Source ISE_DS/settings64.sh first." >&2; exit 1; }
done
mkdir -p build
cd build
rm -f led_demo.bit
xst -ifn ../scripts/led_demo.xst -ofn led_demo.syr
ngdbuild -p xc3s500e-4-fg320 -uc ../constraints/led_demo.ucf led_demo.ngc led_demo.ngd
map -w -p xc3s500e-4-fg320 -o led_demo_map.ncd led_demo.ngd led_demo.pcf
par -w led_demo_map.ncd led_demo.ncd led_demo.pcf
trce -v 10 -o led_demo.twr led_demo.ncd led_demo.pcf
grep -Eq 'Timing errors: +0 +Score: +0' led_demo.twr || {
    echo 'Timing checks failed. Review build/led_demo.twr.' >&2
    exit 1
}
bitgen -w -g StartupClk:JtagClk -g UnusedPin:Pullnone led_demo.ncd led_demo.bit led_demo.pcf
test -s led_demo.bit
echo "Generated $(pwd)/led_demo.bit. Review led_demo.twr before programming."
