import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class PostDetail extends StatefulWidget {
  const PostDetail({super.key});

  @override
  State<PostDetail> createState() => _PostDetailState();
}

class _PostDetailState extends State<PostDetail> {
  late final Dio dio;
  late Future<Map<String, dynamic>> postFuture;

  final TextEditingController _commentCtrl = TextEditingController();

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

    // postId는 build에서 받아서 future를 세팅해야 해서,
    // initState에서는 임시로 비워두고 didChangeDependencies에서 세팅
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final postId = ModalRoute.of(context)!.settings.arguments;
    postFuture = fetchPost(postId);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // "2020.03.24" 형태 (yyyy.MM.dd)
  String _dateOnly(String raw) {
    if (raw.isEmpty) return '';
    final normalized = raw.replaceFirst(' ', 'T');
    final dt = DateTime.tryParse(normalized);
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}.${two(dt.month)}.${two(dt.day)}';
  }

  Future<Map<String, dynamic>> fetchPost(dynamic postId) async {
    try {
      final idStr = postId.toString();
      final res = await dio.get('/api/posts/$idStr');
      final data = res.data;

      // 응답 형태가 다양할 수 있어서 방어
      if (data is Map && data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
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

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _commentCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //뒤로가기
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      // 댓글 작성 바(텍스트칸 + 전송 아이콘)
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
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                onPressed: _sendComment,
                icon: const Icon(Icons.send),
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

          // 백엔드 필드명에 맞춰 필요하면 수정
          final nickname = (post['nickname'] ??
              post['userNickname'] ??
              post['writerNickname'] ??
              '닉네임')
              .toString();

          final createdAtRaw =
          (post['createdAt'] ?? post['created_at'] ?? '').toString();
          final createdAt = _dateOnly(createdAtRaw);

          final content =
          (post['description'] ?? post['content'] ?? '').toString();

          final imageUrl =
          (post['imgUrl'] ?? post['imageUrl'] ?? post['image_url'])
              ?.toString();
          final hasImage = imageUrl != null && imageUrl.isNotEmpty;

          // 댓글은 아직 API 미연동이라 임시
          final comments = <String>['댓글 1', '댓글 2', '댓글 3'];

          return ListView(
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
                            nickname,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
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
              ),

              //  내용
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              ),

              const SizedBox(height: 12),

              //  사진(있으면)
              if (hasImage) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
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

              //  아이콘(좋아요/채팅/더보기)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // TODO: 좋아요 API
                      },
                      icon: const Icon(Icons.favorite_border),
                    ),
                    IconButton(
                      onPressed: () {
                        // TODO: 댓글 영역으로 스크롤 이동 같은 동작 가능
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        // TODO: 더보기(신고/공유/삭제 등)
                      },
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: Colors.grey.shade300),

              //  댓글 섹션(임시)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '댓글들',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),

              ...comments.map((c) {
                return Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(radius: 16),
                      title: Text(c),
                      subtitle: Text(
                        createdAt.isEmpty ? '2020.03.24' : createdAt,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                  ],
                );
              }),

              // 하단 작성바에 가리지 않게 여백
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
