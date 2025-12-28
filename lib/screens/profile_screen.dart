import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    setState(() => _loading = true);

    final token = await TokenStorage.readAccessToken();

    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _loading = false;
    });
  }

  void _goMain(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
          (route) => false,
    );
  }

  Future<void> _goLogin(BuildContext context) async {
    await Navigator.pushNamed(context, AppRoutes.login);
    await _checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return WillPopScope(
        onWillPop: () async {
          _goMain(context);
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('내 프로필', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    '로그인이 필요합니다.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '프로필/내 글/내 댓글/좋아요를 보려면\n로그인 해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _goLogin(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text('로그인 하러가기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _ProfileAuthedView(
      goMain: _goMain,
      primaryPink: Colors.white,
      onLoggedOut: () async => _checkLogin(),
    );
  }
}

enum _ProfileMenu { settings, logout }

class _ProfileAuthedView extends StatefulWidget {
  final void Function(BuildContext context) goMain;
  final Color primaryPink;
  final Future<void> Function() onLoggedOut;

  const _ProfileAuthedView({
    required this.goMain,
    required this.primaryPink,
    required this.onLoggedOut,
  });

  @override
  State<_ProfileAuthedView> createState() => _ProfileAuthedViewState();
}

class _ProfileAuthedViewState extends State<_ProfileAuthedView> {
  late final Dio _dio;


  bool _postsLoading = true;
  String? _postsError;
  List<Map<String, dynamic>> _myPosts = [];
  int _page = 0;
  final int _size = 20;


  bool _commentsLoading = true;
  String? _commentsError;
  List<Map<String, dynamic>> _myComments = [];


  int? _myUserId;

  @override
  void initState() {
    super.initState();

    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    _dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _loadMyUserIdFromToken();

    _loadMyPosts(reset: true);
    _loadMyComments(reset: true);
  }


  Future<Options> _authOptions() async {
    final token = await TokenStorage.readAccessToken();
    return Options(headers: {
      'Authorization': token != null ? 'Bearer $token' : null,
      'Accept': 'application/json',
    });
  }

  Future<void> _handleAuthExpired() async {
    await TokenStorage.deleteAccessToken();
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


  Future<void> _loadMyUserIdFromToken() async {
    final token = await TokenStorage.readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return;

      final payloadJson = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payload = jsonDecode(payloadJson);

      final uid = payload['userId'] ??
          payload['id'] ??
          payload['uid'] ??
          payload['user_id'];

      final parsed = (uid is int) ? uid : int.tryParse(uid?.toString() ?? '');
      if (!mounted) return;
      setState(() => _myUserId = parsed);
    } catch (_) {}
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool _isMyPost(Map<String, dynamic> p) {
    if (_myUserId == null) return false;
    final raw = p['user_id'] ?? p['userId'] ?? p['userID'];
    final authorId = _toInt(raw);
    if (authorId == null) return false;
    return _myUserId == authorId;
  }

  bool _isMyComment(Map<String, dynamic> c) {
    if (_myUserId == null) return false;
    final raw = c['user_id'] ?? c['userId'] ?? c['userID'];
    final authorId = _toInt(raw);
    if (authorId == null) return false;
    return _myUserId == authorId;
  }


  List<dynamic>? _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is List) return content;

      final innerData = data['data'];
      if (innerData is List) return innerData;
      if (innerData is Map<String, dynamic>) {
        final innerContent = innerData['content'];
        if (innerContent is List) return innerContent;
      }

      final items = data['items'];
      if (items is List) return items;

      final posts = data['posts'];
      if (posts is List) return posts;

      final comments = data['comments'];
      if (comments is List) return comments;
    }

    return null;
  }

  dynamic _parseMaybeJson(dynamic raw) {
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return <dynamic>[];
      try {
        return jsonDecode(s);
      } catch (_) {
        return raw;
      }
    }
    return raw;
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


  String _dateOnly(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
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


  Future<void> _logout(BuildContext context) async {
    await TokenStorage.deleteAccessToken();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었습니다.')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
            (route) => false,
      );
    }

    await widget.onLoggedOut();
  }


  Future<void> _loadMyPosts({required bool reset}) async {
    if (reset) {
      setState(() {
        _postsLoading = true;
        _postsError = null;
        _myPosts = [];
        _page = 0;
      });
    } else {
      setState(() {
        _postsLoading = true;
        _postsError = null;
      });
    }

    try {
      final token = await TokenStorage.readAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('토큰이 없습니다. 다시 로그인 해주세요.');
      }

      final res = await _dio.get(
        '/user/posts',
        queryParameters: {
          'page': _page,
          'size': _size,
          'sort': 'createdAt,desc',
        },
        options: (await _authOptions()).copyWith(responseType: ResponseType.plain),
      );

      final parsed = _parseMaybeJson(res.data);
      if (parsed is! Map<String, dynamic> && parsed is! List) {
        throw Exception('응답 형식이 JSON이 아닙니다: ${parsed.toString()}');
      }

      final rawList = _extractList(parsed) ?? <dynamic>[];

      final mapped = rawList.map<Map<String, dynamic>>((e) {
        final m = (e is Map<String, dynamic>) ? e : <String, dynamic>{};

        return {
          'id': m['id'],
          'user_id': m['user_id'] ?? m['userId'],
          'name': m['name'],
          'title': m['title'],
          'description': m['description'] ?? m['content'],
          'image_url': m['image_url'] ?? m['imageUrl'] ?? m['imgUrl'],
          'createdAt': m['createdAt'] ?? m['created_at'],
          'updatedAt': m['updatedAt'] ?? m['updated_at'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _myPosts = mapped;
        _postsLoading = false;
        _postsError = null;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data?.toString() ?? e.message ?? '요청 실패';
      if (!mounted) return;

      if (code == 401) {
        await _handleAuthExpired();
        return;
      }

      setState(() {
        _postsError = '내 글 조회 실패 (status: $code)\n$msg';
        _postsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postsError = e.toString();
        _postsLoading = false;
      });
    }
  }

  Future<void> _goEditPost(BuildContext context, dynamic id) async {
    if (id == null) return;

    final result = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: id.toString(),
    );

    if (result == true) {
      await _loadMyPosts(reset: true);
    }
  }

  Future<void> _deletePost(BuildContext context, dynamic id) async {
    if (id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('정말 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _dio.delete('/api/posts/$id', options: await _authOptions());

      setState(() {
        _myPosts.removeWhere((e) => (e['id']?.toString() ?? '') == id.toString());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.')),
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        await _handleAuthExpired();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패(status=$code): ${e.response?.data}')),
      );
    }
  }


  Future<void> _loadMyComments({required bool reset}) async {
    if (reset) {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
        _myComments = [];
      });
    } else {
      setState(() {
        _commentsLoading = true;
        _commentsError = null;
      });
    }

    try {
      final token = await TokenStorage.readAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('토큰이 없습니다. 다시 로그인 해주세요.');
      }

      final res = await _dio.get(
        '/user/comments',
        options: (await _authOptions()).copyWith(responseType: ResponseType.plain),
      );

      final parsed = _parseMaybeJson(res.data);
      if (parsed is! Map<String, dynamic> && parsed is! List) {
        throw Exception('응답 형식이 JSON이 아닙니다: ${parsed.toString()}');
      }

      final rawList = _extractList(parsed) ?? <dynamic>[];

      final mapped = rawList.map<Map<String, dynamic>>((e) {
        final m = (e is Map<String, dynamic>) ? e : <String, dynamic>{};

        final commentId = _pickAnyString(m, [
          ['id'],
          ['commentId'],
          ['commentsId'],
          ['comment_id'],
        ]) ??
            '';

        final postId = _pickAnyString(m, [
          ['postId'],
          ['post_id'],
          ['post', 'id'],
          ['post', 'postId'],
        ]) ??
            '';

        final content = _pickAnyString(m, [
          ['description'],
          ['content'],
          ['comment'],
          ['text'],
          ['body'],
          ['message'],
        ]) ??
            '';

        final createdAt = (m['createdAt'] ?? m['created_at'] ?? '').toString();

        final writerId = _pickAnyString(m, [
          ['user_id'],
          ['userId'],
          ['user', 'id'],
          ['writerId'],
        ]);

        final writerName = _pickAnyString(m, [
          ['writerName'],
          ['name'],
          ['userName'],
          ['user', 'name'],
        ]);

        final postTitle = _pickAnyString(m, [
          ['postTitle'],
          ['title'],
          ['post', 'title'],
        ]);

        return {
          'id': commentId,
          'post_id': postId,
          'user_id': writerId,
          'writerName': writerName,
          'postTitle': postTitle,
          'content': content,
          'createdAt': createdAt,
          'raw': m,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _myComments = mapped;
        _commentsLoading = false;
        _commentsError = null;
      });
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = e.response?.data?.toString() ?? e.message ?? '요청 실패';

      if (code == 401) {
        await _handleAuthExpired();
        return;
      }

      if (!mounted) return;
      setState(() {
        _commentsError = '내 댓글 조회 실패 (status: $code)\n$msg';
        _commentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsError = e.toString();
        _commentsLoading = false;
      });
    }
  }

  Future<void> _editCommentDialog(Map<String, dynamic> c) async {
    final commentId = (c['id'] ?? '').toString();
    final postId = (c['post_id'] ?? '').toString();
    final oldText = (c['content'] ?? '').toString();

    if (commentId.isEmpty || postId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글/게시글 ID를 찾지 못했어요.')),
      );
      return;
    }

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

    await _updateComment(postId: postId, commentId: commentId, text: newText);
  }

  Future<void> _updateComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    try {
      final path = '/api/posts/$postId/comments/$commentId'; // ✅ post_detail.dart 방식

      await _dio.put(
        path,
        data: {
          'description': text,
          'content': text,
        },
        options: await _authOptions(),
      );

      // 화면 즉시 반영
      setState(() {
        final idx = _myComments.indexWhere((e) => (e['id'] ?? '') == commentId);
        if (idx != -1) _myComments[idx]['content'] = text;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정되었습니다.')),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 401) {
        await _handleAuthExpired();
        return;
      }
      if (code == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 없습니다. 내 댓글만 수정할 수 있어요.')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 수정 실패(status=$code): ${e.response?.data}')),
      );
    }
  }

  Future<void> _deleteComment({
    required String postId,
    required String commentId,
  }) async {
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

    try {
      final primaryPath = '/api/posts/$postId/comments/$commentId';
      try {
        await _dio.delete(primaryPath, options: await _authOptions());
      } on DioException catch (e) {
        // 혹시 서버가 /api/comments/{id} 형태면 fallback
        if (e.response?.statusCode == 404) {
          await _dio.delete('/api/comments/$commentId', options: await _authOptions());
        } else {
          rethrow;
        }
      }

      setState(() {
        _myComments.removeWhere((e) => (e['id'] ?? '') == commentId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제되었습니다.')),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;

      if (code == 401) {
        await _handleAuthExpired();
        return;
      }
      if (code == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 없습니다. 내 댓글만 삭제할 수 있어요.')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 삭제 실패(status=$code): ${e.response?.data}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final likedPosts = <Map<String, dynamic>>[];

    return WillPopScope(
      onWillPop: () async {
        widget.goMain(context);
        return false;
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('내 프로필', style: TextStyle(color: Colors.black)),
            backgroundColor: widget.primaryPink,
            foregroundColor: Colors.black,
            elevation: 0,
            actions: [
              PopupMenuButton<_ProfileMenu>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) async {
                  switch (value) {
                    case _ProfileMenu.settings:
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('설정은 다음 업데이트 예정입니다.')),
                        );
                      }
                      break;
                    case _ProfileMenu.logout:
                      await _logout(context);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _ProfileMenu.settings, child: Text('설정(추후)')),
                  PopupMenuItem(value: _ProfileMenu.logout, child: Text('로그아웃')),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(radius: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '공주님',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '프로필/팔로우 기능은 다음 업데이트 예정입니다.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              const TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: [
                  Tab(text: '내 글'),
                  Tab(text: '내 댓글'),
                  Tab(text: '좋아요'),
                ],
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: TabBarView(
                  children: [
                    // 내 글
                    _MyPostsFeedTab(
                      loading: _postsLoading,
                      error: _postsError,
                      items: _myPosts,
                      onRefresh: () => _loadMyPosts(reset: true),
                      dateOnly: _dateOnly,
                      resolveImageUrl: _resolvePostImageUrl,
                      onTapItem: (id) {
                        if (id == null) return;
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: id);
                      },
                      isMine: (post) => _isMyPost(post),
                      onEdit: (id) => _goEditPost(context, id),
                      onDelete: (id) => _deletePost(context, id),
                    ),

                    // 내 댓글
                    _MyCommentsTab(
                      loading: _commentsLoading,
                      error: _commentsError,
                      items: _myComments,
                      dateOnly: _dateOnly,
                      onRefresh: () => _loadMyComments(reset: true),
                      isMine: (c) => _isMyComment(c),
                      onTapGoPost: (postId) {
                        if (postId == null) return;
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: postId);
                      },
                      onEdit: (c) => _editCommentDialog(c),
                      onDelete: (c) {
                        final commentId = (c['id'] ?? '').toString();
                        final postId = (c['post_id'] ?? '').toString();
                        if (commentId.isEmpty || postId.isEmpty) return;
                        _deleteComment(postId: postId, commentId: commentId);
                      },
                    ),

                    // ---------- 좋아요 (더미) ----------
                    _SimplePostList(
                      items: likedPosts,
                      emptyText: '좋아요한 글이 없습니다.',
                      onTap: (postId) {
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: postId);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MyPostsFeedTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;

  final String Function(String raw) dateOnly;
  final String? Function(String? raw, dynamic postId) resolveImageUrl;

  final void Function(dynamic id) onTapItem;

  final bool Function(Map<String, dynamic> post) isMine;
  final void Function(dynamic id) onEdit;
  final void Function(dynamic id) onDelete;

  const _MyPostsFeedTab({
    required this.loading,
    required this.error,
    required this.items,
    required this.onRefresh,
    required this.dateOnly,
    required this.resolveImageUrl,
    required this.onTapItem,
    required this.isMine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(onPressed: onRefresh, child: const Text('다시 시도')),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) return const Center(child: Text('작성한 글이 없습니다.'));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
        itemBuilder: (context, i) {
          final p = items[i];

          final id = p['id'];
          final name = (p['name'] ?? '사용자').toString();
          final title = (p['title'] ?? '').toString();
          final desc = (p['description'] ?? '').toString();

          final createdAtRaw = (p['createdAt'] ?? '').toString();
          final createdAt = dateOnly(createdAtRaw);

          final rawImage = (p['image_url'] ?? '').toString();
          final imageUrl = resolveImageUrl(rawImage, id);

          final mine = isMine(p);

          return _FeedPostItem(
            nickname: name,
            createdAt: createdAt,
            title: title,
            content: desc,
            imageUrl: imageUrl,
            onTapItem: () => onTapItem(id),
            onTapLike: () {},
            onTapChat: () {
              if (id != null) onTapItem(id);
            },
            onTapMore: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.open_in_new),
                        title: const Text('상세 보기'),
                        onTap: () {
                          Navigator.pop(context);
                          if (id != null) onTapItem(id);
                        },
                      ),
                      const Divider(height: 1),
                      if (mine) ...[
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('수정'),
                          onTap: () {
                            Navigator.pop(context);
                            onEdit(id);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('삭제'),
                          onTap: () {
                            Navigator.pop(context);
                            onDelete(id);
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      ListTile(
                        leading: const Icon(Icons.report),
                        title: const Text('신고'),
                        onTap: () => Navigator.pop(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.share),
                        title: const Text('공유'),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedPostItem extends StatelessWidget {
  final String nickname;
  final String createdAt;
  final String title;
  final String content;
  final String? imageUrl;

  final VoidCallback onTapItem;
  final VoidCallback onTapLike;
  final VoidCallback onTapChat;
  final VoidCallback onTapMore;

  const _FeedPostItem({
    required this.nickname,
    required this.createdAt,
    required this.title,
    required this.content,
    required this.onTapItem,
    required this.onTapLike,
    required this.onTapChat,
    required this.onTapMore,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTapItem,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        if (createdAt.isNotEmpty)
                          Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (title.trim().isNotEmpty)
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              if (title.trim().isNotEmpty) const SizedBox(height: 6),
              Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
              if (hasImage) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl!,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 190,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 190,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(onPressed: onTapLike, icon: const Icon(Icons.favorite_border), splashRadius: 20),
                  IconButton(onPressed: onTapChat, icon: const Icon(Icons.chat_bubble_outline), splashRadius: 20),
                  const Spacer(),
                  IconButton(onPressed: onTapMore, icon: const Icon(Icons.more_horiz), splashRadius: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _MyCommentsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> items;
  final String Function(String raw) dateOnly;
  final Future<void> Function() onRefresh;

  final bool Function(Map<String, dynamic> c) isMine;
  final void Function(dynamic postId) onTapGoPost;
  final void Function(Map<String, dynamic> c) onEdit;
  final void Function(Map<String, dynamic> c) onDelete;

  const _MyCommentsTab({
    required this.loading,
    required this.error,
    required this.items,
    required this.dateOnly,
    required this.onRefresh,
    required this.isMine,
    required this.onTapGoPost,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(onPressed: onRefresh, child: const Text('다시 시도')),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) return const Center(child: Text('작성한 댓글이 없습니다.'));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
        itemBuilder: (context, i) {
          final c = items[i];

          final commentId = (c['id'] ?? '').toString();
          final postId = (c['post_id'] ?? '').toString();
          final content = (c['content'] ?? '').toString();
          final postTitle = (c['postTitle'] ?? '').toString();
          final createdAt = dateOnly((c['createdAt'] ?? '').toString());

          final mine = isMine(c);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              content.isEmpty ? '(내용 없음)' : content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (postTitle.trim().isNotEmpty)
                    Text('게시글: $postTitle', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  if (createdAt.isNotEmpty)
                    Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.open_in_new),
                          title: const Text('게시글로 이동'),
                          onTap: () {
                            Navigator.pop(context);
                            if (postId.isNotEmpty) onTapGoPost(postId);
                          },
                        ),
                        const Divider(height: 1),
                        if (mine && commentId.isNotEmpty && postId.isNotEmpty) ...[
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('댓글 수정'),
                            onTap: () {
                              Navigator.pop(context);
                              onEdit(c);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('댓글 삭제'),
                            onTap: () {
                              Navigator.pop(context);
                              onDelete(c);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            onTap: () {
              if (postId.isNotEmpty) onTapGoPost(postId);
            },
          );
        },
      ),
    );
  }
}



class _SimplePostList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final void Function(dynamic postId) onTap;

  const _SimplePostList({
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
      itemBuilder: (context, i) {
        final p = items[i];
        final postId = p['postId'];
        final title = (p['title'] ?? '').toString();
        final content = (p['content'] ?? '').toString();
        final date = (p['date'] ?? '').toString();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title.isEmpty ? '(제목 없음)' : title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(content, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          onTap: () => onTap(postId),
        );
      },
    );
  }
}
