import 'dart:io';

import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  late final Dio dio;

  final TextEditingController _contentCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  bool _loading = false;

  //로그인 체크
  bool _authChecking = true;
  String? _accessToken;

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

    _bootstrapAuth();
  }

  Future<void> _bootstrapAuth() async {
    setState(() => _authChecking = true);

    final token = await TokenStorage.readAccessToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _accessToken = null;
        _authChecking = false;
      });

      // 로그인 유도
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _goLogin();
      });
      return;
    }

    // 토큰 저장 + Dio에 Authorization 헤더
    setState(() {
      _accessToken = token;
      _authChecking = false;
    });

    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> _goLogin() async {
    if (!mounted) return;

    // 로그인 화면으로 이동 후 돌아오면 다시 토큰 체크
    await Navigator.pushNamed(context, AppRoutes.login);
    await _bootstrapAuth();

    // 여전히 로그인 안 되어 있으면 작성 화면에서 빠져나오게
    if (!mounted) return;
    if (_accessToken == null || _accessToken!.isEmpty) {
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted) return;

      setState(() {
        _pickedImage = file;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
    });
  }

  Future<void> _submit() async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      await _goLogin();
      return;
    }

    final content = _contentCtrl.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final body = <String, dynamic>{
        'description': content,
      };

      await dio.post('/api/posts', data: body);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 등록되었습니다.')),
      );

      Navigator.pop(context, true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      // 토큰 만료/인증 실패 케이스(401/403) 처리
      if (status == 401 || status == 403) {
        await TokenStorage.clear(); // 토큰 제거(클래스에 없으면 delete/clear 맞춰서)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
        );
        await _goLogin();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패 (status=$status): $data')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _pickedImage != null;

    // 로그인 체크 중이면 로딩
    if (_authChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 로그인 안 된 상태면 안내 화면
    if (_accessToken == null || _accessToken!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('게시글 작성', style: TextStyle(color: Colors.black)),
          backgroundColor: _primaryPink,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
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
                  '게시글을 작성하려면 로그인 해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _goLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryPink,
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
      );
    }

    // 로그인 된 상태
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('게시글 작성', style: TextStyle(color: Colors.black)),
        backgroundColor: _primaryPink,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: _loading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          // 사진 선택 영역
          Row(
            children: [
              const Text('사진 (선택)', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: _loading ? null : _pickFromGallery,
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('갤러리에서 선택'),
              ),
              if (hasImage)
                TextButton(
                  onPressed: _loading ? null : _removeImage,
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                  child: const Text('삭제'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 미리보기
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_pickedImage!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Text('이미지 미리보기 실패'),
                ),
              ),
            ),
          ] else ...[
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text(
                '선택된 사진이 없습니다.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 내용
          const Text('내용', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _contentCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '내용을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPink,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('등록하기'),
            ),
          ),

          if (hasImage) ...[
            const SizedBox(height: 10),
            Text(
              '※ 현재는 갤러리 선택/미리보기까지만 적용되어 있습니다.\n'
                  '이미지 업로드는 백엔드에서 파일 업로드(multipart) 지원 후 연결됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
