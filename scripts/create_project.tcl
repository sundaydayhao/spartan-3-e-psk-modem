# Run with xtclsh from any directory. The .xise project opens in ISE GUI.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
if {[file exists led_demo.xise]} {
    project open led_demo.xise
} else {
    project new led_demo.xise
    xfile add rtl/lcd_text.v
    xfile add rtl/led_demo.v
    xfile add constraints/led_demo.ucf
}
project set family Spartan3E
project set device xc3s500e
project set package fg320
project set speed -4
project set "Preferred Language" Verilog
project set "Simulator" "ISim (VHDL/Verilog)"
project set "FPGA Start-Up Clock" "JTAG Clock"
project set "Unused IOB Pins" Float
file mkdir build
project set "Working Directory" build
project set top led_demo
project close
puts "Created led_demo.xise"
