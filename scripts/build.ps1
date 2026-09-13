[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$taskProject = Split-Path $PSScriptRoot -Parent
foreach ($taskTool in @('xst','ngdbuild','map','par','trce','bitgen')) {
    if (-not (Get-Command $taskTool -ErrorAction SilentlyContinue)) {
        throw "Missing ISE tool: $taskTool. Run from an ISE command environment."
    }
}
$taskBuild = Join-Path $taskProject 'build'
New-Item -ItemType Directory -Force -Path $taskBuild | Out-Null
function Invoke-IseTool {
    param([string]$Tool, [string[]]$ToolArguments)
    & $Tool @ToolArguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool exited with code $LASTEXITCODE" }
}
Push-Location $taskBuild
try {
    if (Test-Path -LiteralPath 'led_demo.bit') { Remove-Item -LiteralPath 'led_demo.bit' }
    Invoke-IseTool xst @('-ifn','../scripts/led_demo.xst','-ofn','led_demo.syr')
    Invoke-IseTool ngdbuild @('-p','xc3s500e-4-fg320','-uc','../constraints/led_demo.ucf','led_demo.ngc','led_demo.ngd')
    Invoke-IseTool map @('-w','-p','xc3s500e-4-fg320','-o','led_demo_map.ncd','led_demo.ngd','led_demo.pcf')
    Invoke-IseTool par @('-w','led_demo_map.ncd','led_demo.ncd','led_demo.pcf')
    Invoke-IseTool trce @('-v','10','-o','led_demo.twr','led_demo.ncd','led_demo.pcf')
    if (-not (Select-String -LiteralPath 'led_demo.twr' -Pattern 'Timing errors: +0 +Score: +0' -Quiet)) {
        throw 'Timing checks failed. Review build/led_demo.twr.'
    }
    Invoke-IseTool bitgen @('-w','-g','StartupClk:JtagClk','-g','UnusedPin:Pullnone','led_demo.ncd','led_demo.bit','led_demo.pcf')
    if (-not (Test-Path -LiteralPath 'led_demo.bit') -or (Get-Item -LiteralPath 'led_demo.bit').Length -eq 0) {
        throw 'ISE did not produce a nonempty bitstream.'
    }
    Write-Output "Generated $taskBuild\led_demo.bit. Review led_demo.twr before programming."
} finally {
    Pop-Location
}
