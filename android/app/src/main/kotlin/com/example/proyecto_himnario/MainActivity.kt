package com.example.proyecto_himnario

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.iump.himnario2026/browser"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openInBrowser") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val uri = Uri.parse(url)
                        val browserQuery = Intent(Intent.ACTION_VIEW, Uri.parse("https://"))
                        val resolveInfos = packageManager.queryIntentActivities(browserQuery, 0)

                        var targetPackage: String? = null
                        for (info in resolveInfos) {
                            val pkg = info.activityInfo.packageName
                            if (pkg != packageName) {
                                targetPackage = pkg
                                if (pkg.contains("chrome") || pkg.contains("sbrowser")) {
                                    break
                                }
                            }
                        }

                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        intent.addCategory(Intent.CATEGORY_BROWSABLE)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        if (targetPackage != null) {
                            intent.setPackage(targetPackage)
                            startActivity(intent)
                        } else {
                            val chooser = Intent.createChooser(intent, "Abrir en navegador")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_URL", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
