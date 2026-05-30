class SadhanaRecord {
  final String dateString; // YYYY-MM-DD
  final int meditationMinutes;
  final int versesRead;
  final int chantingRounds;
  final int streakCount;

  const SadhanaRecord({
    required this.dateString,
    required this.meditationMinutes,
    required this.versesRead,
    required this.chantingRounds,
    required this.streakCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'dateString': dateString,
      'meditationMinutes': meditationMinutes,
      'versesRead': versesRead,
      'chantingRounds': chantingRounds,
      'streakCount': streakCount,
    };
  }

  factory SadhanaRecord.fromJson(Map<String, dynamic> json) {
    return SadhanaRecord(
      dateString: json['dateString'] as String,
      meditationMinutes: json['meditationMinutes'] as int,
      versesRead: json['versesRead'] as int,
      chantingRounds: json['chantingRounds'] as int,
      streakCount: json['streakCount'] as int,
    );
  }
}
