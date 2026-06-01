Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

function New-RoundedRectanglePath {
    param(
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Add-Sparkle {
    param(
        [System.Drawing.Graphics]$Graphics,
        [float]$CenterX,
        [float]$CenterY,
        [float]$OuterRadius,
        [System.Drawing.Brush]$Brush
    )

    $innerRadius = $OuterRadius * 0.42
    $points = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'

    for ($index = 0; $index -lt 8; $index++) {
        $angle = (-90 + ($index * 45)) * [Math]::PI / 180
        $radius = if ($index % 2 -eq 0) { $OuterRadius } else { $innerRadius }
        $points.Add([System.Drawing.PointF]::new(
                $CenterX + [Math]::Cos($angle) * $radius,
                $CenterY + [Math]::Sin($angle) * $radius
            ))
    }

    $Graphics.FillPolygon($Brush, $points.ToArray())
}

function New-IconBitmap {
    param([int]$Size)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $backgroundPath = New-RoundedRectanglePath 24 24 ($Size - 48) ($Size - 48) 220
    $gradientBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.RectangleF]::new(0, 0, $Size, $Size),
        [System.Drawing.ColorTranslator]::FromHtml('#FF8A4C'),
        [System.Drawing.ColorTranslator]::FromHtml('#2F67F6'),
        45
    )
    $graphics.FillPath($gradientBrush, $backgroundPath)

    $glowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(76, 255, 255, 255))
    $graphics.FillEllipse($glowBrush, $Size * 0.16, $Size * 0.12, $Size * 0.56, $Size * 0.56)
    $graphics.FillEllipse($glowBrush, $Size * 0.44, $Size * 0.30, $Size * 0.34, $Size * 0.34)

    $pawBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
    $graphics.FillEllipse($pawBrush, $Size * 0.30, $Size * 0.44, $Size * 0.40, $Size * 0.30)
    $graphics.FillEllipse($pawBrush, $Size * 0.24, $Size * 0.34, $Size * 0.15, $Size * 0.15)
    $graphics.FillEllipse($pawBrush, $Size * 0.38, $Size * 0.28, $Size * 0.12, $Size * 0.12)
    $graphics.FillEllipse($pawBrush, $Size * 0.50, $Size * 0.28, $Size * 0.12, $Size * 0.12)
    $graphics.FillEllipse($pawBrush, $Size * 0.62, $Size * 0.34, $Size * 0.15, $Size * 0.15)

    Add-Sparkle -Graphics $graphics -CenterX ($Size * 0.24) -CenterY ($Size * 0.33) -OuterRadius ($Size * 0.045) -Brush $pawBrush
    Add-Sparkle -Graphics $graphics -CenterX ($Size * 0.77) -CenterY ($Size * 0.31) -OuterRadius ($Size * 0.075) -Brush $pawBrush

    $gradientBrush.Dispose()
    $glowBrush.Dispose()
    $pawBrush.Dispose()
    $backgroundPath.Dispose()
    $graphics.Dispose()

    return $bitmap
}

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
$sourceIconPath = Join-Path $root '1 (2).png'

if (-not (Test-Path $sourceIconPath)) {
    throw "Source icon not found: $sourceIconPath"
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
