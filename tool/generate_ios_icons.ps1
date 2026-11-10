# Reutiliza el icono de Android y exporta los tamaños del catálogo de Xcode.
# System.Drawing se ejecuta en Windows; no requiere paquetes adicionales.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskSourcePath = Join-Path $taskRoot 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_adaptive_fore.png'
$taskCatalogPath = Join-Path $taskRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
$taskCatalog = Get-Content -Raw -LiteralPath (Join-Path $taskCatalogPath 'Contents.json') | ConvertFrom-Json
$taskSourceImage = [System.Drawing.Bitmap]::FromFile($taskSourcePath)
try {
    $taskLeft = $taskSourceImage.Width
    $taskTop = $taskSourceImage.Height
    $taskRight = 0
    $taskBottom = 0
    for ($taskY = 0; $taskY -lt $taskSourceImage.Height; $taskY++) {
        for ($taskX = 0; $taskX -lt $taskSourceImage.Width; $taskX++) {
            if ($taskSourceImage.GetPixel($taskX, $taskY).A -gt 0) {
                $taskLeft = [Math]::Min($taskLeft, $taskX)
                $taskTop = [Math]::Min($taskTop, $taskY)
                $taskRight = [Math]::Max($taskRight, $taskX)
                $taskBottom = [Math]::Max($taskBottom, $taskY)
            }
        }
    }
    $taskSourceBounds = [System.Drawing.Rectangle]::new($taskLeft, $taskTop, $taskRight - $taskLeft + 1, $taskBottom - $taskTop + 1)
    foreach ($taskIcon in $taskCatalog.images) {
        if (-not $taskIcon.filename) { continue }
        $taskLogicalSize = [double]::Parse(($taskIcon.size -split 'x')[0], [System.Globalization.CultureInfo]::InvariantCulture)
        $taskScale = [int]($taskIcon.scale -replace 'x', '')
        $taskSize = [int][Math]::Round($taskLogicalSize * $taskScale)
        # Los iconos de App Store deben ser opacos, incluso en las esquinas.
        $taskBitmap = [System.Drawing.Bitmap]::new($taskSize, $taskSize, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $taskGraphics = [System.Drawing.Graphics]::FromImage($taskBitmap)
        try {
            $taskGraphics.Clear([System.Drawing.Color]::FromArgb(25, 25, 30))
            $taskGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $taskGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $taskDestination = [System.Drawing.Rectangle]::new(0, 0, $taskSize, $taskSize)
            $taskGraphics.DrawImage($taskSourceImage, $taskDestination, $taskSourceBounds, [System.Drawing.GraphicsUnit]::Pixel)
            $taskBitmap.Save((Join-Path $taskCatalogPath $taskIcon.filename), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $taskGraphics.Dispose()
            $taskBitmap.Dispose()
        }
    }
} finally {
    $taskSourceImage.Dispose()
}
Write-Output 'Iconos de ServiceMET exportados al catálogo de iOS.'
