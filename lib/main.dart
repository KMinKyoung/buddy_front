import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'config/app_config.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'routes/app_routes.dart';

//로그인, 회원가입 그리고 로고가 보여야함
void main() {
  WidgetsBinding widgetsBinding =WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);


  runApp(const MyApp()); //앱 구동을 위한 부분(메인페이지가 구동됨)

  WidgetsBinding.instance.addPostFrameCallback((_) {
    FlutterNativeSplash.remove();
  });
}



class MyApp extends StatelessWidget {
  //초반 세팅 문법
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp( //디자인 넣는 부분

    );
  }

}
