import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database.dart';
import '../models/memo.dart';
import '../services/rich_text.dart';
import 'format_toolbar.dart';
import 'memo_card.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _composer = TextEditingController();
  final _focus = FocusNode();
  List<Memo> _memos = [];
  List<Map<String, Object?>> _tags = [];
  String? _activeTag;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final memos = await MemoDb.list(tag: _activeTag);
      final tags = await MemoDb.tags();
      if (!mounted) return;
      setState(() {
        _memos = memos;
        _tags = tags;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);  // 存储不可用时降级为空态，不卡加载
    }
  }

  Future<void> _submit() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    await MemoDb.create(text);
    _composer.clear();
    _focus.requestFocus();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MEMO'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Text('本地私有 · 云同步',
                  style: TextStyle(color: AppColors.faint, fontSize: 11)),
            ),
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              _buildComposer(),
              _buildTagBar(),
              const SizedBox(height: 6),
              Expanded(child: _buildTimeline()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: TextField(
              controller: _composer,
              focusNode: _focus,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.5),
              decoration: const InputDecoration(
                hintText: '现在的想法是……',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                FormatToolbar(onFormat: (kind) {
                  applyFormat(_composer, kind);
                  setState(() {});
                }),
                const Spacer(),
                Text(
                  'Ctrl+Enter 发送',
                  style: TextStyle(fontSize: 10.5, color: AppColors.faint.withValues(alpha: 0.8)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _composer.text.trim().isEmpty ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    disabledBackgroundColor: AppColors.green.withValues(alpha: 0.35),
                  ),
                  child: const Text('发送'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagBar() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          _tagChip(null, '全部'),
          for (final t in _tags) _tagChip(t['name'] as String, '${t['name']} ${t['count']}'),
        ],
      ),
    );
  }

  Widget _tagChip(String? name, String label) {
    final active = _activeTag == name;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.greendark : AppColors.sub)),
        selected: active,
        onSelected: (_) async {
          setState(() => _activeTag = name);
          await _reload();
        },
        selectedColor: AppColors.tagbg,
        backgroundColor: AppColors.sidebar,
        side: BorderSide(color: active ? AppColors.green.withValues(alpha: 0.4) : AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green));
    }
    if (_memos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notes, size: 40, color: AppColors.faint),
            const SizedBox(height: 10),
            Text(
              _activeTag == null ? '还没有笔记，写下第一条吧' : '该标签下没有笔记',
              style: const TextStyle(color: AppColors.faint, fontSize: 13.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
      itemCount: _memos.length,
      itemBuilder: (ctx, i) => MemoCard(memo: _memos[i], onChanged: _reload),
    );
  }
}
