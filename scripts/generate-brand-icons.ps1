Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path,
        [int]$Size
    )

    $resized = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($resized)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.DrawImage($Bitmap, 0, 0, $Size, $Size)
    $graphics.Dispose()

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $resized.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $resized.Dispose()
}

function Save-Ico {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path,
        [int]$Size
    )

    $temporaryPng = [System.IO.Path]::GetTempFileName()
    try {
        Save-Png -Bitmap $Bitmap -Path $temporaryPng -Size $Size
        $pngBytes = [System.IO.File]::ReadAllBytes($temporaryPng)

        $directory = Split-Path -Parent $Path
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory | Out-Null
        }

        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
        $writer = [System.IO.BinaryWriter]::new($stream)
        try {
            $dimensionByte = if ($Size -ge 256) { [byte]0 } else { [byte]$Size }
            $writer.Write([UInt16]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]1)
            $writer.Write($dimensionByte)
            $writer.Write($dimensionByte)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]32)
            $writer.Write([UInt32]$pngBytes.Length)
            $writer.Write([UInt32]22)
            $writer.Write($pngBytes)
        }
        finally {
            $writer.Dispose()
            $stream.Dispose()
        }
    }
    finally {
        Remove-Item $temporaryPng -ErrorAction SilentlyContinue
    }
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$sourceIconCandidates = @(
    (Join-Path $root 'apps/petmagic-mobile/assets/branding/petmagic-app-icon-1024.png'),
    (Join-Path $root 'apps/petmagic-mobile/assets/icons/app_icon.png'),
    (Join-Path $root 'apps/admin-web/src/app/icon.png')
)
$sourceIconPath = $sourceIconCandidates |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($sourceIconPath)) {
    throw "Source icon not found. Checked: $($sourceIconCandidates -join ', ')"
}

$sourceImage = [System.Drawing.Image]::FromFile($sourceIconPath)
$master = [System.Drawing.Bitmap]::new($sourceImage)

try {
    $brandingPng = Join-Path $root 'apps/petmagic-mobile/assets/branding/petmagic-app-icon-1024.png'
    $webIcon = Join-Path $root 'apps/admin-web/src/app/icon.png'
    $webFavicon = Join-Path $root 'apps/admin-web/src/app/favicon.ico'

    Save-Png -Bitmap $master -Path $brandingPng -Size 1024
    Save-Png -Bitmap $master -Path $webIcon -Size 1024
    Save-Ico -Bitmap $master -Path $webFavicon -Size 64

    $androidIcons = @{
        'mipmap-mdpi/ic_launcher.png'    = 48
        'mipmap-hdpi/ic_launcher.png'    = 72
        'mipmap-xhdpi/ic_launcher.png'   = 96
        'mipmap-xxhdpi/ic_launcher.png'  = 144
        'mipmap-xxxhdpi/ic_launcher.png' = 192
    }

    foreach ($entry in $androidIcons.GetEnumerator()) {
        $path = Join-Path $root (Join-Path 'apps/petmagic-mobile/android/app/src/main/res' $entry.Key)
        Save-Png -Bitmap $master -Path $path -Size $entry.Value
    }

    $iosIcons = @{
        'Icon-App-20x20@1x.png'     = 20
        'Icon-App-20x20@2x.png'     = 40
        'Icon-App-20x20@3x.png'     = 60
        'Icon-App-29x29@1x.png'     = 29
        'Icon-App-29x29@2x.png'     = 58
        'Icon-App-29x29@3x.png'     = 87
        'Icon-App-40x40@1x.png'     = 40
        'Icon-App-40x40@2x.png'     = 80
        'Icon-App-40x40@3x.png'     = 120
        'Icon-App-50x50@1x.png'     = 50
        'Icon-App-50x50@2x.png'     = 100
        'Icon-App-57x57@1x.png'     = 57
        'Icon-App-57x57@2x.png'     = 114
        'Icon-App-60x60@2x.png'     = 120
        'Icon-App-60x60@3x.png'     = 180
        'Icon-App-72x72@1x.png'     = 72
        'Icon-App-72x72@2x.png'     = 144
        'Icon-App-76x76@1x.png'     = 76
        'Icon-App-76x76@2x.png'     = 152
        'Icon-App-83.5x83.5@2x.png' = 167
        'Icon-App-1024x1024@1x.png' = 1024
    }

    foreach ($entry in $iosIcons.GetEnumerator()) {
        $path = Join-Path $root (Join-Path 'apps/petmagic-mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset' $entry.Key)
        Save-Png -Bitmap $master -Path $path -Size $entry.Value
    }
}
finally {
    $master.Dispose()
    $sourceImage.Dispose()
}
