<#
.SYNOPSIS
  Converts Teams HTML exports to PDF using Microsoft Edge (headless),
  shrinking oversized images so the PDFs stay small.

.DESCRIPTION
  Uses only what ships with Windows: PowerShell and Microsoft Edge.
  No third-party tools, and no Admin rights needed - it works even when
  PowerShell is locked down (Constrained Language Mode), because the
  image shrinking is done by Edge itself while it renders the page.

  For each .html file in the folder:
    1. Adds a small script and stylesheet to a temporary copy of the page.
    2. Edge loads it; any image wider than -MaxWidth pixels (or any
       embedded image over 500 KB) is scaled down and re-saved as JPEG.
    3. Text and layout are scaled by -Zoom percent.
    4. Edge prints it to PDF, rendering modern emoji correctly.

  Original HTML files are never modified.

.PARAMETER Folder
  Folder containing the .html files. Defaults to the current folder.

.PARAMETER MaxWidth
  Widest an image may be, in pixels. 1200 is roughly print quality on A4.

.PARAMETER Quality
  JPEG quality, 1-100. Lower means smaller files.

.PARAMETER Zoom
  Size of everything on the page, in percent. 100 = as in the browser,
  80 = smaller text so more fits on each page.

.EXAMPLE
  .\Convert-TeamsHtmlToPdf.ps1
.EXAMPLE
  .\Convert-TeamsHtmlToPdf.ps1 -Folder "C:\Exports" -Zoom 75 -MaxWidth 900 -Quality 60
#>
param(
  [string]$Folder   = (Get-Location).Path,
  [int]   $MaxWidth = 1200,
  [int]   $Quality  = 75,
  [int]   $Zoom     = 80
)

# Locate Edge
$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge (msedge.exe) was not found." }

# Separate throwaway Edge profile, so your normal browser (sign-in, sync) is untouched
$profileDir = Join-Path $env:TEMP "PDFPowerConvert-Edge"
$edgeLog    = Join-Path $env:TEMP "PDFPowerConvert-Edge.log"

# Added to each page: zoom, keep images within the page, and shrink big images
$inject = @'
<style>
  html { zoom: __ZOOM__%; }
  img, canvas { max-width: 100% !important; height: auto !important; }
</style>
<script>
(function () {
  var MAXW = __MAXW__, Q = __Q__ / 100, LIMIT = 500 * 1024;
  function shrink(img) {
    var w = img.naturalWidth, h = img.naturalHeight;
    if (!w || !h) return;
    var bigData = img.src.indexOf('data:') === 0 && img.src.length * 0.75 > LIMIT;
    if (w <= MAXW && !bigData) return;
    var nw = Math.min(w, MAXW), nh = Math.round(h * nw / w);
    var c = document.createElement('canvas');
    c.width = nw; c.height = nh;
    var g = c.getContext('2d');
    g.fillStyle = '#fff'; g.fillRect(0, 0, nw, nh);
    g.imageSmoothingQuality = 'high';
    g.drawImage(img, 0, 0, nw, nh);
    try {
      img.removeAttribute('srcset');
      img.src = c.toDataURL('image/jpeg', Q);
    } catch (e) {
      c.className = img.className;
      img.parentNode.replaceChild(c, img);
    }
  }
  window.addEventListener('load', function () {
    var imgs = Array.prototype.slice.call(document.images);
    for (var i = 0; i < imgs.length; i++) { try { shrink(imgs[i]); } catch (e) {} }
  });
})();
</script>
'@
$inject = $inject.Replace('__ZOOM__', "$Zoom").Replace('__MAXW__', "$MaxWidth").Replace('__Q__', "$Quality")

# The additions go in a small header file that is joined onto the front of each
# export with a plain file copy. The export itself is never loaded into
# PowerShell's memory, so even very large (multi-GB) files work.
$header = Join-Path $env:TEMP "PDFPowerConvert-header.html"
Set-Content -LiteralPath $header -Encoding UTF8 -Value ("<!DOCTYPE html>`r`n<meta charset=`"utf-8`">`r`n" + $inject)

$files = Get-ChildItem -LiteralPath $Folder -Filter *.html | Where-Object { $_.Name -notlike "_tmp_*" }
if (-not $files) { Write-Host "No .html files found in $Folder"; return }

foreach ($file in $files) {
  $dir = $file.DirectoryName
  $tmp = Join-Path $dir "_tmp_$($file.Name)"
  $pdf = Join-Path $dir "$($file.BaseName).pdf"
  Write-Host ("Converting {0} ({1:N0} MB)..." -f $file.Name, ($file.Length / 1MB))

  foreach ($old in $pdf, $tmp) { if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old } }
  Start-Process cmd.exe -Wait -WindowStyle Hidden -ArgumentList "/c copy /b /y `"$header`"+`"$($file.FullName)`" `"$tmp`""
  # Make sure the temporary copy is complete (header + every byte of the export)
  $expected = (Get-Item -LiteralPath $header).Length + $file.Length
  if (-not (Test-Path -LiteralPath $tmp) -or (Get-Item -LiteralPath $tmp).Length -ne $expected) {
    Write-Host "  -> FAILED: temporary copy is incomplete (is the disk full?). Skipped - no PDF made." -ForegroundColor Red
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp }
    continue
  }

  Start-Process $edge -Wait -WindowStyle Hidden -RedirectStandardError $edgeLog -ArgumentList @(
    "--headless", "--disable-gpu", "--no-pdf-header-footer", "--log-level=3",
    "--allow-file-access-from-files", "--virtual-time-budget=15000",
    "--user-data-dir=`"$profileDir`"",
    "--print-to-pdf=`"$pdf`"", "`"$tmp`""
  )
  Remove-Item -LiteralPath $tmp

  if (Test-Path -LiteralPath $pdf) {
    Write-Host ("  -> {0} ({1:N0} KB)" -f (Split-Path $pdf -Leaf), ((Get-Item -LiteralPath $pdf).Length / 1KB))
  } else {
    Write-Host "  -> FAILED (see $edgeLog)" -ForegroundColor Red
  }
}

Write-Host "Done."
