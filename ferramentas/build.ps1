param([string]$Go='go',[string]$Godot='godot')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$output=Join-Path $projectRoot 'build'
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $Go -C (Join-Path $projectRoot 'server') test ./...
if($LASTEXITCODE -ne 0){throw 'Testes Go falharam.'}
& $Go -C (Join-Path $projectRoot 'server') build -trimpath -o (Join-Path $output 'aurora-server.exe') .
if($LASTEXITCODE -ne 0){throw 'Build Go falhou.'}
& $Godot --headless --path (Join-Path $projectRoot 'client') --editor --import --quit
if($LASTEXITCODE -ne 0){throw 'Importação Godot falhou.'}
& $Godot --headless --quiet --path (Join-Path $projectRoot 'client') --export-pack 'Windows Desktop' (Join-Path $output 'Aurora.pck')
if($LASTEXITCODE -ne 0){throw 'Empacotamento Godot falhou.'}
$runtimePath=(Get-Command $Godot).Source
$guiPath=$runtimePath -replace '_console.exe$','.exe'
if(!(Test-Path -LiteralPath $guiPath)){$guiPath=$runtimePath}
Copy-Item -LiteralPath $guiPath -Destination (Join-Path $output 'Aurora.exe') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/THIRD_PARTY_GODOT.txt') -Destination (Join-Path $output 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/THIRD_PARTY_GO.txt') -Destination (Join-Path $output 'GO-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'client/assets/CREDITS.md') -Destination (Join-Path $output 'CREDITS.md') -Force
Write-Output 'Build concluído. Abra Jogar.cmd. O runtime Godot oficial acompanha o pacote PCK.'
