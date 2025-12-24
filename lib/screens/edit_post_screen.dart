import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  late final Dio dio;

  final TextEditingController _contentCtrl = TextEditingController();

  bool _authChecking = true;
  bool _loading = true;
  bool _saving = false;

  String? _token;

  dynamic _postId;
  String? _originImageUrl;
  String? _originNickname;
  String? _originCreatedAt;

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

    _bootstrap();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _authChecking = true;
      _loading = true;
    });


    final token = await TokenStorage.readAccessToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _token = null;
        _authChecking = false;
        _loading = false;
      });

      // 로그인 유도 → 돌아왔는데도 토큰 없으면 수정 화면 닫기
      await _goLogin();
      return;
    }

    _token = token;
    dio.options.headers['Authorization'] = 'Bearer $token';

    setState(() => _authChecking = false);


    await _resolveArgsAndFetch();
  }

  Future<void> _goLogin() async {
    if (!mounted) return;

    await Navigator.pushNamed(context, AppRoutes.login);
    final token = await TokenStorage.readAccessToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      // 로그인 안 했으면 수정 화면 종료 (뒤로가면 이전 화면으로)
      Navigator.pop(context, false);
      return;
    }

    _token = token;
    dio.options.headers['Authorization'] = 'Bearer $token';

    // 로그인했으면 글 불러오기
    await _resolveArgsAndFetch();
  }

  Future<void> _resolveArgsAndFetch() async {
    final args = ModalRoute.of(context)?.settings.arguments;

    dynamic postId;
    if (args is int || args is String) {
      postId = args;
    } else if (args is Map) {
      postId = args['id'] ?? args['postId'];
      final desc = (args['description'] ?? args['content'] ?? '').toString();
      if (desc.isNotEmpty) _contentCtrl.text = desc;

      _originImageUrl = (args['imgUrl'] ?? args['imageUrl'] ?? args['image_url'])?.toString();
      _originNickname = (args['nickname'] ?? args['userNickname'])?.toString();
      _originCreatedAt = (args['createdAt'] ?? args['created_at'])?.toString();
    }

    if (postId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정할 게시글 id를 찾을 수 없습니다.')),
      );
      Navigator.pop(context, false);
      return;
    }

    _postId = postId;

    await _fetchPostDetail();
  }

  Future<void> _fetchPostDetail() async {
    setState(() => _loading = true);

    try {
      final res = await dio.get('/api/posts/$_postId');
      final data = res.data;

      Map<String, dynamic>? post;

      if (data is Map && data['data'] is Map) {
        post = Map<String, dynamic>.from(data['data'] as Map);
      } else if (data is Map) {
        post = Map<String, dynamic>.from(data);
      }

      if (post == null) {
        throw Exception('응답 파싱 실패: ${data.runtimeType}');
      }

      final desc = (post['description'] ?? post['content'] ?? '').toString();
      if (desc.isNotEmpty) {
        _contentCtrl.text = desc;
      }

      _originImageUrl = (post['imgUrl'] ?? post['imageUrl'] ?? post['image_url'])?.toString();
      _originNickname = (post['nickname'] ?? post['userNickname'])?.toString();
      _originCreatedAt = (post['createdAt'] ?? post['created_at'])?.toString();

      if (!mounted) return;
      setState(() => _loading = false);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      if (!mounted) return;
      setState(() => _loading = false);

      if (status == 401 || status == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
        );
        await TokenStorage.clear();
        await _goLogin();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패 (status=$status): $body')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final body = <String, dynamic>{
        'description': content,
      };

      try {
        await dio.patch('/api/posts/$_postId', data: body);
      } on DioException {
        await dio.put('/api/posts/$_postId', data: body);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정되었습니다.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (!mounted) return;

      if (status == 401 || status == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
        );
        await TokenStorage.clear();
        await _goLogin();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패 (status=$status): $data')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('게시글 수정', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: _primaryPink,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: _saving
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('저장'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if ((_originNickname ?? '').isNotEmpty || (_originCreatedAt ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if ((_originNickname ?? '').isNotEmpty)
                    Text(
                      _originNickname!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  const SizedBox(width: 8),
                  if ((_originCreatedAt ?? '').isNotEmpty)
                    Text(
                      _originCreatedAt!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),

          // 기존 이미지 미리보기(변경은 아직 안 함)
          if ((_originImageUrl ?? '').isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _originImageUrl!,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 190,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Text('내용', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          TextField(
            controller: _contentCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '내용을 수정하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPink,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('저장하기'),
            ),
          ),
        ],
      ),
    );
  }
}
