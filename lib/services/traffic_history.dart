import 'dart:collection';

class TrafficHistory {
  static const int maxDataPoints = 30;
  
  final Queue<int> uploadHistory = Queue<int>();
  final Queue<int> downloadHistory = Queue<int>();
  final Queue<int> pingHistory = Queue<int>();
  
  void addTrafficData(int uploadSpeed, int downloadSpeed, int ping) {
    // اضافه کردن داده‌های جدید
    uploadHistory.add(uploadSpeed);
    downloadHistory.add(downloadSpeed);
    pingHistory.add(ping);
    
    // حذف داده‌های قدیمی اگر تعداد بیشتر از حداکثر است
    while (uploadHistory.length > maxDataPoints) {
      uploadHistory.removeFirst();
    }
    
    while (downloadHistory.length > maxDataPoints) {
      downloadHistory.removeFirst();
    }
    
    while (pingHistory.length > maxDataPoints) {
      pingHistory.removeFirst();
    }
  }
  
  List<int> getUploadHistory() {
    return uploadHistory.toList();
  }
  
  List<int> getDownloadHistory() {
    return downloadHistory.toList();
  }
  
  List<int> getPingHistory() {
    return pingHistory.toList();
  }
  
  void clear() {
    uploadHistory.clear();
    downloadHistory.clear();
    pingHistory.clear();
  }
}