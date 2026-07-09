# Instala o certificado do app Receitas Marketing automaticamente

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Solicitando permissao de administrador..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "=== Instalador de Certificado - Receitas Marketing ===" -ForegroundColor Cyan

# ID do arquivo no Google Drive
$FileId = "1WkYNZhNzkTX7GcwdXPXsM2DwUWigFrxL"
$destino = "$env:TEMP\receitas_mkt.cer"

Write-Host "Baixando certificado..." -ForegroundColor Yellow

# Burlando o aviso de vírus do Google Drive
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$InitUrl = "https://drive.google.com/uc?export=download&id=$FileId"
$ProgressPreference = 'SilentlyContinue'
$Null = Invoke-WebRequest -Uri $InitUrl -WebSession $Session

$DownloadUrl = "https://drive.usercontent.google.com/download?id=$FileId&export=download&confirm=t"
Invoke-WebRequest -Uri $DownloadUrl -WebSession $Session -OutFile $destino

Write-Host "Instalando certificado em Pessoas Confiaveis..." -ForegroundColor Yellow
Import-Certificate -FilePath $destino -CertStoreLocation Cert:\LocalMachine\TrustedPeople

Write-Host "Certificado instalado com sucesso!" -ForegroundColor Green
Write-Host "Agora voce ja pode instalar o arquivo .msix normalmente." -ForegroundColor Green

Remove-Item $destino -Force
Read-Host "Pressione Enter para fechar"