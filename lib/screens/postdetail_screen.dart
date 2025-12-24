// lib/screens/post_detail.dart
import 'dart:convert';

import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class PostDetail extends StatefulWidget {
  const PostDetail({super.key});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  late final Dio dio;

  late Future<Map<String, dynamic>> postFuture;
  late Future<List<Map<String, dynamic>>> commentsFuture;

  final TextEditingController _commentCtrl = TextEditingController();

  dynamic _postId;
  bool _inited = false;

  String? _meId;
  String? _meEmail;
  String? _token;

  bool _sendingComment = false;

  late final Future<void> _meReady;

  @override
  void initState() {
    super.initState();

    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    _meReady = _loadMe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_inited) return;
    _inited = true;

    _postId = ModalRoute.of(context)!.settings.arguments;

    postFuture = _meReady.then((_) => fetchPost(_postId));
    commentsFuture = _meReady.then((_) => fetchComments(_postId));
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _normalizedBaseUrl() {
    final base = AppConfig.baseUrl.trim();
    if (base.endsWith('/')) return base.substring(0, base.length - 1);
    return base;
  }

  String? _resolvePostImageUrl(String? raw, dynamic postId) {
    if (raw == null) return null;
    final url = raw.trim();
    if (url.isEmpty) return null;

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final base = _normalizedBaseUrl();

    if (url.startsWith('/')) {
      return '$base$url';
    }

    final idStr = postId?.toString();
    if (idStr != null && idStr.isNotEmpty) {
      return '$base/api/posts/$idStr/image';
    }

    return '$base/$url';
  }

  Future<void> _loadMe() async {
    final token = await TokenStorage.readAccessToken();
    _token = token;

    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';

      final payload = _decodeJwtPayload(token);

      final sub = _pickFirstString(payload, ['sub']);
      if (sub != null && sub.contains('@')) {
        _meEmail = sub;
      } else {
        _meId = sub;
      }

      _meId ??= _pickFirstString(payload, ['id', 'userId', 'user_id', 'memberId', 'uid']);
      _meEmail ??= _pickFirstString(payload, ['email', 'userEmail', 'username']);
    }

    if ((_meId == null || _meId!.isEmpty) && (_meEmail == null || _meEmail!.isEmpty)) {
      await _tryFetchMeFromApi();
    }

    if (mounted) setState(() {});
  }

  Future<void> _tryFetchMeFromApi() async {
    if (_token == null || _token!.isEmpty) return;

    final candidates = [
      '/api/users/me',
      '/api/auth/me',
      '/api/me',
    ];

    for (final path in candidates) {
      try {
        final res = await dio.get(path);
        final data = res.data;

        Map<String, dynamic> obj = {};
        if (data is Map && data['data'] is Map) obj = Map<String, dynamic>.from(data['data']);
        else if (data is Map) obj = Map<String, dynamic>.from(data);

        _meId ??= _pickAnyString(obj, [
          ['id'],
          ['userId'],
          ['user_id'],
          ['memberId'],
        ]);

        _meEmail ??= _pickAnyString(obj, [
          ['email'],
          ['userEmail'],
          ['username'],
        ]);

        if ((_meId != null && _meId!.isNotEmpty) || (_meEmail != null && _meEmail!.isNotEmpty)) {
          return;
        }
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _handleAuthExpired() async {
    await TokenStorage.deleteAccessToken();
    _token = null;
    dio.options.headers.remove('Authorization');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
    );

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (route) => false,
    );
  }


  Future<Map<String, dynamic>> fetchPost(dynamic postId) async {
    try {
      final idStr = postId.toString();
      final res = await dio.get('/api/posts/$idStr');
      final data = res.data;

      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }

      throw Exception('응답 형태를 해석할 수 없음: ${data.runtimeType} / $data');
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[POST] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
      }
      throw Exception('통신 실패(status=$status): ${e.response?.data}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(dynamic postId) async {
    try {
      final idStr = postId.toString();
      final res = await dio.get('/api/posts/$idStr/comments');
      final data = res.data;

      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      throw Exception('댓글 응답 형태를 해석할 수 없음: ${data.runtimeType} / $data');
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[COMMENTS] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
      }
      throw Exception('댓글 통신 실패(status=$status): ${e.response?.data}');
    }
  }

  Future<void> _refreshAll() async {
    await _meReady;
    setState(() {
      postFuture = fetchPost(_postId);
      commentsFuture = fetchComments(_postId);
    });
    await Future.delayed(const Duration(milliseconds: 200));
  }


  bool _truthy(dynamic v) {
    if (v is bool) return v;
    if (v == null) return false;
    final s = v.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'y' || s == 'yes';
  }

  bool _sameEmail(String? a, String? b) {
    if (a == null || b == null) return false;
    final aa = a.trim().toLowerCase();
    final bb = b.trim().toLowerCase();
    if (aa.isEmpty || bb.isEmpty) return false;
    return aa == bb;
  }

  bool _sameId(String? a, String? b) {
    if (a == null || b == null) return false;
    final aa = a.trim();
    final bb = b.trim();
    if (aa.isEmpty || bb.isEmpty) return false;
    return aa == bb;
  }

  bool _isMyPost(Map<String, dynamic> post) {
    final serverMine = post['isMine'] ?? post['mine'] ?? post['isWriter'] ?? post['isAuthor'];
    if (_truthy(serverMine)) return true;

    final writerId = _pickAnyString(post, [
      ['writerId'],
      ['userId'],
      ['user_id'],
      ['authorId'],
      ['memberId'],
      ['user', 'id'],
      ['writer', 'id'],
      ['author', 'id'],
      ['user', 'userId'],
      ['user', 'user_id'],
    ]);

    if (_sameId(_meId, writerId)) return true;

    final writerEmail = _pickAnyString(post, [
      ['writerEmail'],
      ['userEmail'],
      ['email'],
      ['authorEmail'],
      ['user', 'email'],
      ['writer', 'email'],
      ['author', 'email'],
      ['user', 'userEmail'],
    ]);

    if (_sameEmail(_meEmail, writerEmail)) return true;

    return false;
  }

  bool _isMyComment(Map<String, dynamic> c) {
    final serverMine = c['isMine'] ?? c['mine'] ?? c['isWriter'] ?? c['isAuthor'];
    if (_truthy(serverMine)) return true;

    final writerId = _pickAnyString(c, [
      ['writerId'],
      ['userId'],
      ['user_id'],
      ['authorId'],
      ['memberId'],
      ['user', 'id'],
      ['writer', 'id'],
      ['author', 'id'],
      ['user', 'userId'],
      ['user', 'user_id'],
    ]);

    if (_sameId(_meId, writerId)) return true;

    final writerEmail = _pickAnyString(c, [
      ['writerEmail'],
      ['userEmail'],
      ['email'],
      ['authorEmail'],
      ['user', 'email'],
      ['writer', 'email'],
      ['author', 'email'],
    ]);

    if (_sameEmail(_meEmail, writerEmail)) return true;

    return false;
  }


  Future<void> _openPostMoreSheet(Map<String, dynamic> post) async {
    await _meReady;

    final isMine = _isMyPost(post);
    final postId = (post['id'] ?? _postId)?.toString();

    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('신고 기능은 다음 업데이트 예정입니다.')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('공유'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('공유 기능은 다음 업데이트 예정입니다.')),
                );
              },
            ),
            if (isMine && postId != null && postId.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정하기'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.postEdit,
                    arguments: postId,
                  );
                  if (result == true) {
                    await _refreshAll();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제하기'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deletePost(postId);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    await _meReady;

    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    ) ??
        false;

    if (!ok) return;

    try {
      await dio.delete('/api/posts/$postId');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[POST_DELETE] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패(status=$status): ${e.response?.data}')),
      );
    }
  }

  Future<void> _sendComment() async {
    await _meReady;

    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (_sendingComment) return;

    setState(() => _sendingComment = true);
    try {
      await dio.post(
        '/api/posts/${_postId.toString()}/comments',
        data: {
          'content': text,
          'description': text,
        },
      );

      if (!mounted) return;

      _commentCtrl.clear();
      setState(() {
        commentsFuture = fetchComments(_postId);
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[COMMENT_CREATE] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
        return;
      }
      if (status == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글 작성 권한이 없습니다.')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패(status=$status): ${e.response?.data}')),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _openCommentMoreSheet(Map<String, dynamic> c) async {
    await _meReady;

    final isMine = _isMyComment(c);

    final commentId = _pickAnyString(c, [
      ['id'],
      ['commentId'],
      ['commentsId'],
      ['comment_id'],
    ]);

    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('댓글 신고는 다음 업데이트 예정입니다.')),
                );
              },
            ),
            if (isMine && commentId != null && commentId.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('댓글 수정'),
                onTap: () async {
                  Navigator.pop(context);
                  await _editCommentDialog(c, commentId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('댓글 삭제'),
                onTap: () async {
                  Navigator.pop(context);
                  await _deleteComment(commentId);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editCommentDialog(Map<String, dynamic> c, String commentId) async {
    final oldText = _pickAnyString(c, [
      ['description'],
      ['content'],
      ['comment'],
      ['text'],
      ['body'],
      ['message'],
    ]) ??
        '';

    final ctrl = TextEditingController(text: oldText);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '댓글 내용을 입력하세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
        ],
      ),
    ) ??
        false;

    if (!ok) return;

    final newText = ctrl.text.trim();
    if (newText.isEmpty) return;

    await _updateComment(commentId, newText);
  }

  Future<void> _updateComment(String commentId, String text) async {
    if (_token == null || _token!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final path = '/api/posts/${_postId.toString()}/comments/$commentId';

    try {
      await dio.put(
        path,
        data: {
          'description': text,
          'content': text,
        },
      );

      if (!mounted) return;
      setState(() {
        commentsFuture = fetchComments(_postId);
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[COMMENT_UPDATE] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
        return;
      }
      if (status == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 없습니다. 내 댓글만 수정할 수 있어요.')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 수정 실패(status=$status): ${e.response?.data}')),
      );
    }
  }

  Future<void> _deleteComment(String commentId) async {
    if (_token == null || _token!.isNotEmpty == false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    ) ??
        false;

    if (!ok) return;

    final path = '/api/posts/${_postId.toString()}/comments/$commentId';

    try {
      await dio.delete(path);

      if (!mounted) return;
      setState(() {
        commentsFuture = fetchComments(_postId);
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      debugPrint('[COMMENT_DELETE] status=$status body=${e.response?.data}');

      if (status == 401) {
        await _handleAuthExpired();
        return;
      }
      if (status == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 없습니다. 내 댓글만 삭제할 수 있어요.')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패(status=$status): ${e.response?.data}')),
      );
    }
  }


  String _dateOnly(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }


  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return {};
      final payload = parts[1];

      final normalized = base64Url.normalize(payload);
      final bytes = base64Url.decode(normalized);
      final jsonStr = utf8.decode(bytes);
      final obj = json.decode(jsonStr);

      if (obj is Map<String, dynamic>) return obj;
      if (obj is Map) return Map<String, dynamic>.from(obj);
      return {};
    } catch (_) {
      return {};
    }
  }

  String? _pickFirstString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v == null) continue;
      final s = v.toString();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _pickAnyString(Map<String, dynamic> root, List<List<String>> paths) {
    for (final path in paths) {
      dynamic cur = root;
      bool ok = true;

      for (final key in path) {
        if (cur is Map && cur.containsKey(key)) {
          cur = cur[key];
        } else {
          ok = false;
          break;
        }
      }

      if (!ok || cur == null) continue;
      final s = cur.toString();
      if (s.isNotEmpty) return s;
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryPink,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendingComment ? null : _sendComment,
                icon: _sendingComment
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('에러: ${snapshot.error}'),
              ),
            );
          }

          final post = snapshot.data ?? {};

          final writerName =
              _pickAnyString(post, [
                ['writerName'],
                ['name'],
                ['userName'],
                ['nickname'],
                ['user', 'name'],
                ['writer', 'name'],
                ['author', 'name'],
              ]) ??
                  '이름';

          final createdAtRaw = (post['createdAt'] ?? post['created_at'] ?? '').toString();
          final createdAt = _dateOnly(createdAtRaw);

          final content =
              _pickAnyString(post, [
                ['description'],
                ['content'],
                ['text'],
                ['body'],
              ]) ??
                  '';

          final rawImage = (post['imgUrl'] ?? post['imageUrl'] ?? post['image_url'])?.toString();
          final resolvedImage = _resolvePostImageUrl(rawImage, post['id'] ?? _postId);
          final hasImage = resolvedImage != null && resolvedImage.isNotEmpty;

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              writerName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 10),
                            if (createdAt.isNotEmpty)
                              Text(
                                createdAt,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    content,
                    style: const TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
                const SizedBox(height: 12),
                if (hasImage) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        resolvedImage!,
                        width: double.infinity,
                        height: 320,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 320,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.chat_bubble_outline)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _openPostMoreSheet(post),
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    '댓글',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: commentsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('댓글 에러: ${snap.error}'),
                      );
                    }

                    final comments = snap.data ?? [];
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text('아직 댓글이 없습니다.', style: TextStyle(color: Colors.grey.shade600)),
                      );
                    }

                    return Column(
                      children: comments.map((c) {
                        final cWriter =
                            _pickAnyString(c, [
                              ['writerName'],
                              ['name'],
                              ['userName'],
                              ['user', 'name'],
                              ['writer', 'name'],
                            ]) ??
                                '이름';

                        final cContent =
                            _pickAnyString(c, [
                              ['description'],
                              ['content'],
                              ['comment'],
                              ['text'],
                              ['body'],
                              ['message'],
                            ]) ??
                                '';

                        final cCreatedRaw = (c['createdAt'] ?? c['created_at'] ?? '').toString();
                        final cCreated = _dateOnly(cCreatedRaw);

                        return Column(
                          children: [
                            ListTile(
                              leading: const CircleAvatar(radius: 16),
                              title: Text(cWriter, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                cContent.isEmpty ? '(내용 없음)' : cContent,
                                style: const TextStyle(height: 1.3),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(cCreated, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _openCommentMoreSheet(c),
                                    child: const Icon(Icons.more_horiz, size: 20),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
