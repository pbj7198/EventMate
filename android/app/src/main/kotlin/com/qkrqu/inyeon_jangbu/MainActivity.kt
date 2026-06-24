package com.qkrqu.inyeon_jangbu

import android.os.Handler
import android.os.Looper
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val ocrChannel = "com.qkrqu.inyeon_jangbu/ocr"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ocrChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "recognizeText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val imagePath = call.argument<String>("imagePath")
                val tessDataPath = call.argument<String>("tessDataPath")
                val language = call.argument<String>("language") ?: "eng"
                val args = call.argument<Map<String, String>>("args")

                if (imagePath.isNullOrBlank()) {
                    result.error("INVALID_IMAGE", "Image path is empty.", null)
                    return@setMethodCallHandler
                }
                if (tessDataPath.isNullOrBlank()) {
                    result.error("INVALID_TESSDATA", "Tessdata path is empty.", null)
                    return@setMethodCallHandler
                }

                Thread {
                    val api = TessBaseAPI()
                    try {
                        if (!api.init(tessDataPath, language)) {
                            postError(
                                result,
                                "OCR_INIT_FAILED",
                                "Tesseract failed to initialize.",
                                null,
                            )
                            return@Thread
                        }

                        var psm = TessBaseAPI.PageSegMode.PSM_AUTO_OSD
                        args?.forEach { (key, value) ->
                            if (key == "psm") {
                                psm = parsePageSegMode(value)
                            } else {
                                api.setVariable(key, value)
                            }
                        }

                        api.setPageSegMode(psm)
                        api.setImage(File(imagePath))
                        val recognizedText = api.getUTF8Text() ?: ""
                        api.stop()

                        mainHandler.post {
                            result.success(recognizedText)
                        }
                    } catch (error: Exception) {
                        postError(
                            result,
                            "OCR_FAILED",
                            error.message ?: "Text recognition failed.",
                            error.stackTraceToString(),
                        )
                    } finally {
                        try {
                            api.recycle()
                        } catch (_: Exception) {
                        }
                    }
                }.start()
            }
    }

    private fun postError(
        result: MethodChannel.Result,
        code: String,
        message: String,
        details: Any?,
    ) {
        mainHandler.post {
            result.error(code, message, details)
        }
    }

    private fun parsePageSegMode(value: String): Int {
        return value.toIntOrNull() ?: TessBaseAPI.PageSegMode.PSM_AUTO_OSD
    }
}
