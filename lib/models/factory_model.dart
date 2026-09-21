class FactoryModel {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final String gradientStart;
  final String gradientEnd;
  final double rating;
  final int reviewCount;
  final int inquiryCount;
  final bool isPremium;
  final bool isVerified;
  final bool isAvailable;
  final String city;
  final int foundedYear;
  final int employeeCount;
  final String description;
  final String phone;
  final String whatsapp;
  final String email;
  final String website;
  final List<String> tags;
  final List<BranchModel> branches;
  final String facebook;
  final String instagram;
  final String twitter;
  final String youtube;
  final String nickname;
  final String logoUrl;
  final String subscriptionType;
  final String country;
  final int viewsCount;
  final int productsCount;

  const FactoryModel({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    this.gradientStart = '#fff3d0',
    this.gradientEnd = '#ffe090',
    this.rating = 4.0,
    this.reviewCount = 0,
    this.inquiryCount = 0,
    this.isPremium = false,
    this.isVerified = false,
    this.isAvailable = true,
    this.city = 'القاهرة',
    this.foundedYear = 2010,
    this.employeeCount = 50,
    this.description = '',
    this.phone = '',
    this.whatsapp = '',
    this.email = '',
    this.website = '',
    this.tags = const [],
    this.branches = const [],
    this.facebook = '',
    this.instagram = '',
    this.twitter = '',
    this.youtube = '',
    this.nickname = '',
    this.logoUrl = '',
    this.subscriptionType = '',
    this.country = '',
    this.viewsCount = 0,
    this.productsCount = 0,
  });

  FactoryModel withBranches(List<BranchModel> b) => FactoryModel(
        id: id, name: name, category: category, emoji: emoji,
        gradientStart: gradientStart, gradientEnd: gradientEnd,
        rating: rating, reviewCount: reviewCount, inquiryCount: inquiryCount,
        isPremium: isPremium, isVerified: isVerified, isAvailable: isAvailable,
        city: city, foundedYear: foundedYear, employeeCount: employeeCount,
        description: description, phone: phone, whatsapp: whatsapp, email: email,
        website: website, tags: tags, branches: b,
        facebook: facebook, instagram: instagram, twitter: twitter, youtube: youtube,
        nickname: nickname, logoUrl: logoUrl, subscriptionType: subscriptionType,
        country: country, viewsCount: viewsCount, productsCount: productsCount,
      );
}

class BranchModel {
  final String name;
  final String address;
  final String phone;
  final String hours;

  const BranchModel({
    required this.name,
    required this.address,
    required this.phone,
    required this.hours,
  });
}
