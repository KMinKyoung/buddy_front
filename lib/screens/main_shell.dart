import 'package:buddyfront/screens/chat_screen.dart';
import 'package:buddyfront/screens/home_screen.dart';
import 'package:buddyfront/screens/profile_screen.dart';
import 'package:buddyfront/screens/store_screen.dart';
import 'package:flutter/material.dart';
import '../components/bottomnav.dart';
import 'sns_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;


  final List<Widget> _pages = const [
    SnsScreen(),  // 작성된 글들
    HomeScreen(), //메인
    ChatScreen(), //채팅방
    StoreScreen(), //상점
    ProfileScreen(), //내 프로필
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
