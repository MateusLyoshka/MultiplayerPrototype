# sync_packets.ps1
# Copia shared/packets/ -> scripts/packets/ de cada projeto Godot do repo.
#
# Quando rodar:
#   - Antes de testar qualquer projeto se voce editou algo em shared/packets/.
#   - Sempre que mudar a assinatura/encode/decode de um pacote (precisa rebatizar
#     nos 3 lados juntos para nao quebrar contrato).
#
# Como funciona:
#   - Source: shared/packets/ na raiz do repo (este script).
#   - Targets: server/, professor/, client/prototype/ (cada um com sua subpasta
#     scripts/packets/).
#   - Cria scripts/packets/ se nao existir; ignora target inexistente (warning
#     verde) - assim funciona durante a migracao quando alguns projetos ainda
#     nao foram criados.
#   - Copia recursivo + sobrescreve (Force). NAO espelha (renomear um pacote em
#     shared/ nao remove a copia velha do target - apague manualmente se quiser).

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$source = Join-Path $repoRoot "shared\packets"

if (-not (Test-Path $source)) {
    Write-Host "ERRO: $source nao existe." -ForegroundColor Red
    exit 1
}

$targets = @(
    @{ Name = "server";    Path = "server\scripts\packets" },
    @{ Name = "professor"; Path = "professor\scripts\packets" },
    @{ Name = "client";    Path = "client\prototype\scripts\packets" }
)

foreach ($target in $targets) {
    $fullTarget = Join-Path $repoRoot $target.Path
    $projectRoot = Split-Path -Path (Split-Path -Path $fullTarget -Parent) -Parent

    if (-not (Test-Path $projectRoot)) {
        Write-Host "  [skip] $($target.Name): projeto ainda nao existe ($projectRoot)" -ForegroundColor Yellow
        continue
    }

    if (-not (Test-Path $fullTarget)) {
        New-Item -ItemType Directory -Force -Path $fullTarget | Out-Null
    }

    Copy-Item -Path "$source\*" -Destination $fullTarget -Recurse -Force
    Write-Host "  [ok]   $($target.Name) -> $($target.Path)" -ForegroundColor Green
}

Write-Host ""
Write-Host "sync_packets concluido." -ForegroundColor Cyan
