package bo.metrica.smet

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import androidx.annotation.NonNull
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File

/**
 * Actividad principal de ServiceMET.
 *
 * Expone un puente hacia Storage Access Framework para que la capa Dart pueda
 * escribir la documentación de cada servicio en una carpeta elegida por el
 * técnico sin necesitar MANAGE_EXTERNAL_STORAGE ni permisos de medios.
 */
class MainActivity : FlutterFragmentActivity() {

    private companion object {
        const val CHANNEL = "bo.metrica.smet/saf"
        const val REQUEST_PICK_TREE = 0x5AF0
        const val PERSISTABLE_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleSafCall(call, result) }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        val isDark = (newConfig.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        window.setBackgroundDrawableResource(
            if (isDark) android.R.color.black else android.R.color.white
        )
    }

    // region Puente SAF

    private fun handleSafCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickDirectory" -> pickDirectory(result)
            "isTreeAvailable" -> result.success(isTreeAvailable(call.argument("uri")))
            "treeName" -> result.success(treeName(call.argument("uri")))
            "releaseDirectory" -> {
                releaseDirectory(call.argument("uri"))
                result.success(null)
            }
            "writeDocument" -> writeDocument(call, result)
            "copyDocument" -> copyDocument(call, result)
            "openDocument" -> openDocument(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "Ya hay un selector de carpeta abierto", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(PERSISTABLE_FLAGS or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        pendingPickResult = result
        try {
            startActivityForResult(intent, REQUEST_PICK_TREE)
        } catch (e: Exception) {
            pendingPickResult = null
            result.error("picker_unavailable", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK_TREE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPickResult ?: return
        pendingPickResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(uri, PERSISTABLE_FLAGS)
            result.success(
                mapOf(
                    "uri" to uri.toString(),
                    "name" to (DocumentFile.fromTreeUri(this, uri)?.name ?: "")
                )
            )
        } catch (e: Exception) {
            result.error("permission_failed", e.message, null)
        }
    }

    /**
     * Confirma que el permiso URI persistente sigue vigente y que la carpeta
     * continúa existiendo. El técnico puede revocarlo o borrar la carpeta desde
     * el explorador de archivos entre un servicio y otro.
     */
    private fun isTreeAvailable(uriString: String?): Boolean {
        val uri = parseUri(uriString) ?: return false
        val persisted = contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isWritePermission
        }
        if (!persisted) return false
        val dir = DocumentFile.fromTreeUri(this, uri)
        return dir != null && dir.exists() && dir.canWrite()
    }

    private fun treeName(uriString: String?): String? {
        val uri = parseUri(uriString) ?: return null
        return DocumentFile.fromTreeUri(this, uri)?.name
    }

    private fun releaseDirectory(uriString: String?) {
        val uri = parseUri(uriString) ?: return
        try {
            contentResolver.releasePersistableUriPermission(uri, PERSISTABLE_FLAGS)
        } catch (_: Exception) {
            // El permiso ya no existía; no hay nada que liberar.
        }
    }

    private fun writeDocument(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
            result.error("invalid_arguments", "Falta el contenido del archivo", null)
            return
        }
        createTarget(call, result)?.let { target ->
            try {
                contentResolver.openOutputStream(target.uri, "wt").use { output ->
                    if (output == null) {
                        result.error("write_failed", "No se pudo abrir el archivo destino", null)
                        return
                    }
                    output.write(bytes)
                    output.flush()
                }
                result.success(target.uri.toString())
            } catch (e: Exception) {
                result.error("write_failed", e.message, null)
            }
        }
    }

    private fun copyDocument(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        if (sourcePath == null) {
            result.error("invalid_arguments", "Falta la ruta de origen", null)
            return
        }
        val source = File(sourcePath)
        if (!source.isFile) {
            result.error("source_missing", "El archivo de origen no existe", null)
            return
        }
        createTarget(call, result)?.let { target ->
            try {
                contentResolver.openOutputStream(target.uri, "wt").use { output ->
                    if (output == null) {
                        result.error("write_failed", "No se pudo abrir el archivo destino", null)
                        return
                    }
                    source.inputStream().use { input -> input.copyTo(output) }
                    output.flush()
                }
                result.success(target.uri.toString())
            } catch (e: Exception) {
                result.error("write_failed", e.message, null)
            }
        }
    }

    /**
     * Resuelve `treeUri/segments.../fileName`, creando los subdirectorios que
     * falten. Devuelve null y responde el error por el canal cuando la carpeta
     * ya no está disponible.
     */
    private fun createTarget(call: MethodCall, result: MethodChannel.Result): DocumentFile? {
        val treeUri = parseUri(call.argument<String>("treeUri"))
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
        val segments = call.argument<List<String>>("segments") ?: emptyList()

        if (treeUri == null || fileName.isNullOrEmpty()) {
            result.error("invalid_arguments", "treeUri y fileName son obligatorios", null)
            return null
        }

        val root = DocumentFile.fromTreeUri(this, treeUri)
        if (root == null || !root.exists() || !root.canWrite()) {
            result.error(
                "tree_unavailable",
                "La carpeta de ServiceMET ya no está disponible",
                null
            )
            return null
        }

        var dir: DocumentFile = root
        for (segment in segments) {
            if (segment.isBlank()) continue
            val existing = dir.findFile(segment)
            val next = if (existing != null && existing.isDirectory) {
                existing
            } else {
                dir.createDirectory(segment)
            }
            if (next == null) {
                result.error("mkdir_failed", "No se pudo crear la carpeta $segment", null)
                return null
            }
            dir = next
        }

        // Sobrescribir en vez de dejar que SAF genere "archivo (1).csv".
        dir.findFile(fileName)?.takeIf { it.isFile }?.delete()

        val target = dir.createFile(mimeType, fileName)
        if (target == null) {
            result.error("create_failed", "No se pudo crear $fileName", null)
            return null
        }
        return target
    }

    private fun openDocument(call: MethodCall, result: MethodChannel.Result) {
        val uri = parseUri(call.argument<String>("uri"))
        if (uri == null) {
            result.error("invalid_arguments", "Falta el uri del documento", null)
            return
        }
        val mimeType = call.argument<String>("mimeType") ?: "*/*"
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            val chooser = Intent.createChooser(view, "Abrir archivo")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            // Sin visor instalado el archivo ya quedó guardado; no es un fallo
            // de exportación.
            result.success(false)
        }
    }

    private fun parseUri(value: String?): Uri? {
        if (value.isNullOrEmpty()) return null
        return try {
            Uri.parse(value)
        } catch (_: Exception) {
            null
        }
    }

    // endregion
}
