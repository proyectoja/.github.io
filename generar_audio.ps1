# ==============================================================
#  generar_audio.ps1
#  Genera el audio del guión (guion.md) con la herramienta gratuita
#  de Microsoft (Edge TTS / voces neuronales) y voz de mujer natural.
#
#  Requisito: Python 3 instalado (edge-tts se instala automáticamente).
#
#  Ejemplos:
#    .\generar_audio.ps1                                  # audio\guion-completo.mp3 con es-MX-DaliaNeural
#    .\generar_audio.ps1 -Voice es-ES-ElviraNeural
#    .\generar_audio.ps1 -Voice es-MX-DaliaNeural -Rate 10 -OutFile audio\guion-rapido.mp3
#    .\generar_audio.ps1 -MostrarVoces                    # lista las voces disponibles
# ==============================================================

param(
  [string]$Voice = "es-MX-DaliaNeural",
  [string]$GuionFile = "guion.md",
  [string]$OutFile = "audio\guion-completo.mp3",
  [int]$Rate = 0,        # velocidad en %  (ej: -10 lento, +10 rápido)
  [int]$Volume = 0,      # volumen en %   (-50 a +0)
  [int]$Pitch = 0,       # tono en Hz     (ej: -10 grave, +10 agudo)
  [switch]$MostrarVoces
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)

# --- 1. Comprobar / instalar edge-tts (solo la primera vez) ---
python -c "import edge_tts" 2>$null
if (-not $?) {
  Write-Host "Instalando edge-tts..." -ForegroundColor Yellow
  python -m pip install --quiet edge-tts
  if (-not $?) { throw "No se pudo instalar edge-tts." }
}

# --- 2. Listar voces (opcional) ---
if ($MostrarVoces) {
  python -m edge_tts --list-voices | Select-String -Pattern "Female" | ForEach-Object { $_.Line }
  exit 0
}

# --- 3. Leer el guión ---
if (-not (Test-Path -LiteralPath $GuionFile)) { throw "No se encuentra el archivo: $GuionFile" }
$text = Get-Content -LiteralPath $GuionFile -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($text)) { throw "El guión está vacío." }

# --- 4. Preparar salida ---
$outDir = Split-Path -Parent $OutFile
if (-not $outDir) { $outDir = "." }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outAbs = (Join-Path $PSScriptRoot $OutFile)

# archivo temporal UTF-8 sin BOM (edge-tts lee texto)
$tmp = Join-Path $env:TEMP "guion-tts.txt"
[System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))

# --- 5. Llamada a Edge TTS ---
$esArgs = @("--voice", $Voice, "--file", $tmp, "--write-media", $outAbs)
if ($Rate   -ne 0) { $esArgs += "--rate=$Rate%" }
if ($Volume -ne 0) { $esArgs += "--volume=$Volume%" }
if ($Pitch  -ne 0) { $esArgs += "--pitch=$Pitch`Hz" }

Write-Host "Generando audio con voz '$Voice'..." -ForegroundColor Cyan
Write-Host "  Guión: $GuionFile"
Write-Host "  Salida: $outAbs"
python -m edge_tts $esArgs
if (-not $?) { throw "Falló la generación del audio con edge-tts." }

$mp3 = Get-Item $outAbs
Write-Host "OK: $($mp3.Name) ($([math]::Round($mp3.Length/1KB)) KB)" -ForegroundColor Green