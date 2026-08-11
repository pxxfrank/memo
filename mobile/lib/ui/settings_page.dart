import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/sync_controller.dart';
import 'theme.dart';
class SettingsPage extends StatefulWidget {
  /// tab 模式下隐藏返回按钮
  final bool showBack;
  const SettingsPage({super.key, this.showBack = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _url = TextEditingController(text: AppSettings.webdavUrl);
  late final TextEditingController _user = TextEditingController(text: AppSettings.username);
  late final TextEditingController _pass = TextEditingController(text: AppSettings.appPassword);
  late final TextEditingController _phrase = TextEditingController(text: AppSettings.passphrase);
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = SyncController.lastResult;
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    AppSettings.webdavUrl = _url.text.trim();
    AppSettings.username = _user.text.trim();
    AppSettings.appPassword = _pass.text.trim();
    AppSettings.passphrase = _phrase.text.trim();
    await AppSettings.saveAll();
    await SyncController.apply();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = SyncController.lastResult;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppSettings.syncConfigured ? '已保存并启用云同步' : '已关闭云同步')),
    );
  }

  Future<void> _syncNow() async {
    await SyncController.syncNow();
    if (!mounted) return;
    setState(() => _status = SyncController.lastResult);
  }

  @override
  Widget build(BuildContext context) {
    final inputCls = InputDecoration(
      hintStyle: TextStyle(color: AppColors.faint, fontSize: 13),
      labelStyle: TextStyle(color: AppColors.sub, fontSize: 12),
    );
    final label = (String t) => Text(t,
        style: TextStyle(color: AppColors.faint, fontSize: 11.5, fontWeight: FontWeight.w500));

    return Scaffold(
      appBar: AppBar(
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text('云同步（坚果云）',
              style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            '手机与桌面各自本地编辑，经坚果云交换加密变更日志实现双向同步。'
            '远程目录填坚果云 WebDAV 地址，如 https://dav.jianguoyun.com/dav/memo-sync。',
            style: TextStyle(color: AppColors.faint, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('远程目录（WebDAV）'),
                const SizedBox(height: 6),
                TextField(controller: _url, decoration: inputCls, keyboardType: TextInputType.url),
                const SizedBox(height: 12),
                label('坚果云账号'),
                const SizedBox(height: 6),
                TextField(controller: _user, decoration: inputCls),
                const SizedBox(height: 12),
                label('应用密码（坚果云网页端"安全设置"生成）'),
                const SizedBox(height: 6),
                TextField(controller: _pass, decoration: inputCls, obscureText: true),
                const SizedBox(height: 12),
                label('同步口令（端到端加密，各设备须一致；留空不加密）'),
                const SizedBox(height: 6),
                TextField(controller: _phrase, decoration: inputCls, obscureText: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _save,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.greendark,
                          side: BorderSide(color: AppColors.line),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: Text(_saving ? '保存中…' : '保存配置'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: SyncController.configured ? _syncNow : null,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                        child: const Text('立即同步'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _status ?? (SyncController.configured ? '已启用（每 15 秒自动同步）' : '未配置同步'),
              style: TextStyle(color: AppColors.sub, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
          Text('每日回顾',
              style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Text('每次抽取条数',
                    style: TextStyle(color: AppColors.sub, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, size: 20, color: AppColors.sub),
                  onPressed: () async {
                    if (AppSettings.reviewCount > 1) {
                      AppSettings.reviewCount--;
                      await AppSettings.saveAll();
                      setState(() {});
                    }
                  },
                ),
                Text('${AppSettings.reviewCount}',
                    style: TextStyle(
                        color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, size: 20, color: AppColors.green),
                  onPressed: () async {
                    if (AppSettings.reviewCount < 10) {
                      AppSettings.reviewCount++;
                      await AppSettings.saveAll();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('外观',
              style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Text('暗黑模式',
                    style: TextStyle(color: AppColors.sub, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: AppSettings.themeDark,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) async {
                    AppSettings.themeDark = v;
                    await AppSettings.saveAll();
                    AppTheme.apply(v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('关于',
              style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('MEMO 手机端 · Flutter 版\n数据存储于本机，云端仅交换加密日志。',
              style: TextStyle(color: AppColors.faint, fontSize: 12, height: 1.6)),
        ],
      ),
    );
  }
}
