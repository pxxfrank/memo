import 'dart:math';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../models/memo.dart';
import '../services/app_settings.dart';
import '../services/rich_text.dart';
import 'theme.dart';

/// 每日回顾：历史优先，随机翻出 N 条
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<Memo>? _cards;

  String _dayLabel(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final startOf = (DateTime x) => DateTime(x.year, x.month, x.day);
    final diff = startOf(now).difference(startOf(d)).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${d.month}月${d.day}日';
  }

  Future<void> _pick() async {
    final all = await MemoDb.list();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pool = all.where((m) => m.createdAt < now - 86400000).toList();
    final src = pool.isNotEmpty ? pool : all;
    final n = min(AppSettings.reviewCount, src.length);
    final picked = [...src]..shuffle(Random());
    if (!mounted) return;
    setState(() => _cards = picked.take(n).toList());
  }

  @override
  void initState() {
    super.initState();
    _pick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每日回顾')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text('随机翻出过去的笔记，让记忆重新浮现',
                    style: TextStyle(color: AppColors.faint, fontSize: 12)),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('再抽一组'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_cards == null) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green));
    }
    if (_cards!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 34)),
            const SizedBox(height: 8),
            const Text('还没有可回顾的笔记，先去记几条吧',
                style: TextStyle(color: AppColors.faint, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      itemCount: _cards!.length,
      itemBuilder: (ctx, i) {
        final m = _cards![i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(richToSpan(m.content,
                  baseStyle:
                      const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.8))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('📅 ${_dayLabel(m.createdAt)}',
                      style: const TextStyle(color: AppColors.faint, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(
                    '${DateTime.fromMillisecondsSinceEpoch(m.createdAt).hour.toString().padLeft(2, '0')}:'
                    '${DateTime.fromMillisecondsSinceEpoch(m.createdAt).minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.faint, fontSize: 11),
                  ),
                  if (m.pinned) ...[
                    const SizedBox(width: 8),
                    const Text('📌 置顶', style: TextStyle(color: AppColors.pin, fontSize: 11)),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
