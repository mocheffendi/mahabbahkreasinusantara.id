<#
.SYNOPSIS
    Build image landing page lalu deploy ke server via SSH (tanpa registry/GHCR).

.DESCRIPTION
    Menggantikan pipeline CI/CD, dijalankan dari komputer ini:
      test -> docker build -> simpan image (tar) -> kirim ke server ->
      docker load -> docker compose up -d

    Image dibangun lokal, lalu ditransfer dan dimuat di server. Server tidak
    perlu build dan tidak perlu registry.

.PARAMETER Server
    Tujuan SSH, format user@host. Contoh: root@202.10.41.233

.PARAMETER KeyFile
    File private key SSH untuk login ke server.

.PARAMETER Image
    Nama image lokal (tanpa tag). Default: mahabbahkreasinusantara

.PARAMETER DeployPath
    Folder di server tempat docker-compose.yml disimpan.

.PARAMETER SkipTest
    Lewati tahap test.

.PARAMETER KeepTar
    Jangan hapus file tar setelah selesai (untuk inspeksi).

.EXAMPLE
    .\scripts\deploy.ps1

.EXAMPLE
    .\scripts\deploy.ps1 -Server root@203.0.113.10 -KeyFile "$env:USERPROFILE\.ssh\id_mahabbah" -SkipTest
#>
[CmdletBinding()]
param(
    [string] $Server     = "root@202.10.41.233",
    [string] $KeyFile    = "$env:USERPROFILE\.ssh\id_mahabbah",
    [int]    $SshPort    = 22,
    [string] $Image      = "mahabbahkreasinusantara",
    [string] $DeployPath = "/opt/mahabbahkreasinusantara",
    [string] $WebPort    = "80",
    [switch] $SkipTest,
    [switch] $KeepTar
)

$ErrorActionPreference = 'Stop'

function Write-Section($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }
function Write-Ok($text)      { Write-Host "  [ok] $text" -ForegroundColor Green }

# ---- root proyek (skrip ada di scripts/, root = folder induk) ----
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'Dockerfile'))) {
    throw "Dockerfile tidak ditemukan di '$Root'. Pastikan skrip ada di folder scripts/."
}

$ComposeFile = Join-Path $Root 'docker-compose.prod.yml'
$TarName     = 'deploy-image.tar'
$TarPath     = Join-Path $Root $TarName
$RemoteTar   = '/tmp/mkn-image.tar'

Push-Location $Root
try {
    # ---------- 1. Prasyarat ----------
    Write-Section 'Memeriksa prasyarat'
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'docker tidak ditemukan di PATH.' }
    docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker daemon tidak berjalan. Jalankan Docker Desktop dulu.' }
    Write-Ok 'Docker aktif'

    if (-not (Test-Path $KeyFile)) { throw "File key SSH tidak ditemukan: $KeyFile" }
    Write-Ok "Key SSH: $KeyFile"

    if (-not (Test-Path $ComposeFile)) { throw "File compose tidak ditemukan: $ComposeFile" }

    $sshCommon = @('-i', $KeyFile, '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15', '-p', "$SshPort")
    $scpCommon = @('-i', $KeyFile, '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15', '-P', "$SshPort")

    Write-Section "Menguji koneksi SSH ke $Server"
    $probe = (& ssh @sshCommon $Server 'echo __READY__') 2>&1 | Out-String
    if ($probe -notmatch '__READY__') {
        throw "Tidak bisa login SSH ke $Server. Pastikan public key sudah terpasang di server.`nOutput: $probe"
    }
    Write-Ok 'SSH berhasil'

    # ---------- 2. Tag image ----------
    $shortSha = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try { $shortSha = (& git rev-parse --short HEAD 2>$null) } catch { $shortSha = $null }
    }
    if ([string]::IsNullOrWhiteSpace($shortSha)) { $shortSha = Get-Date -Format 'yyyyMMdd-HHmmss' }
    $tagLatest = "${Image}:latest"
    $tagSha    = "${Image}:$shortSha"
    Write-Section "Target image: $tagLatest  (sha: $shortSha)"

    # ---------- 3. Test ----------
    if (-not $SkipTest) {
        Write-Section 'Menjalankan test (scripts/test.sh)'
        docker run --rm -v "${Root}:/w" -w /w alpine:3.20 sh -c "apk add --no-cache bash jq >/dev/null 2>&1 && bash scripts/test.sh"
        if ($LASTEXITCODE -ne 0) { throw 'Test gagal. Perbaiki dulu sebelum deploy.' }
        Write-Ok 'Semua test lulus'
    } else {
        Write-Host '  (test dilewati)' -ForegroundColor Yellow
    }

    # ---------- 4. Build ----------
    Write-Section "Build image $tagLatest"
    docker build -t $tagLatest -t $tagSha .
    if ($LASTEXITCODE -ne 0) { throw 'docker build gagal.' }
    Write-Ok 'Image berhasil dibangun'

    # ---------- 5. Simpan image ----------
    Write-Section 'Menyimpan image ke file tar'
    if (Test-Path $TarPath) { Remove-Item $TarPath -Force }
    docker save -o $TarPath $tagLatest $tagSha
    if ($LASTEXITCODE -ne 0) { throw 'docker save gagal.' }
    Write-Ok ('Ukuran tar: {0:N1} MB' -f ((Get-Item $TarPath).Length / 1MB))

    # ---------- 6. Siapkan folder server ----------
    Write-Section "Menyiapkan folder $DeployPath di server"
    & ssh @sshCommon $Server "mkdir -p '$DeployPath'"
    if ($LASTEXITCODE -ne 0) { throw 'Gagal membuat folder deploy di server.' }
    Write-Ok 'Folder siap'

    # ---------- 7. Kirim image & compose ----------
    Write-Section 'Mengirim image ke server (scp)'
    & scp @scpCommon $TarName "${Server}:$RemoteTar"
    if ($LASTEXITCODE -ne 0) { throw 'scp image gagal.' }
    Write-Ok 'Image terkirim'

    Write-Section 'Mengirim docker-compose.prod.yml'
    & scp @scpCommon 'docker-compose.prod.yml' "${Server}:$DeployPath/docker-compose.yml"
    if ($LASTEXITCODE -ne 0) { throw 'scp compose gagal.' }
    Write-Ok 'Compose terkirim'

    # ---------- 8. Load & jalankan ----------
    Write-Section 'Load image & jalankan container di server'
    $remoteCmd = "set -e; cd '$DeployPath'; docker load -i $RemoteTar; rm -f $RemoteTar; if docker compose version >/dev/null 2>&1; then DC='docker compose'; else DC='docker-compose'; fi; IMAGE_REF='$tagLatest' WEB_PORT='$WebPort' `$DC up -d --force-recreate; docker image prune -f; echo '----- status -----'; `$DC ps"
    & ssh @sshCommon $Server $remoteCmd
    if ($LASTEXITCODE -ne 0) { throw 'Deploy di server gagal.' }

    Write-Section 'Selesai'
    Write-Ok "Landing page aktif di http://<IP-server>:$WebPort"
}
finally {
    Pop-Location
    if (-not $KeepTar -and (Test-Path $TarPath)) {
        Remove-Item $TarPath -Force -ErrorAction SilentlyContinue
    }
}
