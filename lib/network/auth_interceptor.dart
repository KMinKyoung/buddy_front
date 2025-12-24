import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../app/app_navigator.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';
import 'dio_client.dart';

class AuthInterceptor extends Interceptor {
  bool _handling = false;

  bool _isPublicPath(String path) {
    final p = path.toLowerCase();

    if (p.contains('/login')) return true;
    if (p.contains('/signup')) return true;
    if (p.contains('/reissue')) return true;
    if (p.contains('/refresh')) return true;

    return false;
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // 401만 자동 로그아웃
    if (status == 401 && !_handling && !_isPublicPath(path)) {
      _handling = true;
      try {
        //  토큰 삭제
        await TokenStorage.deleteAccessToken();
        DioClient.clearTokenCache();

        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('로그인이 만료되었습니다. 다시 로그인해주세요.')),
          );
        }

        //  로그인 화면으로 스택 정리해서 이동
        final nav = navigatorKey.currentState;
        nav?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      } finally {
        _handling = false;
      }
    }


    handler.next(err);
  }
}
