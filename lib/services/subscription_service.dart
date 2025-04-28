import 'package:http/http.dart' as http;

class SubscriptionService {
  static const String FREE_SUB_URL =
      'https://blizzardping.ir/free_sub.txt'; // آدرس فایل txt روی هاست شما

  static Future<String?> getFreeSubscription() async {
    try {
      final response = await http.get(Uri.parse(FREE_SUB_URL));

      if (response.statusCode == 200) {
        final subscriptionUrl = response.body.trim();
        if (subscriptionUrl.isNotEmpty) {
          return subscriptionUrl;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}