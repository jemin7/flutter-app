# StaffHub icon generation: SVG -> 1024 PNG (headless Chrome) -> all densities (System.Drawing)
$ErrorActionPreference = 'Stop'
$root = "D:\web\flutter app"
$svg  = Join-Path $root 'mobile\assets\icons\app_icon_source.svg'
$work = 'D:\android-sdk\downloads\iconwork'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
New-Item -ItemType Directory -Force -Path $work | Out-Null

# --- 1. Rasterize SVG at 1024px ---
$png1024 = Join-Path $work 'icon1024.png'
$svgUrl = 'file:///' + (($svg -replace '\\','/') -replace ' ', '%20')
& $chrome --headless --disable-gpu --default-background-color=00000000 --window-size=1024,1024 --screenshot="$png1024" "$svgUrl"
if (!(Test-Path $png1024)) { throw "Chrome rasterization failed for $svgUrl" }
Write-Host "master 1024px rendered"

Add-Type -AssemblyName System.Drawing

function Resize([string]$src, [string]$dst, [int]$size, [bool]$cropSquare = $true) {
  $img = [System.Drawing.Image]::FromFile($src)
  try {
    $s = [Math]::Min($img.Width, $img.Height)
    $crop = if ($cropSquare -and ($img.Width -ne $img.Height)) {
      $x = ($img.Width - $s) / 2; $y = ($img - $s) / 2; $true
    } else { $false }
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.SmoothingMode = 'HighQuality'
    $g.PixelOffsetMode = 'HighQuality'
    $srcRect = if ($crop) { New-Object System.Drawing.Rectangle([int]$x, [int]$y, $s, $s) } else { New-Object System.Drawing.Rectangle(0, 0, $img.Width, $img.Height) }
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)), $srcRect, 'Pixel')
    $g.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  } finally { $img.Dispose() }
}

# --- 2. Android mipmaps (48/72/96/144/192) ---
$mi = Join-Path $root 'mobile\android\app\src\main\res'
@{ 'mipmap-mdpi'=48; 'mipmap-hdpi'=72; 'mipmap-xhdpi'=96; 'mipmap-xxhdpi'=144; 'mipmap-xxxhdpi'=192 }.GetEnumerator() | ForEach-Object {
  Resize $png1024 (Join-Path $mi "$($_.Key)\ic_launcher.png") $_.Value
}
Write-Host "android mipmaps done"

# --- 3. iOS AppIcon.appiconset (every entry in Contents.json) ---
$ai = Join-Path $root 'mobile\ios\Runner\Assets.xcassets\AppIcon.appiconset'
(Get-Content (Join-Path $ai 'Contents.json') | ConvertFrom-Json).images | ForEach-Object {
  # filenames look like Icon-App-20x20@2x.png -> pixel size = 20 * 2 = 40
  if ($_.filename -match '(\d+)x\d+@(\d+)x') {
    $size = [int]$Matches[1] * [int]$Matches[2]
    Resize $png1024 (Join-Path $ai $_.filename) $size
  } else {
    Write-Warning "unrecognized icon filename: $($_.filename)"
  }
}
Write-Host "ios appiconset done"

# --- 4. Web icons ---
$wi = Join-Path $root 'mobile\web\icons'
@{ 'Icon-192.png'=192; 'Icon-512.png'=512; 'Icon-maskable-192.png'=192; 'Icon-maskable-512.png'=512 }.GetEnumerator() | ForEach-Object {
  Resize $png1024 (Join-Path $wi $_.Key) $_.Value
}
Write-Host "web icons done"
Write-Host "ALL ICONS GENERATED"
