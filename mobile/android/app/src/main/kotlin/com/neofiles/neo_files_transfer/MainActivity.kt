package com.neofiles.neo_files_transfer

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val MEDIA_CHANNEL = "com.neofiles.transfer/media_scanner"
    private val SHARE_CHANNEL = "com.neofiles.transfer/share_receiver"

    private var shareMethodChannel: MethodChannel? = null
    private val pendingSharedFiles = mutableListOf<Map<String, Any>>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Media Scanner Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.argument<String>("path")
                if (path != null) {
                    MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ -> }
                    result.success(true)
                } else {
                    result.error("INVALID_PATH", "Path was null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Share Receiver Channel
        shareMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedFiles" -> {
                    val files = ArrayList(pendingSharedFiles)
                    pendingSharedFiles.clear()
                    result.success(files)
                }
                "clearSharedFiles" -> {
                    pendingSharedFiles.clear()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // If files were caught before engine was ready, deliver them
        if (pendingSharedFiles.isNotEmpty()) {
            shareMethodChannel?.invokeMethod("onSharedFilesReceived", ArrayList(pendingSharedFiles))
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return

        when (action) {
            Intent.ACTION_SEND -> {
                val uri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }

                if (uri != null) {
                    val fileData = processUri(uri)
                    if (fileData != null) {
                        deliverSharedFiles(listOf(fileData))
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }

                if (uris != null && uris.isNotEmpty()) {
                    val filesList = mutableListOf<Map<String, Any>>()
                    for (uri in uris) {
                        val fileData = processUri(uri)
                        if (fileData != null) {
                            filesList.add(fileData)
                        }
                    }
                    if (filesList.isNotEmpty()) {
                        deliverSharedFiles(filesList)
                    }
                }
            }
        }
    }

    private fun deliverSharedFiles(files: List<Map<String, Any>>) {
        pendingSharedFiles.addAll(files)
        shareMethodChannel?.invokeMethod("onSharedFilesReceived", ArrayList(files))
    }

    private fun processUri(uri: Uri): Map<String, Any>? {
        return try {
            var fileName = "shared_file_${System.currentTimeMillis()}"
            var fileSize = 0L
            val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"

            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIndex != -1) {
                        val name = cursor.getString(nameIndex)
                        if (!name.isNullOrEmpty()) fileName = name
                    }
                    if (sizeIndex != -1) {
                        fileSize = cursor.getLong(sizeIndex)
                    }
                }
            }

            val cacheDir = File(cacheDir, "shared_incoming")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            val sanitizedName = fileName.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
            val destFile = File(cacheDir, "${System.currentTimeMillis()}_$sanitizedName")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (destFile.exists()) {
                if (fileSize <= 0) fileSize = destFile.length()
                mapOf(
                    "name" to fileName,
                    "path" to destFile.absolutePath,
                    "size" to fileSize,
                    "mimeType" to mimeType
                )
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
