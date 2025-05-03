private func getV2RayStatus(result: @escaping FlutterResult) {
    let status = v2rayService.getV2RayStatus()
    result(status)
}

// در متد handle اضافه کنید:
case "getV2RayStatus":
    getV2RayStatus(result: result)



