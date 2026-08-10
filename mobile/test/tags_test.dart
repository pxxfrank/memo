import 'package:flutter_test/flutter_test.dart';

import 'package:memo_mobile/models/memo.dart';
import 'package:memo_mobile/services/tags.dart';

void main() {
  test('parse_tags：单级标签', () {
    final s = parseTags('今天跑步 #运动 记一下 #生活');
    expect(s, containsAll(['运动', '生活']));
  });

  test('parse_tags：多级标签产生父级', () {
    final s = parseTags('笔记 #工作/项目/汇报');
    expect(s, containsAll(['工作', '工作/项目', '工作/项目/汇报']));
  });

  test('parse_tags：中文标点截断', () {
    final s = parseTags('#标签。继续 #另一#标签');
    expect(s, contains('标签'));
    expect(s, isNot(contains('标签。继续')));
  });

  test('splitHighlight 拆分正确', () {
    final parts = splitHighlight('前缀 #tag1 中间 #tag2');
    expect(parts.map((p) => p.text).join(), '前缀 #tag1 中间 #tag2');
    expect(parts.where((p) => p.isTag).length, 2);
  });

  test('formatTime 相对时间', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect(formatTime(now), contains(':'));
  });
}
