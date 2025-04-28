private func startV2Ray(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let config = args["config"] as? String,
          let remark = args["remark"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
    }
    
    let proxyOnly = args["proxyOnly"] as? Bool ?? false
    let enableIPv6 = args["enableIPv6"] as? Bool ?? false
    let enableMux = args["enableMux"] as? Bool ?? false
    
    v2rayService.startV2Ray(
        config: config, 
        remark: remark, 
        proxyOnly: proxyOnly, 
        enableIPv6: enableIPv6,
        enableMux: enableMux
    )
    
    result(nil)
}
