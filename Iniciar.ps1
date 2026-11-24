param([string]$Perfil = 'principal', [string]$Servidor = 'http://127.0.0.1:8787')
$ErrorActionPreference='Stop'
$projectRoot=$PSScriptRoot
$runtime=Join-Path $projectRoot 'build/Aurora.exe'
$backend=Join-Path $projectRoot 'build/aurora-server.exe'
if(!(Test-Path -LiteralPath $runtime) -or !(Test-Path -LiteralPath $backend)){
    throw 'Compile primeiro com ferramentas/build.ps1, ou abra client/project.godot no Godot 4 e execute o servidor Go.'
}
if($Servidor -eq 'http://127.0.0.1:8787'){
    $running=$false
    try {$health=Invoke-RestMethod "$Servidor/health" -TimeoutSec 2;$running=$health.game -eq 'Pokémon Aurora Online'} catch {}
    if(!$running){
        $dataDirectory=Join-Path $env:LOCALAPPDATA 'PokemonAurora/server'
        New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
        $dataFile=Join-Path $dataDirectory 'world.json'
        Start-Process -FilePath $backend -ArgumentList @('-listen','127.0.0.1:8787','-data',('"'+$dataFile+'"')) -WindowStyle Hidden -WorkingDirectory $projectRoot | Out-Null
    }
}
Start-Process -FilePath $runtime -ArgumentList @('--main-pack','Aurora.pck','--',('--profile='+$Perfil),('--server='+$Servidor)) -WorkingDirectory (Join-Path $projectRoot 'build')
