import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

class SubscriptionService {
  // چندین آدرس برای دریافت سابسکریپشن رایگان
  static const List<String> FREE_SUB_URLS = [
    'https://blizzardping.ir/free_sub.txt',
    // آدرس‌های جایگزین را اضافه کنید
    'https://raw.githubusercontent.com/bloodh73/blizzardping-main/main/free_sub.txt',
  ];

  static Future<String?> getFreeSubscription() async {
    // تلاش با استفاده از http
    for (final url in FREE_SUB_URLS) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final subscriptionUrl = response.body.trim();
          if (subscriptionUrl.isNotEmpty) {
            return subscriptionUrl;
          }
        }
      } catch (e) {
        print('Failed to get free subscription from $url: $e');
        // ادامه به آدرس بعدی
      }
    }
    
    // تلاش با استفاده از Dio اگر http موفق نبود
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ));
      
      for (final url in FREE_SUB_URLS) {
        try {
          final response = await dio.get(url);
          if (response.statusCode == 200) {
            final subscriptionUrl = response.data.toString().trim();
            if (subscriptionUrl.isNotEmpty) {
              return subscriptionUrl;
            }
          }
        } catch (e) {
          print('Dio failed to get free subscription from $url: $e');
          // ادامه به آدرس بعدی
        }
      }
    } catch (e) {
      print('Error in Dio request: $e');
    }
    
    return null;
  }
}
