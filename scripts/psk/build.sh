#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/psk
cd build/psk
rm -f psk_rx_top.bit
xst -ifn ../../scripts/psk/receiver.xst -ofn psk_rx_top.syr > synthesis-console.log 2>&1 || { tail -100 synthesis-console.log; exit 1; }
ngdbuild -p xc3s500e-4-fg320 -uc ../../constraints/psk_rx_top.ucf psk_rx_top.ngc psk_rx_top.ngd
map -w -p xc3s500e-4-fg320 -o psk_rx_top_map.ncd psk_rx_top.ngd psk_rx_top.pcf
par -w psk_rx_top_map.ncd psk_rx_top.ncd psk_rx_top.pcf
trce -v 10 -o psk_rx_top.twr psk_rx_top.ncd psk_rx_top.pcf
grep -Eq 'Timing errors: +0 +Score: +0' psk_rx_top.twr
bitgen -w -g StartupClk:JtagClk -g UnusedPin:Pullnone psk_rx_top.ncd psk_rx_top.bit psk_rx_top.pcf
test -s psk_rx_top.bit
echo 'PASS receiver build and 50 MHz timing'
