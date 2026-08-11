import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/memo.dart';
import '../services/rich_text.dart';
import 'format_toolbar.dart';
import 'theme.dart';

class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onChanged;

  const MemoCard({super.key, required this.memo, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: memo.content);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('编辑笔记'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 6,
                minLines: 2,
                decoration: const InputDecoration(
                  hintText: '修改内容……',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FormatToolbar(onFormat: (kind) {
                applyFormat(ctrl, kind);
                setDialogState(() {});
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (text != null && text.isNotEmpty && text != memo.content) {
      await MemoDb.update(memo.id!, text);
      onChanged();
    }
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: memo.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = memo.pinned ? AppColors.pin.withValues(alpha: 0.45) : AppColors.line;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: richToSpan(memo.content),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatTime(memo.createdAt),
                style: TextStyle(color: AppColors.faint, fontSize: 11),
              ),
              if (memo.pinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin, size: 11, color: AppColors.pin),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 16,
                color: AppColors.card,
                onSelected: (v) async {
                  switch (v) {
                    case 'edit':
                      await _edit(context);
                    case 'pin':
                      await MemoDb.setPinned(memo.id!, !memo.pinned);
                      onChanged();
                    case 'copy':
                      _copy(context);
                    case 'delete':
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除这条笔记？'),
                          content: Text(memo.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await MemoDb.remove(memo.id!);
                        onChanged();
                      }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'edit', child: Row(children: const [
                    Icon(Icons.edit_outlined, size: 17), SizedBox(width: 8), Text('编辑'),
                  ])),
                  PopupMenuItem(value: 'pin', child: Row(children: [
                    Icon(memo.pinned ? Icons.push_pin_outlined : Icons.push_pin, size: 17,
                        color: memo.pinned ? AppColors.pin : null),
                    const SizedBox(width: 8), Text(memo.pinned ? '取消置顶' : '置顶'),
                  ])),
                  const PopupMenuItem(value: 'copy', child: Row(children: [
                    Icon(Icons.copy_outlined, size: 17), SizedBox(width: 8), Text('复制'),
                  ])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [
                    Icon(Icons.delete_outline, size: 17, color: Colors.red), SizedBox(width: 8),
                    Text('删除', style: TextStyle(color: Colors.red)),
                  ])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
