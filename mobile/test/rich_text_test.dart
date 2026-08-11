import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memo_mobile/services/rich_text.dart';

void main() {
  test('parseRich：加粗/下划线/标签', () {
    final lines = parseRich('普通 **加粗** <u>下划线</u> #标签');
    expect(lines.length, 1);
    final spans = lines.first.spans;
    expect(spans.any((s) => s.bold), isTrue);
    expect(spans.any((s) => s.underline), isTrue);
    expect(spans.any((s) => s.type == SpanType.tag), isTrue);
  });

  test('parseRich：嵌套加粗+下划线', () {
    final lines = parseRich('**<u>重点</u>**');
    final spans = lines.first.spans;
    expect(spans.length, 1);
    expect(spans.first.bold, isTrue);
    expect(spans.first.underline, isTrue);
    expect(spans.first.text, '重点');
  });

  test('parseRich：无序/有序列表与缩进', () {
    final lines = parseRich('- 条目一\n    1. 子项\n普通行');
    expect(lines[0].list, 'ul');
    expect(lines[0].spans.first.text, '条目一');
    expect(lines[1].list, 'ol');
    expect(lines[1].indent, 1);
    expect(lines[2].list, isNull);
    expect(lines[2].indent, 0);
  });

  test('applyFormat：bold 包裹选区', () {
    final c = TextEditingController(text: 'hello world');
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    applyFormat(c, FormatKind.bold);
    expect(c.text, '**hello** world');
    c.dispose();
  });

  test('applyFormat：无序列表切换', () {
    final c = TextEditingController(text: '甲\n乙\n丙');
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 3); // 覆盖前两行
    applyFormat(c, FormatKind.ul);
    expect(c.text, '- 甲\n- 乙\n丙');
    // 再次应用取消列表
    applyFormat(c, FormatKind.ul);
    expect(c.text, '甲\n乙\n丙');
    c.dispose();
  });

  test('applyFormat：有序列表编号递增', () {
    final c = TextEditingController(text: '一\n二\n三');
    c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    applyFormat(c, FormatKind.ol);
    expect(c.text, '1. 一\n2. 二\n三');
    c.dispose();
  });

  test('applyFormat：缩进/反缩进', () {
    final c = TextEditingController(text: 'text');
    applyFormat(c, FormatKind.indent);
    expect(c.text, '    text');
    applyFormat(c, FormatKind.outdent);
    expect(c.text, 'text');
    c.dispose();
  });

  test('richToSpan：无异常渲染', () {
    final span = richToSpan('**粗** <u>划</u> #标\n- 项');
    expect(span.children, isNotEmpty);
  });
}
