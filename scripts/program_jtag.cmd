setMode -bs
setCable -port auto
identify
assignFile -p 1 -file build/led_demo.bit
program -p 1
readStatusRegister -p 1
quit
