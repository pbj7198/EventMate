param(
    [string]$OutputRoot = (Join-Path $PSScriptRoot "..\assets\ocr_models\korean")
)

$ErrorActionPreference = 'Stop'

Write-Host "Preparing Korean OCR model pack..."
Write-Host "Output root: $OutputRoot"

$tempRoot = Join-Path $PSScriptRoot "..\.tmp_ocr_models"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$detOnnx = Join-Path $tempRoot "pp-ocrv5_mobile_det.onnx"
$recOnnx = Join-Path $tempRoot "korean_pp-ocrv5_mobile_rec.onnx"

if (-not (Test-Path $detOnnx)) {
    Invoke-WebRequest `
        -Uri 'https://github.com/GreatV/oar-ocr/releases/download/v0.3.0/pp-ocrv5_mobile_det.onnx' `
        -OutFile $detOnnx
}

if (-not (Test-Path $recOnnx)) {
    Invoke-WebRequest `
        -Uri 'https://github.com/GreatV/oar-ocr/releases/download/v0.3.0/korean_pp-ocrv5_mobile_rec.onnx' `
        -OutFile $recOnnx
}

Push-Location $tempRoot
try {
    pnnx 'pp-ocrv5_mobile_det.onnx' inputshape=[1,3,320,320] inputshape2=[1,3,256,256]
    pnnx 'korean_pp-ocrv5_mobile_rec.onnx' inputshape=[1,3,48,160] inputshape2=[1,3,48,256]

    Copy-Item -Force 'pp_ocrv5_mobile_det.ncnn.param' (Join-Path $OutputRoot 'det.ncnn.param')
    Copy-Item -Force 'pp_ocrv5_mobile_det.ncnn.bin' (Join-Path $OutputRoot 'det.ncnn.bin')
    Copy-Item -Force 'korean_pp_ocrv5_mobile_rec.ncnn.param' (Join-Path $OutputRoot 'rec.ncnn.param')
    Copy-Item -Force 'korean_pp_ocrv5_mobile_rec.ncnn.bin' (Join-Path $OutputRoot 'rec.ncnn.bin')
}
finally {
    Pop-Location
}

Write-Host "Korean OCR model pack is ready."
