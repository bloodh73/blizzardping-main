private fun startV2Ray(call: MethodCall, result: Result) {
    try {
        val config = call.argument<String>("config")!!
        val remark = call.argument<String>("remark")!!
        val proxyOnly = call.argument<Boolean>("proxyOnly") ?: false
        val enableIPv6 = call.argument<Boolean>("enableIPv6") ?: false
        val enableMux = call.argument<Boolean>("enableMux") ?: false
        val enableHttpUpgrade = call.argument<Boolean>("enableHttpUpgrade") ?: false
        
        v2rayService?.startV2Ray(
            config, 
            remark, 
            proxyOnly, 
            enableIPv6,
            enableMux,
            enableHttpUpgrade
        )
        
        result.success(null)
    } catch (e: Exception) {
        result.error("V2RAY_START_ERROR", e.message, null)
    }
}

private fun getV2RayStatus(result: Result) {
    try {
        val status = v2rayService?.getV2RayStatus() ?: mapOf(
            "state" to "DISCONNECTED",
            "uploadSpeed" to 0,
            "downloadSpeed" to 0
        )
        result.success(status)
    } catch (e: Exception) {
        result.error("GET_STATUS_ERROR", e.message, null)
    }
}

// در متد onMethodCall اضافه کنید:
"getV2RayStatus" -> getV2RayStatus(result)






