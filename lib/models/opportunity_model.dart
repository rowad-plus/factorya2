enum OppType { tender, partnership, export, investment, agency }

class OpportunityModel {
  final String id;
  final String title;
  final OppType type;
  final String typeLabel;
  final String emoji;
  final String bgColor;
  final String city;
  final String location;
  final String budget;
  final String deadline;
  final String company;
  final int applicants;
  final String description;
  final String postedAgo;
  final String imageUrl;

  const OpportunityModel({
    required this.id,
    required this.title,
    required this.type,
    required this.typeLabel,
    required this.emoji,
    required this.bgColor,
    required this.city,
    this.location = '',
    required this.budget,
    required this.deadline,
    required this.company,
    this.applicants = 0,
    this.description = '',
    this.postedAgo = '',
    this.imageUrl = '',
  });
}
