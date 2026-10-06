<#
.SYNOPSIS
  Converts Teams HTML exports to PDF using Microsoft Edge (headless),
  shrinking oversized images first so the PDFs stay small.

.DESCRIPTION
  Uses only what ships with Windows: PowerShell, the built-in .NET
  System.Drawing library, and Microsoft Edge. No third-party tools.

  For each .html file in the folder:
    1. Finds every <img> (linked files and embedded base64 images).
    2. Any image wider than -MaxWidth pixels, or larger than 500 KB,
       is scaled down and re-saved as a compressed JPEG.
    3. Adds CSS so images never spill off the page.
    4. Prints to PDF with Edge, which renders modern emoji correctly.

  Original HTML files are never modified; a temporary copy is used.

.PARAMETER Folder
  Folder containing the .html files. Defaults to the current folder.

.PARAMETER MaxWidth
  Widest an image may be, in pixels. 1200 is roughly print quality on A4.

.PARAMETER Quality
  JPEG quality, 1-100. Lower means smaller files.

.EXAMPLE
  .\Convert-TeamsHtmlToPdf.ps1
.EXAMPLE
  .\Convert-TeamsHtmlToPdf.ps1 -Folder "C:\Exports" -MaxWidth 900 -Quality 60
#>
param(
  [string]$Folder   = (Get-Location).Path,
  [int]   $MaxWidth = 1200,
  [int]   $Quality  = 75
)

Add-Type -AssemblyName System.Drawing

$script:maxWidth = $MaxWidth
$script:sizeLimit = 500KB

# Locate Edge
$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge (msedge.exe) was not found." }

$css = "<style>img{max-width:100% !important;height:auto !important}</style>"

$script:codec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$script:params = New-Object System.Drawing.Imaging.EncoderParameters 1
$script:params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)

$evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $src = $m.Groups[3].Value
  try {
    if ($src -match '^data:image/[^;]+;base64,(.+)$') {
      $bytes = [Convert]::FromBase64String($Matches[1])
    }
    else {
      $path = [Uri]::UnescapeDataString(($src -replace '^file:///', ''))
      if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $script:dir $path }
      if (-not (Test-Path -LiteralPath $path)) { return $m.Value }
      $bytes = [IO.File]::ReadAllBytes($path)
    }

    $img = [System.Drawing.Image]::FromStream((New-Object IO.MemoryStream (,$bytes)))
    if ($img.Width -le $script:maxWidth -and $bytes.Length -lt $script:sizeLimit) {
      $img.Dispose(); return $m.Value
    }

    $w = [Math]::Min($img.Width, $script:maxWidth)
    $h = [int]($img.Height * $w / $img.Width)
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($img, 0, 0, $w, $h)
    $g.Dispose(); $img.Dispose()

    $out = New-Object IO.MemoryStream
    $bmp.Save($out, $script:codec, $script:params); $bmp.Dispose()

    $q = $m.Groups[2].Value
    return $m.Groups[1].Value + $q + "data:image/jpeg;base64," + [Convert]::ToBase64String($out.ToArray()) + $q
  }
  catch { return $m.Value }
}

$files = Get-ChildItem -LiteralPath $Folder -Filter *.html | Where-Object Name -notlike "_tmp_*"
if (-not $files) { Write-Host "No .html files found in $Folder"; return }

foreach ($file in $files) {
  $script:dir = $file.DirectoryName
  $tmp = Join-Path $script:dir "_tmp_$($file.Name)"
  $pdf = Join-Path $script:dir "$($file.BaseName).pdf"
  Write-Host "Converting $($file.Name)..."

  $html = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $html = [regex]::Replace($html, '(<img\b[^>]*?\bsrc\s*=\s*)(["''])(.*?)\2', $evaluator)
  $html -replace '</head>', "$css</head>" | Set-Content -LiteralPath $tmp -Encoding UTF8

  Start-Process $edge -Wait -ArgumentList "--headless","--disable-gpu","--no-pdf-header-footer","--print-to-pdf=`"$pdf`"","`"$tmp`""
  Remove-Item -LiteralPath $tmp
}

Write-Host "Done."
