/// MEMO 笔记模型（与桌面端 memos 表字段一致）
class Memo {
  final int? id;
  final String uuid;
  final String content;
  final int createdAt;
  final int? updatedAt;
  final bool pinned;
  final List<String> tags;

  const Memo({
    this.id,
    required this.uuid,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.pinned,
    this.tags = const [],
  });

  factory Memo.fromMap(Map<String, dynamic> m) {
    return Memo(
      id: m['id'] as int?,
      uuid: m['uuid'] as String? ?? '',
      content: (m['content'] as String?) ?? '',
      createdAt: (m['created_at'] as int?) ?? 0,
      updatedAt: m['updated_at'] as int?,
      pinned: (m['pinned'] as int? ?? 0) != 0,
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  Memo copyWith({String? content, bool? pinned, int? updatedAt, List<String>? tags}) {
    return Memo(
      id: id,
      uuid: uuid,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinned: pinned ?? this.pinned,
      tags: tags ?? this.tags,
    );
  }
}

/// 相对时间：今天 HH:mm / 昨天 / N 天前 / YYYY-MM-DD
String formatTime(int ts) {
  final t = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  String hhmm() => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return hhmm();
  if (diff == 1) return '昨天';
  if (diff < 7) return '$diff 天前';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
