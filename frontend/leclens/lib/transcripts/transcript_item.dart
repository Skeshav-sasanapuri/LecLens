class TranscriptItem {
  final String time;
  final String content;

  TranscriptItem({
    required this.time,
    required this.content,
  });

  factory TranscriptItem.fromJson(Map<String, dynamic> json) {
    return TranscriptItem(
      time: json['time'] as String,
      content: json['content'] as String,
    );
  }
}
