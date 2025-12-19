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
  late Future<List<Map<String, dynamic>>> postFuture;

  //맨 위로 버튼용
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

    postFuture = fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      postFuture = fetchPosts();
    });
  }

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


  // 생성일
  String _dateOnly(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }

  Future<List<Map<String, dynamic>>> fetchPosts() async {
    try {
      final res = await dio.get('/api/posts');
      final data = res.data;

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (data is Map && data['data'] is List) {
        final list = data['data'] as List;
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (data is Map && data['content'] is List) {
        final list = data['content'] as List;
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      throw Exception('응답 형태를 해석할 수 없음: ${data.runtimeType} / $data');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      throw Exception('통신 실패(status=$status): $body');
    } catch (e) {
      throw Exception('파싱/처리 실패: $e');
    }
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

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('에러: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? [];
          if (posts.isEmpty) {
            return const Center(child: Text('게시글이 없습니다.'));
          }

          return ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
            const Divider(height: 1, thickness: 1),
            itemBuilder: (context, i) {
              final p = posts[i];

              final id = p['id'];
              final nickname =
              (p['nickname'] ?? p['userNickname'] ?? '닉네임').toString();

              final createdAtRaw =
              (p['createdAt'] ?? p['created_at'] ?? '').toString();
              final createdAt = _dateOnly(createdAtRaw);

              final content =
              (p['description'] ?? p['content'] ?? '').toString();

              final imageUrl =
              (p['imgUrl'] ?? p['imageUrl'] ?? p['image_url'])?.toString();
              final hasImage = imageUrl != null && imageUrl.isNotEmpty;

              return _PostItem(
                nickname: nickname,
                createdAt: createdAt,
                content: content,
                imageUrl: hasImage ? imageUrl : null,
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
          );
        },
      ),
    );
  }
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
