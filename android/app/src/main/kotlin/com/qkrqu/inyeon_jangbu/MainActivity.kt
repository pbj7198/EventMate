package com.qkrqu.inyeon_jangbu

import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

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

                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("INVALID_IMAGE", "Image bytes are empty.", null)
                    return@setMethodCallHandler
                }

                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    result.error("INVALID_IMAGE", "The image could not be decoded.", null)
                    return@setMethodCallHandler
                }

                recognizeText(InputImage.fromBitmap(bitmap, 0), result)
            }
    }

    private fun recognizeText(inputImage: InputImage, result: MethodChannel.Result) {
        val koreanRecognizer = TextRecognition.getClient(
            KoreanTextRecognizerOptions.Builder().build()
        )

        koreanRecognizer.process(inputImage)
            .addOnSuccessListener { recognized ->
                koreanRecognizer.close()
                result.success(recognized.text)
            }
            .addOnFailureListener { koreanError ->
                koreanRecognizer.close()
                recognizeLatinText(inputImage, koreanError, result)
            }
    }

    private fun recognizeLatinText(
        inputImage: InputImage,
        koreanError: Exception,
        result: MethodChannel.Result,
    ) {
        val latinRecognizer = TextRecognition.getClient(
            TextRecognizerOptions.DEFAULT_OPTIONS
        )

        latinRecognizer.process(inputImage)
            .addOnSuccessListener { recognized ->
                latinRecognizer.close()
                result.success(recognized.text)
            }
            .addOnFailureListener { latinError ->
                latinRecognizer.close()
                result.error(
                    "OCR_FAILED",
                    latinError.message ?: "Text recognition failed.",
                    "Korean: ${koreanError.message}; Latin: ${latinError.message}",
                )
            }
    }
}
