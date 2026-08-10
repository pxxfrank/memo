/// 标签解析（与桌面端 sync.py / service.py 的 parse_tags 规则一致）
/// #标签、#父/子 多级标签
library;

final RegExp _tagRe = RegExp(
  r'#([^\s#，。！？!?,;；:："“”‘’（）()【】\[\]<>《》]+)',
);
final RegExp _stripRe = RegExp(r'^[^\w\u4e00-\u9fff]+|[^\w\u4e00-\u9fff]+$');

/// 从内容中提取标签集合（含多级：`#父/子` 产生 `#父` 与 `#父/子`）
Set<String> parseTags(String content) {
  final tags = <String>{};
  for (final m in _tagRe.allMatches(content)) {
    var raw = m.group(1) ?? '';
    raw = raw.replaceAll(_stripRe, '');
    final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) continue;
    final path = <String>[];
    for (final p in parts) {
      path.add(p);
      tags.add(path.join('/'));
    }
  }
  return tags;
}

/// 把内容按标签拆成可高亮渲染的片段列表
List<({String text, bool isTag})> splitHighlight(String content) {
  final out = <({String text, bool isTag})>[];
  var last = 0;
  for (final m in _tagRe.allMatches(content)) {
    if (m.start > last) {
      out.add((text: content.substring(last, m.start), isTag: false));
    }
    out.add((text: m.group(0)!, isTag: true));
    last = m.end;
  }
  if (last < content.length) {
    out.add((text: content.substring(last), isTag: false));
  }
  return out;
}
