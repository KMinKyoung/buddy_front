import 'package:buddyfront/app/app_navigator.dart';
import 'package:buddyfront/network/dio_client.dart';
import 'package:buddyfront/screens/edit_post_screen.dart';
import 'package:buddyfront/screens/main_shell.dart';
import 'package:buddyfront/screens/profil_screen.dart';
import 'package:buddyfront/screens/signup_screen.dart';

import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'config/app_config.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'routes/app_routes.dart';
import 'screens/postdetail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sns_screen.dart';
import 'screens/createpost_screen.dart';

import 'routes/app_routes.dart';
import 'app/app_navigator.dart';


//부팅 담당 페이지로 디자인 구성 없이 앱 구동시 필요한것만 넣어놓을 예정
void main() {

  WidgetsBinding widgetsBinding =WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  DioClient.init();

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
      navigatorKey:  navigatorKey,
      initialRoute: AppRoutes.main,
      routes: {
        AppRoutes.main: (_) => const MainShell(),
        AppRoutes.sns: (_) => const SnsScreen(), //post 글들
        AppRoutes.profil: (_) => const ProfilScreen(), //내 정보
        AppRoutes.home: (_) => const HomeScreen(), //메인 페이지
        AppRoutes.store: (_) => const StoreScreen(), //상점
        AppRoutes.chat: (_) => const ChatScreen(), //채팅방

        // 바텀네비 없는 화면
        AppRoutes.postDetail: (_) => const PostDetail(),
        AppRoutes.postCreate: (_) => const CreatePostScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.postEdit: (_) => const EditPostScreen(),
      },
    );
  }
}