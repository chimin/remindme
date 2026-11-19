package chimin.remindme.google_account

import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class GoogleAccountPlugin : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var requestCode = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "chimin.remindme/google_account")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        finishError("temporary", "Sign in was interrupted.")
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() {
        onDetachedFromActivityForConfigChanges()
        finishError("temporary", "Sign in was interrupted.")
    }
    private fun finishError(code: String, message: String) {
        val result = pending
        pending = null
        result?.error(code, message, null)
    }
    private fun failure(result: MethodChannel.Result, error: Exception) {
        val code = if (error is ApiException) when (error.statusCode) {
            CommonStatusCodes.CANCELED -> "canceled"
            CommonStatusCodes.DEVELOPER_ERROR -> "configuration"
            CommonStatusCodes.SIGN_IN_REQUIRED, CommonStatusCodes.RESOLUTION_REQUIRED -> "interaction_required"
            else -> "temporary"
        } else "temporary"
        result.error(code, if (code == "configuration") "Google sign in is not configured for this app." else "Unable to sign in. Please retry.", null)
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "chooseAccount" -> {
                val host = activity
                if (host == null) { result.error("interaction_required", "Open the app to sign in.", null); return }
                if (pending != null) { result.error("temporary", "Sign in is already in progress.", null); return }
                pending = result
                requestCode = 4011
                try {
                    host.startActivityForResult(AccountManager.newChooseAccountIntent(null, null, arrayOf("com.google"), null, null, null, null), requestCode)
                } catch (error: Exception) { finishError("temporary", "Unable to open the Google account chooser.") }
            }
            "authorize" -> {
                val email = call.argument<String>("email")
                if (email.isNullOrBlank()) { result.error("configuration", "Please sign in to continue.", null); return }
                val interactive = call.argument<Boolean>("interactive") == true
                val client = Identity.getAuthorizationClient(context)
                val request = AuthorizationRequest.builder()
                    .setAccount(Account(email, "com.google"))
                    .setRequestedScopes(listOf(Scope("https://www.googleapis.com/auth/tasks")))
                    .build()
                client.authorize(request).addOnSuccessListener { authorization ->
                    if (!authorization.hasResolution()) {
                        val token = authorization.accessToken
                        if (token == null) result.error("interaction_required", "Please sign in again.", null)
                        else result.success(token)
                    } else {
                        val host = activity
                        if (!interactive || host == null) { result.error("interaction_required", "Please sign in again.", null) }
                        else if (pending != null) { result.error("temporary", "Sign in is already in progress.", null) }
                        else {
                            pending = result
                            requestCode = 4012
                            try { host.startIntentSenderForResult(authorization.pendingIntent!!.intentSender, requestCode, null, 0, 0, 0) }
                            catch (error: Exception) { finishError("temporary", "Unable to open Google sign in.") }
                        }
                    }
                }.addOnFailureListener { failure(result, it) }
            }
            "invalidateToken" -> {
                val token = call.argument<String>("token")
                if (token == null) { result.error("configuration", "A token is required.", null); return }
                Identity.getAuthorizationClient(context).clearToken(ClearTokenRequest.builder().setToken(token).build())
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { failure(result, it) }
            }
            else -> result.notImplemented()
        }
    }
    override fun onActivityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (pending == null || code != requestCode) return false
        val result = pending!!
        pending = null
        if (status != Activity.RESULT_OK) { result.error("canceled", "Sign in with Google to use Remind Me.", null); return true }
        if (code == 4011) {
            val email = data?.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
            val type = data?.getStringExtra(AccountManager.KEY_ACCOUNT_TYPE)
            if (email.isNullOrBlank() || type != "com.google") result.error("canceled", "Choose a Google account.", null)
            else result.success(email)
        } else {
            try {
                val authorization = Identity.getAuthorizationClient(context).getAuthorizationResultFromIntent(data)
                val token = authorization.accessToken
                if (token == null || !authorization.grantedScopes.contains("https://www.googleapis.com/auth/tasks")) {
                    result.error("interaction_required", "Google Tasks permission is required.", null)
                } else result.success(token)
            } catch (error: Exception) { failure(result, error) }
        }
        return true
    }
}
