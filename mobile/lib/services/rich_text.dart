/// 富文本（Markdown 子集）解析与格式操作（与桌面端 flomo/src/lib/rich.ts 同规则）
/// 加粗 **x**、下划线 <u>x</u>、#标签、行首缩进（4 空格=1 级）、
/// 无序列表 "- "、有序列表 "1. "；存储为纯文本，渲染端解析显示。
/// span 为组合式（bold/underline 可同时为 true，支持 **<u>x</u>** 嵌套）。
library;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

enum SpanType { text, tag }

class RichSpan {
  final SpanType type;
  final String text;
  final bool bold;
  final bool underline;
  final String? tag;
  const RichSpan(this.type, this.text, {this.bold = false, this.underline = false, this.tag});
  const RichSpan.text(String text, {bool bold = false, bool underline = false})
      : this(SpanType.text, text, bold: bold, underline: underline);
  const RichSpan.tag(String text) : this(SpanType.tag, text);
}

class RichLine {
  final int indent;
  final String? list; // 'ul' | 'ol' | null
  final List<RichSpan> spans;
  const RichLine(this.indent, this.list, this.spans);
}

final _ulRe = RegExp(r'^[-*] (.*)$');
final _olRe = RegExp(r'^\d+[.)] (.*)$');

List<RichLine> parseRich(String content) {
  return content.split('\n').map((line) {
    final lead = line.indexOf(RegExp(r'[^ ]'));
    final spaceLen = lead == -1 ? line.length : lead;
    final rest = line.substring(spaceLen);
    String? list;
    var text = rest;
    final ul = _ulRe.firstMatch(rest);
    final ol = _olRe.firstMatch(rest);
    if (ul != null) {
      list = 'ul';
      text = ul.group(1)!;
    } else if (ol != null) {
      list = 'ol';
      text = ol.group(1)!;
    }
    return RichLine(spaceLen ~/ 4, list, parseInline(text));
  }).toList();
}

final _inlineRe = RegExp(
    r'(\*\*[^*]+\*\*|<u>[\s\S]*?</u>|#[^\s#，。！？!?,;；:："“”‘’（）()【】\[\]<>《》]+)');

/// 递归解析行内标记：**x**、<u>x</u> 可嵌套，生成组合式 span
List<RichSpan> parseInline(String text, {bool bold = false, bool underline = false}) {
  final spans = <RichSpan>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) {
      spans.add(RichSpan.text(text.substring(last, m.start), bold: bold, underline: underline));
    }
    final token = m.group(0)!;
    if (token.startsWith('**')) {
      spans.addAll(parseInline(token.substring(2, token.length - 2), bold: true, underline: underline));
    } else if (token.startsWith('<u>')) {
      spans.addAll(parseInline(token.substring(3, token.length - 4), bold: bold, underline: true));
    } else if (token.startsWith('#')) {
      spans.add(RichSpan.tag(token));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(RichSpan.text(text.substring(last), bold: bold, underline: underline));
  }
  return spans;
}

/// 渲染为 TextSpan（含缩进/列表标记，行内加粗/下划线/标签高亮）
TextSpan richToSpan(String content, {TextStyle? baseStyle}) {
  final base = baseStyle ??
      TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.65);
  final children = <TextSpan>[];
  final lines = parseRich(content);
  var ol = 0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.indent > 0) {
      children.add(TextSpan(text: ' ' * (l.indent * 4)));
    }
    if (l.list == 'ul') {
      children.add(const TextSpan(text: '• '));
    } else if (l.list == 'ol') {
      ol++;
      children.add(TextSpan(text: '$ol. '));
    } else {
      ol = 0;
    }
    for (final s in l.spans) {
      if (s.type == SpanType.tag) {
        children.add(TextSpan(
            text: s.text,
            style: TextStyle(
                color: AppColors.greendark, fontWeight: FontWeight.w600)));
      } else {
        TextStyle? style;
        if (s.bold) {
          style = TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink);
        }
        if (s.underline) {
          final base2 = style ?? TextStyle(color: AppColors.ink);
          style = base2.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: const Color(0x8034996B),
              decorationThickness: 1.2);
        }
        children.add(TextSpan(text: s.text, style: style));
      }
    }
    if (i < lines.length - 1) {
      children.add(const TextSpan(text: '\n'));
    }
  }
  return TextSpan(style: base, children: children);
}

enum FormatKind { bold, underline, ul, ol, indent, outdent }

/// 对 TextEditingController 选区应用格式（纯文本模式用）
void applyFormat(TextEditingController c, FormatKind kind) {
  final value = c.text;
  final s = c.selection.isValid ? c.selection.start : value.length;
  final e = c.selection.isValid ? c.selection.end : value.length;
  final sel = value.substring(s, e);

  if (kind == FormatKind.bold) {
    final marker = sel.isEmpty ? '**' : '**$sel**';
    c.text = value.replaceRange(s, e, marker);
    c.selection = TextSelection.collapsed(offset: s + 2);
    return;
  }
  if (kind == FormatKind.underline) {
    final marker = sel.isEmpty ? '<u></u>' : '<u>$sel</u>';
    c.text = value.replaceRange(s, e, marker);
    c.selection = TextSelection.collapsed(offset: s + 3);
    return;
  }
  // 行级操作：选区覆盖的完整行
  final lineStart = s == 0 ? 0 : value.lastIndexOf('\n', s - 1) + 1;
  final lineEndIdx = value.indexOf('\n', e);
  final end = lineEndIdx == -1 ? value.length : lineEndIdx;
  final lines = value.substring(lineStart, end).split('\n');
  final processed = List.generate(lines.length, (i) {
    final ln = lines[i];
    switch (kind) {
      case FormatKind.ul:
        return RegExp(r'^\s*[-*] ').hasMatch(ln)
            ? ln.replaceFirst(RegExp(r'^\s*[-*] '), '')
            : '- $ln';
      case FormatKind.ol:
        return RegExp(r'^\s*\d+[.)] ').hasMatch(ln)
            ? ln.replaceFirst(RegExp(r'^\s*\d+[.)] '), '')
            : '${i + 1}. $ln';
      case FormatKind.indent:
        return '    $ln';
      case FormatKind.outdent:
        return ln.startsWith('    ') ? ln.substring(4) : ln;
      default:
        return ln;
    }
  });
  final joined = processed.join('\n');
  c.text = value.replaceRange(lineStart, end, joined);
  c.selection = TextSelection(baseOffset: lineStart, extentOffset: lineStart + joined.length);
}
