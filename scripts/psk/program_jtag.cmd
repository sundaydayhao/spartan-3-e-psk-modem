setMode -bs
setCable -port auto
identify
assignFile -p 1 -file build/psk/psk_rx_top.bit
program -p 1
readStatusRegister -p 1
quit
