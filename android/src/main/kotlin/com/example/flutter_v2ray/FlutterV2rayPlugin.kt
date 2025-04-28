private fun startV2Ray(call: MethodCall, result: Result) {
    try {
        val config = call.argument<String>("config")!!
        val remark = call.argument<String>("remark")!!
        val proxyOnly = call.argument<Boolean>("proxyOnly") ?: false
        val enableIPv6 = call.argument<Boolean>("enableIPv6") ?: false
        val enableMux = call.argument<Boolean>("enableMux") ?: false
        
        v2rayService?.startV2Ray(
            config, 
            remark, 
            proxyOnly, 
            enableIPv6,
            enableMux
        )
        
        result.success(null)
    } catch (e: Exception) {
        result.error("V2RAY_START_ERROR", e.message, null)
    }
}
