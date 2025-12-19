// 얘는 보류라고 페이지 막아놓을 예정
import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  void _goMain(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
          (route) => false, // 스택 전부 제거하고 main만 남김
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goMain(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:  Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction, size: 40),
                SizedBox(height: 12),
                Text(
                  '구현을 진행중입니다.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  '다음 업데이트 이후에 이용 부탁드립니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
