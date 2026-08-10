/// 坚果云 WebDAV 传输（dav.jianguoyun.com）
/// 认证：账号 + 应用密码（坚果云网页端「安全设置」生成，非登录密码）
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_engine.dart';

class WebDavTransport implements SyncTransport {
  final String baseUrl; // 如 https://dav.jianguoyun.com/dav/memo-sync
  final String username;
  final String password;

  WebDavTransport({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  String get _base =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  static String _trim(String s) => s.length > 200 ? s.substring(0, 200) : s;

  @override
  Future<void> upload(String fileName, String content) async {
    final uri = Uri.parse('$_base/$fileName');
    final resp = await http.put(uri, headers: _headers, body: content);
    if (resp.statusCode >= 300) {
      throw Exception('上传失败 ${resp.statusCode}: ${_trim(resp.body)}');
    }
  }

  @override
  Future<String?> download(String fileName) async {
    final uri = Uri.parse('$_base/$fileName');
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode == 404 || resp.statusCode == 405) return null;
    if (resp.statusCode >= 300) {
      throw Exception('下载失败 ${resp.statusCode}: ${_trim(resp.body)}');
    }
    return resp.body;
  }
}
