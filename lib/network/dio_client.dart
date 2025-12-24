import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

class DioClient {
  DioClient._();

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static bool _inited = false;

  //  토큰 캐시
  static String? _cachedToken;
  static Future<String?>? _loadingTokenFuture;

  static Future<String?> _getTokenCached() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return _cachedToken;

    // 동시에 여러 요청이 토큰을 읽지 않게 Future 공유
    _loadingTokenFuture ??= TokenStorage.readAccessToken();
    final token = await _loadingTokenFuture!;
    _loadingTokenFuture = null;

    _cachedToken = token;
    return token;
  }

  // 로그아웃/토큰삭제 시 캐시도 같이 날려야 안전
  static void clearTokenCache() {
    _cachedToken = null;
    _loadingTokenFuture = null;
  }

  static void init() {
    if (_inited) return;
    _inited = true;

    // 요청 보낼 때마다 토큰 자동 첨부
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (options.extra['noAuth'] == true) {
              options.headers.remove('Authorization');
              handler.next(options);
              return;
            }

            final token = await _getTokenCached();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              options.headers.remove('Authorization');
            }
          } catch (_) {
            options.headers.remove('Authorization');
          }

          handler.next(options);
        },
      ),
    );

    // 401 자동 로그아웃 + 로그인 이동 (403은 로그아웃 금지)
    dio.interceptors.add(AuthInterceptor());

    // 로그 확인용
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }
}
