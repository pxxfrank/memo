import 'package:flutter/material.dart';

import '../db/database.dart';
import 'theme.dart';

/// 统计页：总量/周期/字数/置顶/标签排行
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Map<String, Object?>? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await MemoDb.stats();
    if (!mounted) return;
    setState(() => _s = s);
  }

  Widget _metric(String label, String value, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: color ?? AppColors.greendark)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: AppColors.faint, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: s == null
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Row(children: [
                  _metric('全部笔记', '${s['total']}'),
                  const SizedBox(width: 10),
                  _metric('近 7 天', '${s['week']}'),
                  const SizedBox(width: 10),
                  _metric('近 30 天', '${s['month']}'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _metric('累计字数', '${s['chars']}', color: AppColors.ink),
                  const SizedBox(width: 10),
                  _metric('置顶', '${s['pinned']}', color: AppColors.pin),
                  const SizedBox(width: 10),
                  _metric('标签', '${(s['topTags'] as List).length}'),
                ]),
                const SizedBox(height: 20),
                Text('标签排行',
                    style: TextStyle(
                        color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: (s['topTags'] as List).isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('还没有标签，记笔记时用 #标签 即可',
                                  style: TextStyle(color: AppColors.faint, fontSize: 12)),
                            ),
                          ]
                        : (s['topTags'] as List)
                            .map<Widget>((t) {
                              final name = (t as Map)['name'] as String;
                              final count = (t['count'] as num).toInt();
                              final max = ((s['topTags'] as List).first as Map)['count'] as num;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      child: Text('#$name',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: AppColors.ink, fontSize: 13)),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: count / max.toDouble(),
                                          minHeight: 6,
                                          backgroundColor: AppColors.tagbg,
                                          color: AppColors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('$count',
                                        style: TextStyle(
                                            color: AppColors.sub, fontSize: 12)),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
