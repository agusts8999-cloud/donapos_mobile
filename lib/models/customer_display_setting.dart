class CustomerDisplaySetting {
  final String welcomeText;
  final List<String> promoImages;
  final String cartLayout;
  final bool showPromo;
  final String themeColor;

  CustomerDisplaySetting({
    required this.welcomeText,
    required this.promoImages,
    required this.cartLayout,
    required this.showPromo,
    required this.themeColor,
  });

  factory CustomerDisplaySetting.fromJson(Map<String, dynamic> json) {
    return CustomerDisplaySetting(
      welcomeText: json['welcome_text'] ?? 'Selamat Datang di donaPOS',
      promoImages: json['promo_images'] != null 
          ? List<String>.from(json['promo_images']) 
          : [],
      cartLayout: json['cart_layout'] ?? 'default',
      showPromo: json['show_promo'] ?? true,
      themeColor: json['theme_color'] ?? '#f58634',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'welcome_text': welcomeText,
      'promo_images': promoImages,
      'cart_layout': cartLayout,
      'show_promo': showPromo,
      'theme_color': themeColor,
    };
  }
}
