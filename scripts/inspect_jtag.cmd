setMode -bs
setCable -port auto
identify
saveCdf -file build/jtag-chain.cdf
readIdcode -p 1
quit
