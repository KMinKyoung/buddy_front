import 'dart:convert';

import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class SnsScreen extends StatefulWidget {
  const SnsScreen({super.key});

  @override
  State<SnsScreen> createState() => _SnsScreenState();
}

class _SnsScreenState extends State<SnsScreen> {
  late final Dio dio;

  // 목록/페이지 상태
  final List<Map<String, dynamic>> _posts = [];
  final Set<String> _seenIds = {}; // 중복 방지
  int _page = 0;
  final int _size = 10;

  bool _loadingInit = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  // 내 userId (토큰에서 추출)
  int? _myUserId;

  // 스크롤 컨트롤러 (맨 위로 + 무한로딩 트리거)
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _scrollController.addListener(_onScroll);

    _loadMyUserIdFromToken(); // 내 userId 로드
    _fetchFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchNextPage();
    }
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

      final uid = payload['userId'] ?? payload['id'] ?? payload['uid'] ?? payload['user_id'];
      final parsed = (uid is int) ? uid : int.tryParse(uid?.toString() ?? '');

      if (!mounted) return;
      setState(() => _myUserId = parsed);
    } catch (_) {
      // 실패해도 앱은 돌아가게
    }
  }

  Future<void> _fetchFirstPage() async {
    setState(() {
      _loadingInit = true;
      _error = null;
      _page = 0;
      _hasMore = true;
      _posts.clear();
      _seenIds.clear();
    });

    try {
      final result = await _requestPosts(page: 0);
      _applyPageResult(result);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loadingInit = false);
    }
  }

  Future<void> _fetchNextPage() async {
    if (_loadingInit || _loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _requestPosts(page: nextPage);
      _applyPageResult(result);
      setState(() => _page = nextPage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 로딩 실패: $e')),
        );
      }
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  Future<_PostPageResult> _requestPosts({required int page}) async {
    try {
      final res = await dio.get(
        '/api/posts',
        queryParameters: {
          'page': page,
          'size': _size,
        },
      );

      final data = res.data;

      if (data is Map && data['content'] is List) {
        final list = (data['content'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final bool last = data['last'] == true;
        return _PostPageResult(items: list, hasMore: !last);
      }

      if (data is Map && data['data'] is List) {
        final list = (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final hasMore = list.length == _size;
        return _PostPageResult(items: list, hasMore: hasMore);
      }

      if (data is List) {
        final list = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final hasMore = list.length == _size;
        return _PostPageResult(items: list, hasMore: hasMore);
      }

      throw Exception('응답 형태를 해석할 수 없음: ${data.runtimeType} / $data');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw Exception('통신 실패(status=$status): $body');
    }
  }

  void _applyPageResult(_PostPageResult result) {
    for (final p in result.items) {
      final idStr = (p['id'] ?? p['postId'] ?? '').toString();
      if (idStr.isEmpty) continue;
      if (_seenIds.add(idStr)) {
        _posts.add(p);
      }
    }
    setState(() {
      _hasMore = result.hasMore;
    });
  }

  Future<void> _refresh() => _fetchFirstPage();

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goCreatePost(BuildContext context) async {
    final token = await TokenStorage.readAccessToken();

    if (token == null || token.isEmpty) {
      await Navigator.pushNamed(context, AppRoutes.login);
      return;
    }

    final result = await Navigator.pushNamed(context, AppRoutes.postCreate);

    if (result == true) {
      _refresh();
    }
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.readAccessToken();
    return Options(headers: {
      'Authorization': token != null ? 'Bearer $token' : null,
    });
  }

  Future<void> _goEditPost(BuildContext context, dynamic id) async {
    if (id == null) return;

    final result = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: id,
    );

    if (result == true) {
      _refresh();
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await dio.delete('/api/posts/$id', options: await _authOptions());

      setState(() {
        _posts.removeWhere((e) => (e['id']?.toString() ?? '') == id.toString());
        _seenIds.remove(id.toString());
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  // 생성일
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

  String _displayName(Map<String, dynamic> p) {
    final name = p['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return '사용자';
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  bool _isMyPost(Map<String, dynamic> p) {
    if (_myUserId == null) return false;

    final raw = p['userId'] ?? p['user_id'];
    final authorId = _toInt(raw);
    if (authorId == null) return false;

    return _myUserId == authorId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.egg, color: Color(0xFFFFE8E8), size: 32),
        title: const Text('Buddy', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
      ),

      // 우측 하단 버튼 2개 ((위)글쓰기 / (아래)맨위로)
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'fab_write',
            mini: true,
            elevation: 2,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade800,
            onPressed: () => _goCreatePost(context),
            child: const Icon(Icons.edit, size: 18),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'fab_top',
            mini: true,
            elevation: 2,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade800,
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward, size: 18),
          ),
        ],
      ),

      body: _loadingInit
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('에러: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchFirstPage,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      )
          : (_posts.isEmpty)
          ? const Center(child: Text('게시글이 없습니다.'))
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: _posts.length + 1, // 하단 로딩용 1칸
          separatorBuilder: (_, __) =>
          const Divider(height: 1, thickness: 1),
          itemBuilder: (context, i) {
            if (i == _posts.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!_hasMore) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('마지막 글입니다.')),
                );
              }
              return const SizedBox.shrink();
            }

            final p = _posts[i];

            final id = p['id'];
            final name = _displayName(p);
            final isMine = _isMyPost(p);

            final createdAtRaw =
            (p['createdAt'] ?? p['created_at'] ?? '').toString();
            final createdAt = _dateOnly(createdAtRaw);

            final content =
            (p['description'] ?? p['content'] ?? '').toString();

            final rawImage =
            (p['imgUrl'] ?? p['imageUrl'] ?? p['image_url'])
                ?.toString();
            final resolvedImage = _resolvePostImageUrl(rawImage, id);
            final hasImage =
                resolvedImage != null && resolvedImage.isNotEmpty;

            return _PostItem(
              nickname: name,
              createdAt: createdAt,
              content: content,
              imageUrl: hasImage ? resolvedImage : null,
              onTapItem: () {
                if (id == null) return;
                Navigator.pushNamed(
                  context,
                  AppRoutes.postDetail,
                  arguments: id,
                );
              },
              onTapLike: () {
                // TODO
              },
              onTapChat: () {
                // TODO
              },
              onTapMore: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMine) ...[
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('수정'),
                            onTap: () {
                              Navigator.pop(context);
                              _goEditPost(context, id);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('삭제'),
                            onTap: () {
                              Navigator.pop(context);
                              _deletePost(context, id);
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
      ),
    );
  }
}

class _PostPageResult {
  final List<Map<String, dynamic>> items;
  final bool hasMore;
  _PostPageResult({required this.items, required this.hasMore});
}

class _PostItem extends StatelessWidget {
  final String nickname;
  final String createdAt;
  final String content;
  final String? imageUrl;

  final VoidCallback onTapItem;
  final VoidCallback onTapLike;
  final VoidCallback onTapChat;
  final VoidCallback onTapMore;

  const _PostItem({
    required this.nickname,
    required this.createdAt,
    required this.content,
    required this.onTapItem,
    required this.onTapLike,
    required this.onTapChat,
    required this.onTapMore,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
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
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if (imageUrl != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl!,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
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
                  IconButton(
                    onPressed: onTapLike,
                    icon: const Icon(Icons.favorite_border),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: onTapChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    splashRadius: 20,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onTapMore,
                    icon: const Icon(Icons.more_horiz),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
