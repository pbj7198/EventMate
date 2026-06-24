package com.qkrqu.inyeon_jangbu

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val ocrChannel = "com.qkrqu.inyeon_jangbu/ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "recognizeText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val imagePath = call.argument<String>("imagePath")
                if (imagePath.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "Image path is empty.", null)
                    return@setMethodCallHandler
                }

                val bitmap = BitmapFactory.decodeFile(imagePath)
                if (bitmap == null) {
                    result.error("INVALID_IMAGE", "The image could not be decoded.", null)
                    return@setMethodCallHandler
                }

                Thread {
                    handleRecognition(imagePath, bitmap, result)
                }.start()
            }
    }

    private fun handleRecognition(
        imagePath: String,
        originalBitmap: Bitmap,
        result: MethodChannel.Result,
    ) {
        val bitmapsToRecycle = mutableListOf<Bitmap>()
        try {
            val upright = applyExifOrientation(imagePath, originalBitmap)
            if (upright !== originalBitmap) {
                bitmapsToRecycle.add(upright)
            }

            val variants = buildVariants(upright)
            bitmapsToRecycle.addAll(variants.filter { it !== upright })

            var hadSuccessfulAttempt = false
            var bestText = ""

            for (variant in variants) {
                val recognized = runCatching { recognizeTextFromBitmap(variant) }.getOrNull()
                if (recognized != null) {
                    hadSuccessfulAttempt = true
                    val trimmed = recognized.trim()
                    if (trimmed.length > bestText.length) {
                        bestText = trimmed
                    }
                }
            }

            val payload = when {
                bestText.isNotEmpty() -> mapOf(
                    "status" to "success",
                    "text" to bestText,
                    "message" to null,
                )
                hadSuccessfulAttempt -> mapOf(
                    "status" to "no_text",
                    "text" to "",
                    "message" to "OCR found no confident text.",
                )
                else -> mapOf(
                    "status" to "error",
                    "text" to "",
                    "message" to "All OCR attempts failed.",
                    "details" to "ML Kit returned errors for every processed variant.",
                )
            }

            runOnUiThread {
                result.success(payload)
            }
        } catch (error: Exception) {
            runOnUiThread {
                result.success(
                    mapOf(
                        "status" to "error",
                        "text" to "",
                        "message" to (error.message ?: "Text recognition failed."),
                        "details" to error.stackTraceToString(),
                    ),
                )
            }
        } finally {
            bitmapsToRecycle.forEach {
                try {
                    if (!it.isRecycled) {
                        it.recycle()
                    }
                } catch (_: Exception) {
                }
            }
            if (!originalBitmap.isRecycled) {
                originalBitmap.recycle()
            }
        }
    }

    private fun buildVariants(bitmap: Bitmap): List<Bitmap> {
        val variants = mutableListOf<Bitmap>()
        variants.add(bitmap)

        if (maxOf(bitmap.width, bitmap.height) < 2200) {
            variants.add(scaleBitmap(bitmap, 2.0))
        }

        variants.addAll(buildBandCrops(bitmap))
        return variants
    }

    private fun buildBandCrops(bitmap: Bitmap): List<Bitmap> {
        val crops = mutableListOf<Bitmap>()
        val height = bitmap.height
        val width = bitmap.width

        crops.add(cropBitmap(bitmap, 0f, 0.72f))
        crops.add(cropBitmap(bitmap, 0.12f, 0.88f))
        crops.add(cropBitmap(bitmap, 0.25f, 1.00f))
        return crops.filter { it.width >= 200 && it.height >= 120 && it.width <= width && it.height <= height }
    }

    private fun cropBitmap(bitmap: Bitmap, topRatio: Float, bottomRatio: Float): Bitmap {
        val left = 0
        val right = bitmap.width
        val top = (bitmap.height * topRatio).toInt().coerceIn(0, bitmap.height - 1)
        val bottom = (bitmap.height * bottomRatio).toInt().coerceIn(top + 1, bitmap.height)
        return Bitmap.createBitmap(bitmap, left, top, right - left, bottom - top)
    }

    private fun scaleBitmap(bitmap: Bitmap, scale: Double): Bitmap {
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        )
    }

    private fun applyExifOrientation(imagePath: String, bitmap: Bitmap): Bitmap {
        val exif = ExifInterface(imagePath)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )

        val matrix = android.graphics.Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.preScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.preScale(-1f, 1f)
            }
            else -> return bitmap
        }

        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun recognizeTextFromBitmap(bitmap: Bitmap): String {
        val image = InputImage.fromBitmap(bitmap, 0)
        val koreanRecognizer = TextRecognition.getClient(
            KoreanTextRecognizerOptions.Builder().build(),
        )
        val latinRecognizer = TextRecognition.getClient(
            TextRecognizerOptions.DEFAULT_OPTIONS,
        )

        return try {
            val koreanText = runCatching {
                Tasks.await(koreanRecognizer.process(image)).text.trim()
            }.getOrNull()

            when {
                !koreanText.isNullOrBlank() -> koreanText
                else -> runCatching {
                    Tasks.await(latinRecognizer.process(image)).text.trim()
                }.getOrNull().orEmpty()
            }
        } finally {
            kotlin.runCatching { koreanRecognizer.close() }
            kotlin.runCatching { latinRecognizer.close() }
        }
    }
}
