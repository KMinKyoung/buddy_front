import 'dart:io';

import 'package:buddyfront/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  bool _authChecking = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();

    dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _goLogin();
      });
      return;
    }

    setState(() {
      _accessToken = token;
      _authChecking = false;
    });

    // 기본 Authorization 세팅
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> _goLogin() async {
    if (!mounted) return;

    await Navigator.pushNamed(context, AppRoutes.login);
    await _bootstrapAuth();

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
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (!mounted) return;
      setState(() => _pickedImage = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() => _pickedImage = null);
  }

  int? _extractPostId(dynamic data) {
    if (data == null) return null;

    if (data is Map) {
      final direct = int.tryParse(data['id']?.toString() ?? '');
      if (direct != null) return direct;

      final inner = data['data'];
      if (inner is Map) {
        final innerId = int.tryParse(inner['id']?.toString() ?? '');
        if (innerId != null) return innerId;
      }
    }
    return null;
  }

  Future<void> _uploadImage(int postId) async {
    final file = _pickedImage;
    if (file == null) return;

    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/posts/$postId/image'),
        error: 'Missing access token',
      );
    }

    final filename = (file.name.isNotEmpty) ? file.name : 'upload.jpg';

    MultipartFile multipart;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      multipart = MultipartFile.fromBytes(bytes, filename: filename);
    } else {
      multipart = await MultipartFile.fromFile(file.path, filename: filename);
    }

    final formData = FormData.fromMap({'file': multipart});

    await dio.post(
      '/api/posts/$postId/image',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        headers: {'Authorization': 'Bearer $token'},
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
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
      final createRes = await dio.post(
        '/api/posts',
        data: {'description': content},
        options: Options(contentType: 'application/json'),
      );

      final postId = _extractPostId(createRes.data);
      if (postId == null) {
        throw Exception('글 생성 응답에서 id를 찾을 수 없습니다.');
      }

      if (_pickedImage != null) {
        try {
          await _uploadImage(postId);
        } on DioException catch (e) {
          final status = e.response?.statusCode;
          final data = e.response?.data;

          if (status == 401) {
            await TokenStorage.clear();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
            );
            await _goLogin();
            return;
          }

          if (status == 403) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('이미지 업로드 권한이 없습니다(403): $data')),
            );
          } else if (status == 413) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미지 용량이 너무 큽니다. 더 작은 사진으로 시도해주세요.')),
            );
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('이미지 업로드 실패 (status=$status): $data')),
            );
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 등록되었습니다.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      if (status == 401) {
        await TokenStorage.clear();
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

    if (_authChecking) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
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

          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(
                _pickedImage!.path,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : Image.file(
                File(_pickedImage!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
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
              child: Text('선택된 사진이 없습니다.', style: TextStyle(color: Colors.grey.shade700)),
            ),
          ],

          const SizedBox(height: 16),
          const Text('내용', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _contentCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '내용을 입력하세요',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('등록하기'),
            ),
          ),
        ],
      ),
    );
  }
}
