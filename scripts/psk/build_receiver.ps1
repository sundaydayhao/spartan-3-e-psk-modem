[CmdletBinding()]
param([string]$Python = "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe")
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
Push-Location $taskRoot
try {
    if (-not (Test-Path -LiteralPath $Python)) { throw 'Provide -Python with a Python executable containing numpy.' }
    & C:\projects\hpm6750-psk-modem\tools\build_host_tools.ps1 -OutDir "$taskRoot\build\reference-tools"
    & $Python scripts\psk\generate_tables.py
    if ($LASTEXITCODE -ne 0) { throw 'RTL table generation failed.' }
    & $Python scripts\psk\prepare_vectors.py
    if ($LASTEXITCODE -ne 0) { throw 'Vector generation failed.' }
    & $Python scripts\psk\prepare_fec_vectors.py
    if ($LASTEXITCODE -ne 0) { throw 'FEC vector generation failed.' }
    foreach ($taskAction in @('ReceiverSimulate','ReceiverStress','ReceiverFEC','ReceiverBoard','ReceiverBuild')) {
        & "$taskRoot\scripts\ise-vm.ps1" -Action $taskAction
        if ($LASTEXITCODE -ne 0) { throw "$taskAction failed." }
    }
    & $Python scripts\psk\validate.py
    if ($LASTEXITCODE -ne 0) { throw 'Receiver validation failed.' }
} finally { Pop-Location }
