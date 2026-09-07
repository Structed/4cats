<#
.SYNOPSIS
    Erzeugt die Launcher-Symbole fuer Android aus dem SVG-Icon.

.DESCRIPTION
    Android verlangt ein klassisches Symbol (mindestens 192x192) sowie
    Vorder- und Hintergrund fuer adaptive Symbole (mindestens 432x432).
    Die Grafiken werden hier gezeichnet, damit keine externen Werkzeuge
    noetig sind und das Ergebnis reproduzierbar bleibt.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\assets\icon")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$BACKGROUND = [System.Drawing.Color]::FromArgb(255, 43, 58, 85)
$FUR = [System.Drawing.Color]::FromArgb(255, 240, 168, 104)
$EAR_INNER = [System.Drawing.Color]::FromArgb(255, 224, 112, 95)
$OUTLINE = [System.Drawing.Color]::FromArgb(255, 43, 58, 85)
$WHITE = [System.Drawing.Color]::White


# Zeichnet den Katzenkopf zentriert in ein Quadrat der Kantenlaenge $Size.
# $Inset gibt an, wie viel Rand frei bleibt (0.0 - 0.4). Adaptive Symbole
# brauchen viel Rand, weil der Launcher sie beschneidet.
function Add-CatFace {
    param(
        [System.Drawing.Graphics]$Graphics,
        [int]$Size,
        [double]$Inset
    )

    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $margin = $Size * $Inset
    $box = $Size - 2 * $margin
    $cx = $Size / 2.0
    $cy = $margin + $box * 0.58

    $headW = $box * 0.78
    $headH = $box * 0.70

    $furBrush = New-Object System.Drawing.SolidBrush $FUR
    $earBrush = New-Object System.Drawing.SolidBrush $EAR_INNER
    $darkBrush = New-Object System.Drawing.SolidBrush $OUTLINE
    $whiteBrush = New-Object System.Drawing.SolidBrush $WHITE

    # Ohren
    $earOuterLeft = @(
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.46), [float]($cy - $headH * 0.18))),
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.42), [float]($cy - $headH * 0.86))),
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.05), [float]($cy - $headH * 0.44)))
    )
    $earOuterRight = @(
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.46), [float]($cy - $headH * 0.18))),
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.42), [float]($cy - $headH * 0.86))),
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.05), [float]($cy - $headH * 0.44)))
    )
    $Graphics.FillPolygon($furBrush, $earOuterLeft)
    $Graphics.FillPolygon($furBrush, $earOuterRight)

    $earInnerLeft = @(
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.38), [float]($cy - $headH * 0.30))),
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.35), [float]($cy - $headH * 0.72))),
        (New-Object System.Drawing.PointF ([float]($cx - $headW * 0.12), [float]($cy - $headH * 0.46)))
    )
    $earInnerRight = @(
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.38), [float]($cy - $headH * 0.30))),
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.35), [float]($cy - $headH * 0.72))),
        (New-Object System.Drawing.PointF ([float]($cx + $headW * 0.12), [float]($cy - $headH * 0.46)))
    )
    $Graphics.FillPolygon($earBrush, $earInnerLeft)
    $Graphics.FillPolygon($earBrush, $earInnerRight)

    # Kopf
    $Graphics.FillEllipse($furBrush, [float]($cx - $headW / 2), [float]($cy - $headH / 2),
        [float]$headW, [float]$headH)

    # Augen
    $eyeW = $headW * 0.13
    $eyeH = $headH * 0.20
    foreach ($sign in @(-1, 1)) {
        $ex = $cx + $sign * $headW * 0.22 - $eyeW / 2
        $ey = $cy - $headH * 0.12
        $Graphics.FillEllipse($darkBrush, [float]$ex, [float]$ey, [float]$eyeW, [float]$eyeH)
        $Graphics.FillEllipse($whiteBrush, [float]($ex + $eyeW * 0.25), [float]($ey + $eyeH * 0.12),
            [float]($eyeW * 0.34), [float]($eyeH * 0.28))
    }

    # Nase
    $noseW = $headW * 0.12
    $nose = @(
        (New-Object System.Drawing.PointF ([float]$cx, [float]($cy + $headH * 0.20))),
        (New-Object System.Drawing.PointF ([float]($cx - $noseW / 2), [float]($cy + $headH * 0.10))),
        (New-Object System.Drawing.PointF ([float]($cx + $noseW / 2), [float]($cy + $headH * 0.10)))
    )
    $Graphics.FillPolygon($earBrush, $nose)

    # Mund und Schnurrhaare
    $pen = New-Object System.Drawing.Pen $OUTLINE, ([float]($Size * 0.016))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $mouthY = $cy + $headH * 0.20
    $Graphics.DrawLine($pen, [float]$cx, [float]$mouthY, [float]$cx, [float]($mouthY + $headH * 0.09))
    $Graphics.DrawArc($pen, [float]($cx - $headW * 0.20), [float]($mouthY + $headH * 0.02),
        [float]($headW * 0.20), [float]($headH * 0.18), 0, 110)
    $Graphics.DrawArc($pen, [float]$cx, [float]($mouthY + $headH * 0.02),
        [float]($headW * 0.20), [float]($headH * 0.18), 70, 110)

    foreach ($sign in @(-1, 1)) {
        foreach ($offset in @(-0.06, 0.06)) {
            $y = $cy + $headH * (0.12 + $offset)
            $x1 = $cx + $sign * $headW * 0.34
            $x2 = $cx + $sign * $headW * 0.62
            $Graphics.DrawLine($pen, [float]$x1, [float]$y, [float]$x2, [float]($y + $offset * $headH * 0.5))
        }
    }

    $furBrush.Dispose(); $earBrush.Dispose(); $darkBrush.Dispose(); $whiteBrush.Dispose(); $pen.Dispose()
}

function New-Icon {
    param(
        [int]$Size,
        [string]$Path,
        [bool]$WithBackground,
        [bool]$FaceOnly = $true,
        [double]$Inset = 0.06
    )
    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    if ($WithBackground) {
        $graphics.Clear($BACKGROUND)
    } else {
        $graphics.Clear([System.Drawing.Color]::Transparent)
    }
    if ($FaceOnly) {
        Add-CatFace -Graphics $graphics -Size $Size -Inset $Inset
    }
    $graphics.Dispose()
    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    Write-Host "  $Path (${Size}x${Size})"
}


$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path $OutputDirectory)) { New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null }

Write-Host "Erzeuge Android-Symbole:"
# Klassisches Symbol: Hintergrund mit drin, wenig Rand.
New-Icon -Size 192 -Path (Join-Path $OutputDirectory 'icon_192.png') -WithBackground $true -Inset 0.08
# Adaptives Symbol: Vordergrund transparent und mit viel Rand, weil der
# Launcher bis zu 33 % der Kanten abschneiden darf.
New-Icon -Size 432 -Path (Join-Path $OutputDirectory 'icon_adaptive_foreground_432.png') -WithBackground $false -Inset 0.26
New-Icon -Size 432 -Path (Join-Path $OutputDirectory 'icon_adaptive_background_432.png') -WithBackground $true -FaceOnly $false
