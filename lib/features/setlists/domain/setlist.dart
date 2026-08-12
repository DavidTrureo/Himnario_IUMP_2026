class Setlist {
  final String id;
  final String title;
  final String date;
  final List<String> hymnIds;
  final String leader;
  final String pianist;
  final String rosterInfo;

  const Setlist({
    required this.id,
    required this.title,
    required this.date,
    required this.hymnIds,
    this.leader = '',
    this.pianist = '',
    this.rosterInfo = '',
  });

  factory Setlist.fromJson(Map<String, dynamic> json, String id) {
    return Setlist(
      id: id.isNotEmpty ? id : (json['id'] ?? ''),
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      hymnIds: List<String>.from(json['hymnIds'] ?? []),
      leader: json['leader'] ?? '',
      pianist: json['pianist'] ?? '',
      rosterInfo: json['rosterInfo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'hymnIds': hymnIds,
      'leader': leader,
      'pianist': pianist,
      'rosterInfo': rosterInfo,
    };
  }

  Setlist copyWith({
    String? id,
    String? title,
    String? date,
    List<String>? hymnIds,
    String? leader,
    String? pianist,
    String? rosterInfo,
  }) {
    return Setlist(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      hymnIds: hymnIds ?? this.hymnIds,
      leader: leader ?? this.leader,
      pianist: pianist ?? this.pianist,
      rosterInfo: rosterInfo ?? this.rosterInfo,
    );
  }
}
