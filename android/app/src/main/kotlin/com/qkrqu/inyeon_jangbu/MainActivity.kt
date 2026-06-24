package com.qkrqu.inyeon_jangbu

import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
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

                recognizeText(bitmap, result)
            }
    }

    private fun recognizeText(bitmap: android.graphics.Bitmap, result: MethodChannel.Result) {
        Thread {
            try {
                val originalText = recognizeTextFromBitmap(bitmap)
                val scaledBitmap = createScaledBitmap(bitmap)
                val scaledText = if (scaledBitmap != null) {
                    try {
                        recognizeTextFromBitmap(scaledBitmap)
                    } finally {
                        scaledBitmap.recycle()
                    }
                } else {
                    ""
                }

                val bestText = listOf(originalText, scaledText).maxBy { it.length }.trim()
                runOnUiThread { result.success(bestText) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "OCR_FAILED",
                        error.message ?: "Text recognition failed.",
                        error.stackTraceToString(),
                    )
                }
            }
        }.start()
    }

    private fun recognizeTextFromBitmap(bitmap: android.graphics.Bitmap): String {
        val image = InputImage.fromBitmap(bitmap, 0)
        val koreanRecognizer = TextRecognition.getClient(
            KoreanTextRecognizerOptions.Builder().build()
        )
        val latinRecognizer = TextRecognition.getClient(
            TextRecognizerOptions.DEFAULT_OPTIONS
        )

        return try {
            val koreanText = Tasks.await(koreanRecognizer.process(image)).text.trim()
            if (koreanText.isNotEmpty()) {
                koreanText
            } else {
                Tasks.await(latinRecognizer.process(image)).text.trim()
            }
        } catch (_: Exception) {
            try {
                Tasks.await(latinRecognizer.process(image)).text.trim()
            } catch (error: Exception) {
                throw error
            }
        } finally {
            koreanRecognizer.close()
            latinRecognizer.close()
        }
    }

    private fun createScaledBitmap(bitmap: android.graphics.Bitmap): android.graphics.Bitmap? {
        val width = bitmap.width
        val height = bitmap.height
        val maxSide = maxOf(width, height)
        if (maxSide >= 2200) {
            return null
        }

        val scale = 2.0
        return android.graphics.Bitmap.createScaledBitmap(
            bitmap,
            (width * scale).toInt(),
            (height * scale).toInt(),
            true,
        )
    }
}
