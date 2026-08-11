import 'package:flutter_test/flutter_test.dart';

import 'package:memo_mobile/services/rich_delta.dart';

void main() {
  String roundtrip(String md) => deltaToMd(mdToDelta(md));

  test('往返：加粗/下划线/标签', () {
    expect(roundtrip('普通 **加粗** <u>下划线</u> #标签'), '普通 **加粗** <u>下划线</u> #标签');
  });

  test('往返：嵌套加粗+下划线', () {
    expect(roundtrip('**<u>重点</u>**'), '**<u>重点</u>**');
  });

  test('往返：无序/有序列表与缩进', () {
    const md = '- 条目一\n    1. 子项\n普通行';
    expect(roundtrip(md), md);
  });

  test('往返：多段不同样式', () {
    const md = '第一段 **粗**\n第二段 <u>划</u> 和 #标签';
    expect(roundtrip(md), md);
  });

  test('mdToDelta：bold 属性正确', () {
    final delta = mdToDelta('**粗** 文本');
    final ops = delta.toList();
    expect(ops.any((o) => o.attributes?['bold'] == true), isTrue);
  });

  test('deltaToMd：列表标记还原', () {
    final delta = mdToDelta('- a\n- b');
    expect(deltaToMd(delta), '- a\n- b');
  });
}
