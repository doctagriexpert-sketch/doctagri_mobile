package com.doctagri.app

import android.content.Context
import android.os.Build
import android.util.AtomicFile
import android.widget.Toast
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.File
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.concurrent.TimeUnit
import javax.net.ssl.HttpsURLConnection

/** Identity is excluded from backups, so a restored phone gets its own identity. */
internal object InstallationRegistration {
    private const val WORK_NAME = "doctagri-installation-registration-v1"

    private fun file(context: Context) =
        AtomicFile(File(context.noBackupFilesDir, "installation-registration.json"))

    @Synchronized
    fun read(context: Context): JSONObject? {
        val storage = file(context)
        if (!storage.baseFile.exists()) return null
        return JSONObject(storage.openRead().bufferedReader().use { it.readText() })
    }

    private fun write(context: Context, record: JSONObject) {
        val storage = file(context)
        val stream = storage.startWrite()
        try {
            stream.write(record.toString().toByteArray(Charsets.UTF_8))
            storage.finishWrite(stream)
        } catch (e: Exception) {
            storage.failWrite(stream)
            throw e
        }
    }

    @Synchronized
    fun markUploaded(context: Context) {
        val record = read(context) ?: return
        record.put("uploaded", true)
        write(context, record)
    }

    @Synchronized
    fun schedule(context: Context, url: String, anonKey: String) {
        val existing = read(context)
        val record = existing ?: JSONObject().apply {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            dateFormat.timeZone = TimeZone.getTimeZone("UTC")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            put("payload", JSONObject().apply {
                put("p_installation_id", UUID.randomUUID().toString())
                put("p_first_opened_at", dateFormat.format(Date()))
                put("p_manufacturer", Build.MANUFACTURER.take(100))
                put("p_model", Build.MODEL.take(100))
                put("p_os_version", Build.VERSION.RELEASE.take(50))
                put("p_app_version", (info.versionName ?: "unknown").take(50))
            })
            put("uploaded", false)
        }
        // Persist first-open data even if this APK has no server configuration.
        write(context, record)
        if (existing == null) {
            Toast.makeText(context,
                "DoctAgri transmettra un identifiant d’installation et les versions du téléphone " +
                    "et de l’application au retour d’Internet, sans nom ni position GPS.",
                Toast.LENGTH_LONG).show()
        }
        if (record.optBoolean("uploaded")) return
        if (url.isBlank() || anonKey.isBlank()) return
        val endpoint = URL(url.trimEnd('/') + "/rest/v1/rpc/register_app_installation")
        require(endpoint.protocol == "https" && endpoint.host.isNotBlank() && endpoint.userInfo == null)
        record.put("endpoint", endpoint.toString())
        record.put("anon_key", anonKey)
        write(context, record)
        val request = OneTimeWorkRequestBuilder<InstallationRegistrationWorker>()
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.KEEP, request)
    }
}

/** WorkManager launches this native worker even when no Flutter UI is running. */
class InstallationRegistrationWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        var connection: HttpsURLConnection? = null
        return try {
            val record = InstallationRegistration.read(applicationContext) ?: return Result.failure()
            if (record.optBoolean("uploaded")) return Result.success()
            connection = URL(record.getString("endpoint")).openConnection() as HttpsURLConnection
            connection.apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                instanceFollowRedirects = false
                doOutput = true
                setRequestProperty("apikey", record.getString("anon_key"))
                setRequestProperty("Content-Type", "application/json")
            }
            connection.outputStream.use {
                it.write(record.getJSONObject("payload").toString().toByteArray(Charsets.UTF_8))
            }
            if (connection.responseCode in 200..299) {
                InstallationRegistration.markUploaded(applicationContext)
                Result.success()
            } else {
                // Keep retrying, including while the server migration is not deployed.
                Result.retry()
            }
        } catch (e: Exception) {
            Result.retry()
        } finally {
            connection?.disconnect()
        }
    }
}
