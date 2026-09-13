[CmdletBinding()]
param([ValidateSet('Open','Build','Simulate','Scan','Program','ReceiverBuild','ReceiverSimulate','ReceiverStress','ReceiverBoard','ReceiverFEC','ReceiverProgram')][string]$Action = 'Open')
$ErrorActionPreference = 'Stop'
$taskVBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
$taskVm = 'ISE-14.7-Spartan3E'
if (-not (Test-Path -LiteralPath $taskVBox)) { throw 'VirtualBox is not installed.' }
$taskInfo = & $taskVBox showvminfo $taskVm --machinereadable
if ($LASTEXITCODE -ne 0) { throw 'The ISE virtual machine is not installed.' }
if ($taskInfo -contains 'VMState="poweroff"' -or $taskInfo -contains 'VMState="saved"') {
    & $taskVBox startvm $taskVm --type headless
    if ($LASTEXITCODE -ne 0) { throw 'Could not start ISE VM.' }
    $taskReady = $false
    for ($taskTry = 0; $taskTry -lt 30; $taskTry++) {
        Start-Sleep -Seconds 2
        & $taskVBox guestcontrol $taskVm run --exe /bin/true --username ise --password xilinx --timeout 2000 --wait-stdout 2>$null
        if ($LASTEXITCODE -eq 0) { $taskReady = $true; break }
    }
    if (-not $taskReady) { throw 'ISE VM is still booting. Try again shortly.' }
} elseif ($taskInfo -notcontains 'VMState="running"') {
    throw 'ISE VM must be running or shut down. Check VirtualBox.'
}

# These are the public default credentials supplied with the official ISE VM.
# The VM network adapter is disconnected; the shared folder is this project.
if ($Action -in @('Scan','Program','ReceiverProgram')) {
    # After the first Windows driver installation/replug, a device can be Held
    # by VirtualBox without yet being attached to the guest. Attach only Xilinx.
    $taskUsb = (& $taskVBox list usbhost) -join "`n"
    foreach ($taskBlock in ($taskUsb -split "`n`n")) {
        if ($taskBlock -match 'VendorId:\s+0x03fd' -and
            $taskBlock -match 'Current State:\s+(Held|Available)' -and
            $taskBlock -match 'UUID:\s+([0-9a-f-]+)') {
            & $taskVBox controlvm $taskVm usbattach $Matches[1]
            if ($LASTEXITCODE -ne 0) { throw 'Could not attach Xilinx USB-JTAG.' }
            Start-Sleep -Seconds 3
        }
    }
}
if ($Action -eq 'Open') {
    & $taskVBox startvm $taskVm --type separate
    & $taskVBox guestcontrol $taskVm start --exe /bin/bash --username ise --password xilinx --putenv DISPLAY=:0 -- -lc 'cd /home/ise/fpga-project && exec ise led_demo.xise'
} else {
    $taskCommands = @{
        Build = 'cd /home/ise/fpga-project && bash scripts/simulate.sh && bash scripts/build.sh'
        Simulate = 'cd /home/ise/fpga-project && bash scripts/simulate.sh'
        Program = 'cd /home/ise/fpga-project && bash scripts/program.sh'
        ReceiverBuild = 'cd /home/ise/fpga-project && bash scripts/psk/build.sh'
        ReceiverSimulate = 'cd /home/ise/fpga-project && bash scripts/psk/simulate.sh'
        ReceiverStress = 'cd /home/ise/fpga-project && bash scripts/psk/simulate.sh --stress'
        ReceiverFEC = 'cd /home/ise/fpga-project && bash scripts/psk/fec_error_tests.sh'
        ReceiverBoard = 'cd /home/ise/fpga-project && bash scripts/psk/test_board.sh'
        ReceiverProgram = 'cd /home/ise/fpga-project && bash scripts/psk/program.sh'
        Scan = 'cd /home/ise/fpga-project && mkdir -p build && impact -batch scripts/scan_jtag.cmd 2>&1 | tee build/jtag-scan.log; exit ${PIPESTATUS[0]}'
    }
    # Cable access should finish promptly; retain the longer budget for ISE
    # synthesis/simulation, but fail a stalled scan/download sooner.
    $taskTimeoutMs = if ($Action -in @('Scan','Program','ReceiverProgram')) { 90000 } elseif ($Action -in @('ReceiverSimulate','ReceiverStress','ReceiverFEC')) { 7200000 } else { 600000 }
    & $taskVBox guestcontrol $taskVm run --exe /bin/bash --username ise --password xilinx --timeout $taskTimeoutMs --wait-stdout --wait-stderr -- -lc $taskCommands[$Action]
}
if ($LASTEXITCODE -ne 0) { throw "ISE action $Action failed with exit code $LASTEXITCODE" }
