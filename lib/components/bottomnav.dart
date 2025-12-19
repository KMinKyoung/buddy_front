import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return
      BottomNavigationBar(

      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black12,
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home),label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.egg),label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_outlined),label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.local_grocery_store),label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.person),label: '')

      ],
    );
  }
}
