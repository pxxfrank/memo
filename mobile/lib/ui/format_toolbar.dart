import 'package:flutter/material.dart';

import '../services/rich_text.dart';
import 'theme.dart';

/// 富文本格式工具栏（加粗/下划线/无序/有序/右缩进/左缩进）
class FormatToolbar extends StatelessWidget {
  final void Function(FormatKind kind) onFormat;
  const FormatToolbar({super.key, required this.onFormat});

  @override
  Widget build(BuildContext context) {
    final btn = (IconData icon, String tip, FormatKind kind) => IconButton(
          tooltip: tip,
          icon: Icon(icon, size: 16, color: AppColors.sub),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => onFormat(kind),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.format_bold, '加粗', FormatKind.bold),
      btn(Icons.format_underlined, '下划线', FormatKind.underline),
      btn(Icons.format_list_bulleted, '无序列表', FormatKind.ul),
      btn(Icons.format_list_numbered, '有序列表', FormatKind.ol),
      btn(Icons.format_indent_increase, '右缩进', FormatKind.indent),
      btn(Icons.format_indent_decrease, '左缩进', FormatKind.outdent),
    ]);
  }
}
