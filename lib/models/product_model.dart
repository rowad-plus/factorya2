class ProductModel {
  final String id;
  final String name;
  final String factoryName;
  final String factoryId;
  final String category;
  final String emoji;
  final String gradientStart;
  final String gradientEnd;
  final double rating;
  final int reviewCount;
  final int inquiryCount;
  final bool isAvailable;
  final String description;
  final String minOrder;
  final String leadTime;
  final String origin;
  final String certification;
  final String imageUrl;
  final String price;

  const ProductModel({
    required this.id,
    required this.name,
    required this.factoryName,
    required this.factoryId,
    required this.category,
    required this.emoji,
    this.gradientStart = '#fff3d0',
    this.gradientEnd = '#ffe090',
    this.rating = 4.0,
    this.reviewCount = 0,
    this.inquiryCount = 0,
    this.isAvailable = true,
    this.description = '',
    this.minOrder = '١٠ م²',
    this.leadTime = '٣ أيام',
    this.origin = 'مصر',
    this.certification = 'ISO 9001',
    this.imageUrl = '',
    this.price = '',
  });
}
