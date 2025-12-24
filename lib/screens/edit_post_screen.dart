import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/painting.dart';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';
import '../network/dio_client.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  final _contentCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _authChecking = true;
  bool _loading = true;
  bool _saving = false;

  String? _token;
  dynamic _postId;

  String? _originName;
  String? _originCreatedAt;

  String? _originImageDisplayUrl;

  // 새로 선택한 이미지(업로드 예정)
  XFile? _pickedImage;

  static const int _maxUploadBytes = 2 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    DioClient.init();
    _bootstrap();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
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

    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    final base = _normalizedBaseUrl();

    if (url.startsWith('/')) return '$base$url';

    final idStr = postId?.toString();
    if (idStr != null && idStr.isNotEmpty) {
      return '$base/api/posts/$idStr/image';
    }

    return '$base/$url';
  }

  String _withCacheBust(String url) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (url.contains('?')) return '$url&v=$ts';
    return '$url?v=$ts';
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
      await _goLogin();
      return;
    }

    _token = token;
    setState(() => _authChecking = false);

    await _resolveArgsAndFetch();
  }

  Future<void> _goLogin() async {
    if (!mounted) return;

    await Navigator.pushNamed(context, AppRoutes.login);
    final token = await TokenStorage.readAccessToken();
    if (!mounted) return;

    if (token == null || token.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    _token = token;
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
      final res = await DioClient.dio.get('/api/posts/$_postId');
      final data = res.data;

      Map<String, dynamic>? post;
      if (data is Map && data['data'] is Map) {
        post = Map<String, dynamic>.from(data['data'] as Map);
      } else if (data is Map) {
        post = Map<String, dynamic>.from(data);
      }
      if (post == null) throw Exception('응답 파싱 실패: ${data.runtimeType}');

      final desc = (post['description'] ?? post['content'] ?? '').toString();
      if (desc.isNotEmpty) _contentCtrl.text = desc;

      _originName = (post['name'] ?? post['nickname'] ?? post['userNickname'])?.toString();
      _originCreatedAt = (post['createdAt'] ?? post['created_at'])?.toString();

      final rawImg = (post['imgUrl'] ?? post['imageUrl'] ?? post['image_url'])?.toString();
      final resolved = _resolvePostImageUrl(rawImg, _postId);

      // 항상 캐시버스터 붙여서 “새로 로드” 유도
      _originImageDisplayUrl = (resolved != null) ? _withCacheBust(resolved) : null;

      if (!mounted) return;
      setState(() => _loading = false);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
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
        SnackBar(content: Text('불러오기 실패 (status=$status): ${e.response?.data}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('불러오기 실패: $e')),
      );
    }
  }

  Future<void> _pickNewImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        // 용량 확 줄이기(413 예방)
        imageQuality: 55,
        maxWidth: 1280,
      );
      if (picked == null) return;

      // 파일 크기 체크 (웹은 path로 file size 체크가 어렵기 때문에 bytes로 체크)
      final bytes = await picked.readAsBytes();
      if (bytes.length > _maxUploadBytes) {
        if (!mounted) return;
        final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 용량이 너무 큽니다. ($mb MB) 더 작은 이미지를 선택해주세요.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _pickedImage = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  void _clearPickedImage() {
    setState(() => _pickedImage = null);
  }

  Future<void> _uploadImageIfNeeded() async {
    if (_pickedImage == null) return;

    final path = '/api/posts/${_postId.toString()}/image';

    // 요청마다 FormData 새로 만들기(재사용 금지)
    FormData formData;

    final bytes = await _pickedImage!.readAsBytes();
    final filename = _pickedImage!.name.isNotEmpty ? _pickedImage!.name : 'upload.jpg';

    formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final res = await DioClient.dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      // 업로드 성공 로그
      // ignore: avoid_print
      print('[EDIT][UPLOAD] status=${res.statusCode}');

      // 업로드 후 "항상 같은 이미지 URL"이라 캐시가 문제됨
      // => 캐시 제거 + 캐시버스터 URL로 교체
      final base = _normalizedBaseUrl();
      final stable = '$base/api/posts/${_postId.toString()}/image';
      final busted = _withCacheBust(stable);

      try {
        PaintingBinding.instance.imageCache.evict(NetworkImage(stable));
        PaintingBinding.instance.imageCache.evict(NetworkImage(busted));
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _originImageDisplayUrl = busted;
        _pickedImage = null;
      });

      //  확실히 최신 상태 동기화(서버에서 objectKey를 바꿨는지 확인)
      await _fetchPostDetail();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      // ignore: avoid_print
      print('[EDIT][UPLOAD_FAIL] status=$status body=$body');

      if (status == 413) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 용량이 너무 커서 업로드가 차단되었습니다. 더 작은 이미지로 시도하세요.')),
        );
        rethrow;
      }

      rethrow;
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
      final body = <String, dynamic>{'description': content};
      await DioClient.dio.put('/api/posts/$_postId', data: body);

      if (_pickedImage != null) {
        await _uploadImageIfNeeded();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수정되었습니다.')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

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
        SnackBar(content: Text('수정 실패 (status=$status): ${e.response?.data}')),
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          if ((_originName ?? '').isNotEmpty || (_originCreatedAt ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  if ((_originName ?? '').isNotEmpty)
                    Text(_originName!, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if ((_originCreatedAt ?? '').isNotEmpty)
                    Text(_originCreatedAt!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),

          const Text('이미지', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          if (_pickedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(
                _pickedImage!.path,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              )
                  : Image.file(
                File(_pickedImage!.path),
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _clearPickedImage,
                    child: const Text('선택 취소'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else if ((_originImageDisplayUrl ?? '').isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _originImageDisplayUrl!,
                key: ValueKey(_originImageDisplayUrl),
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
            const SizedBox(height: 12),
          ] else ...[
            Container(
              height: 190,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: Text('이미지 없음', style: TextStyle(color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickNewImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('이미지 변경'),
            ),
          ),

          const SizedBox(height: 18),

          const Text('내용', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          TextField(
            controller: _contentCtrl,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: '내용을 수정하세요',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('저장하기'),
            ),
          ),
        ],
      ),
    );
  }
}
