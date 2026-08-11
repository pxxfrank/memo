import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'theme.dart';

/// WYSIWYG 格式工具栏：操作 QuillController 选区，所见即所得
class QuillFormatToolbar extends StatelessWidget {
  final QuillController controller;
  const QuillFormatToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final btn = (IconData icon, String tip, Attribute attr) => IconButton(
          tooltip: tip,
          icon: Icon(icon, size: 16, color: AppColors.sub),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => controller.formatSelection(attr),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.format_bold, '加粗', Attribute.bold),
      btn(Icons.format_underlined, '下划线', Attribute.underline),
      btn(Icons.format_list_bulleted, '无序列表', Attribute.ul),
      btn(Icons.format_list_numbered, '有序列表', Attribute.ol),
      btn(Icons.format_indent_increase, '右缩进', Attribute.indentL1),
      btn(Icons.format_indent_decrease, '左缩进', const IndentAttribute(level: 0)),
    ]);
  }
}
