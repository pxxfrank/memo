/// 富文本（Markdown 子集）解析与格式操作（与桌面端 flomo/src/lib/rich.ts 同规则）
/// 加粗 **x**、下划线 <u>x</u>、#标签、行首缩进（4 空格=1 级）、
/// 无序列表 "- "、有序列表 "1. "；存储为纯文本，渲染端解析显示。
library;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

enum SpanType { bold, underline, tag, text }

class RichSpan {
  final SpanType type;
  final String text;
  const RichSpan(this.type, this.text);
}

class RichLine {
  final int indent;
  final String? list; // 'ul' | 'ol' | null
  final List<RichSpan> spans;
  const RichLine(this.indent, this.list, this.spans);
}

final _inlineRe = RegExp(
    r'(\*\*[^*]+\*\*|<u>[^<]+</u>|#[^\s#，。！？!?,;；:："“”‘’（）()【】\[\]<>《》]+)');
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

List<RichSpan> parseInline(String text) {
  final spans = <RichSpan>[];
  var last = 0;
  for (final m in _inlineRe.allMatches(text)) {
    if (m.start > last) spans.add(RichSpan(SpanType.text, text.substring(last, m.start)));
    final token = m.group(0)!;
    if (token.startsWith('**')) {
      spans.add(RichSpan(SpanType.bold, token.substring(2, token.length - 2)));
    } else if (token.startsWith('<u>')) {
      spans.add(RichSpan(SpanType.underline, token.substring(3, token.length - 4)));
    } else if (token.startsWith('#')) {
      spans.add(RichSpan(SpanType.tag, token));
    }
    last = m.end;
  }
  if (last < text.length) spans.add(RichSpan(SpanType.text, text.substring(last)));
  return spans;
}

/// 渲染为 TextSpan（含缩进/列表标记，行内加粗/下划线/标签高亮）
TextSpan richToSpan(String content, {TextStyle? baseStyle}) {
  final base = baseStyle ??
      const TextStyle(color: AppColors.ink, fontSize: 14.5, height: 1.65);
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
      switch (s.type) {
        case SpanType.bold:
          children.add(TextSpan(
              text: s.text,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)));
        case SpanType.underline:
          children.add(TextSpan(
              text: s.text,
              style: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0x8034996B),
                  decorationThickness: 1.2)));
        case SpanType.tag:
          children.add(TextSpan(
              text: s.text,
              style: const TextStyle(
                  color: AppColors.greendark, fontWeight: FontWeight.w600)));
        case SpanType.text:
          children.add(TextSpan(text: s.text));
      }
    }
    if (i < lines.length - 1) {
      children.add(const TextSpan(text: '\n'));
    }
  }
  return TextSpan(style: base, children: children);
}

enum FormatKind { bold, underline, ul, ol, indent, outdent }

/// 对 TextEditingController 选区应用格式
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
