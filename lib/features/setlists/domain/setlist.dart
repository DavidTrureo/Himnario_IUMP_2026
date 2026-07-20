class Setlist {
  final String id;
  final String title;
  final String date;
  final List<String> hymnIds;

  const Setlist({
    required this.id,
    required this.title,
    required this.date,
    required this.hymnIds,
  });

  factory Setlist.fromJson(Map<String, dynamic> json, String id) {
    return Setlist(
      id: id.isNotEmpty ? id : (json['id'] ?? ''),
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      hymnIds: List<String>.from(json['hymnIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'hymnIds': hymnIds,
    };
  }
}
