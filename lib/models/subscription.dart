class Subscription {
  final String name;
  final String url;

  Subscription({
    required this.name,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }
}