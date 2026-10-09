# prepare-images.ps1
# Menyalin + mengoptimasi gambar portofolio dari folder sumber.
# Gambar yang terdeteksi RUSAK (mis. hasil unduhan terpotong / bagian besar hitam)
# otomatis dilewati.
# Menghasilkan:
#   public/images/thumbs/<grup>/<name>.jpg  (thumbnail grid)
#   public/images/full/<grup>/<name>.jpg    (lihat besar / lightbox)
#   public/images/manifest.json

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# ---- Helper C# untuk cek cepat area hitam pada gambar ----
$csCode = @"
using System;
using System.Drawing;
public class ImgCheck {
  // Mengembalikan "total%|atas%|bawah%"
  public static string Check(string path) {
    using (var bmp = new Bitmap(path)) {
      int w = bmp.Width, h = bmp.Height;
      int step = Math.Max(1, Math.Min(w, h) / 90);
      long total = 0, black = 0, botTotal = 0, botBlack = 0, topBlack = 0, topTotal = 0;
      int bottomStart = (int)(h * 0.60);
      int topEnd = (int)(h * 0.40);
      for (int y = 0; y < h; y += step) {
        for (int x = 0; x < w; x += step) {
          Color c = bmp.GetPixel(x, y);
          bool isBlack = c.R < 22 && c.G < 22 && c.B < 22;
          total++; if (isBlack) black++;
          if (y >= bottomStart) { botTotal++; if (isBlack) botBlack++; }
          if (y < topEnd) { topTotal++; if (isBlack) topBlack++; }
        }
      }
      return string.Format("{0:F1}|{1:F1}|{2:F1}",
        black * 100.0 / total,
        topBlack * 100.0 / Math.Max(1, topTotal),
        botBlack * 100.0 / Math.Max(1, botTotal));
    }
  }
}
"@
Add-Type -TypeDefinition $csCode -ReferencedAssemblies System.Drawing

function Test-Damaged([string]$path) {
  # rusak bila: hampir seluruh gambar hitam, ATAU sebagian besar bagian bawah hitam
  # sementara bagian atas masih normal (indikasi gambar terpotong).
  $r = [ImgCheck]::Check($path) -split '\|'
  $total = [double]$r[0]; $top = [double]$r[1]; $bottom = [double]$r[2]
  $damaged = ($total -ge 90) -or (($bottom -ge 90) -and ($top -le 25))
  return [pscustomobject]@{ Damaged = $damaged; Total = $total; Top = $top; Bottom = $bottom }
}

$Src  = "C:\Users\Mochammad Effendi\Downloads\drive-download-20261009T032831Z-1-001"
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root "public\images"

# Definisi grup:  NamaGrup = PathRelatifDariSumber
$Groups = [ordered]@{
  "desain-rumah"       = "1. Desain\1. Rumah"
  "desain-kitchen-set" = "1. Desain\2. Kitchen Set"
  "desain-backdrop-tv" = "1. Desain\3. Backdrop TV"
  "kitchen-set"        = "2. Kitchen Set"
  "furnitur-meja"      = "3. Furnitur Lainnya\1. Meja"
  "furnitur-mihrab"    = "3. Furnitur Lainnya\2. Mihrab"
  "baja-ringan"        = "4. Baja Ringan"
  "kanopi"             = "5. Kanopi"
  "plafon"             = "6. Plafon"
  "aluminium-kusen"    = "7. Pekerjaan Aluminium\1. Kusen"
}

$ImageExt = @(".png", ".jpg", ".jpeg", ".webp", ".avif")
$JpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq "image/jpeg" }

function Get-NaturalKey([string]$name) {
  return [regex]::Replace($name.ToLower(), '\d+', { param($m) $m.Value.PadLeft(8, '0') })
}

function Save-ResizedJpeg([string]$source, [string]$target, [int]$maxDim, [int]$quality) {
  $img = [System.Drawing.Image]::FromFile($source)
  try {
    $ratio = [math]::Min($maxDim / $img.Width, $maxDim / $img.Height)
    if ($ratio -gt 1) { $ratio = 1 }
    $w = [int][math]::Max(1, [math]::Round($img.Width * $ratio))
    $h = [int][math]::Max(1, [math]::Round($img.Height * $ratio))

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    try {
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::White)
        $g.DrawImage($img, 0, 0, $w, $h)
      } finally { $g.Dispose() }

      $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
      $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [long]$quality)
      $bmp.Save($target, $JpegCodec, $ep)
      $ep.Dispose()
    } finally { $bmp.Dispose() }
  } finally { $img.Dispose() }
}

# Bersihkan hasil lama
if (Test-Path $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $Dest "thumbs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dest "full")   | Out-Null

$manifest = [ordered]@{}
$total = 0
$skipped = @()

foreach ($key in $Groups.Keys) {
  $sourceDir = Join-Path $Src $Groups[$key]
  if (-not (Test-Path $sourceDir)) { Write-Warning "Folder tidak ditemukan: $sourceDir"; continue }

  $thumbDir = Join-Path $Dest "thumbs\$key"
  $fullDir  = Join-Path $Dest "full\$key"
  New-Item -ItemType Directory -Force -Path $thumbDir | Out-Null
  New-Item -ItemType Directory -Force -Path $fullDir  | Out-Null

  $files = Get-ChildItem -Path $sourceDir -Recurse -File |
    Where-Object { $ImageExt -contains $_.Extension.ToLower() }

  $entries = @()
  foreach ($f in $files) {
    # Lewati gambar rusak
    $chk = Test-Damaged $f.FullName
    if ($chk.Damaged) {
      $skipped += $f.FullName
      Write-Warning ("RUSAK, dilewati: {0}  (hitam total {1}%, bawah {2}%)" -f $f.Name, $chk.Total, $chk.Bottom)
      continue
    }

    $rel = $f.FullName.Substring($sourceDir.Length).TrimStart('\')
    $parts = $rel -split '\\'
    if ($parts.Count -gt 1) {
      $name = (($parts[0..($parts.Count - 2)] -join '-') + '-' + $parts[-1])
    } else {
      $name = $parts[0]
    }
    $name = ($name -replace '\s+', '-')
    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $file = "$base.jpg"

    Save-ResizedJpeg $f.FullName (Join-Path $thumbDir $file) 640  76
    Save-ResizedJpeg $f.FullName (Join-Path $fullDir  $file) 1600 82

    $entries += [pscustomobject]@{
      name  = $file
      thumb = "images/thumbs/$key/$file"
      full  = "images/full/$key/$file"
    }
    $total++
  }

  $sorted = $entries | Sort-Object @{ Expression = { Get-NaturalKey $_.name } }
  $manifest[$key] = @($sorted)
  Write-Host ("[{0}] {1} gambar" -f $key, $sorted.Count)
}

$json = $manifest | ConvertTo-Json -Depth 5
$manifestPath = Join-Path $Dest "manifest.json"
[System.IO.File]::WriteAllText($manifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))

$size = (Get-ChildItem $Dest -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host ""
Write-Host ("Selesai. {0} gambar diproses, {1} dilewati (rusak), total {2:N1} MB" -f $total, $skipped.Count, ($size / 1MB))
if ($skipped.Count) { $skipped | ForEach-Object { Write-Host ("  - {0}" -f $_) } }
Write-Host "Manifest: $manifestPath"
