/// Markdown 子集 ↔ Quill Delta 双向转换（WYSIWYG 编辑器 flutter_quill 用）
/// 存储始终为 Markdown 子集（与桌面端一致），编辑时转 Delta、保存时转回。
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'rich_text.dart';

/// Markdown → Delta（初始化编辑器）
Delta mdToDelta(String content) {
  final ops = <Operation>[];
  for (final line in parseRich(content)) {
    // 行内 spans → 连续 op（合并相邻相同样式段）
    final lineOps = <Operation>[];
    String? curText;
    Map<String, dynamic>? curAttr;
    void flush() {
      if (curText != null) {
        lineOps.add(Operation.insert(curText!, curAttr));
        curText = null;
        curAttr = null;
      }
    }

    for (final s in line.spans) {
      final attrs = <String, dynamic>{};
      if (s.bold) attrs['bold'] = true;
      if (s.underline) attrs['underline'] = true;
      final attrMap = attrs.isEmpty ? null : attrs;
      if (curText != null && _sameStyle(curAttr, attrMap)) {
        curText = curText! + s.text;
      } else {
        flush();
        curText = s.text;
        curAttr = attrMap;
      }
    }
    flush();

    // 块级属性（list/indent）附加到行内最后一个文本 op
    if (lineOps.isNotEmpty) {
      final last = lineOps.removeLast();
      final blockAttrs = <String, dynamic>{...?last.attributes};
      if (line.list == 'ul') blockAttrs['list'] = 'bullet';
      if (line.list == 'ol') blockAttrs['list'] = 'ordered';
      if (line.indent > 0) blockAttrs['indent'] = line.indent;
      ops.addAll(lineOps);
      ops.add(Operation.insert(last.data, blockAttrs.isEmpty ? null : blockAttrs));
    }
    ops.add(Operation.insert('\n'));
  }
  return Delta.fromOperations(ops);
}

bool _sameStyle(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return a['bold'] == b['bold'] && a['underline'] == b['underline'];
}

/// Delta → Markdown（保存时提取）
String deltaToMd(Delta delta) {
  final lines = <String>[];
  final buf = <String>[];
  String? list;
  var indent = 0;
  bool hasContent = false;

  void flushLine() {
    if (hasContent || list != null) {
      final text = buf.join();
      final lead = '    ' * indent;
      lines.add(list == null
          ? lead + text
          : '$lead${list == 'ul' ? '- ' : '1. '}$text');
    }
    buf.clear();
    list = null;
    indent = 0;
    hasContent = false;
  }

  for (final op in delta.toList()) {
    final attrs = op.attributes ?? <String, dynamic>{};
    if (attrs.containsKey('list')) {
      list = attrs['list'] == 'ordered' ? 'ol' : 'ul';
    }
    if (attrs['indent'] is num) {
      indent = (attrs['indent'] as num).toInt();
    }
    final text = op.data is String ? op.data as String : '';
    final bold = attrs['bold'] == true;
    final underline = attrs['underline'] == true;
    // 按 \n 切分处理行
    final parts = text.split('\n');
    for (var p = 0; p < parts.length; p++) {
      if (p > 0) flushLine();
      final seg = parts[p];
      if (seg.isNotEmpty) {
        hasContent = true;
        var s = seg;
        if (underline) s = '<u>$s</u>';
        if (bold) s = '**$s**';
        buf.add(s);
      }
    }
  }
  if (hasContent || buf.isNotEmpty || list != null) flushLine();
  return lines.join('\n').trim();
}
