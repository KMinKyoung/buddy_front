import 'package:buddyfront/routes/app_routes.dart';
import 'package:buddyfront/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import '../config/app_config.dart';

class AuthApi {
  final Dio dio;

  AuthApi()
      : dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final res = await dio.post(
      '/user/login',
      data: {'email': email, 'password': password},
    );

    final token = res.data['accessToken'] ?? res.data['token'];
    if (token is! String || token.isEmpty) {
      throw Exception('토큰이 응답에 없습니다.');
    }
    return token;
  }

  Future<void> signup({
    required String email,
    required String password,
    required String name,
  }) async {
    await dio.post(
      '/user/signup',
      data: {'email': email, 'password': password, 'name': name},
    );
  }

  static Future<void> logout(BuildContext context) async {
    await TokenStorage.clear();

    if(!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.login, (route) => false
    );
  }
}
