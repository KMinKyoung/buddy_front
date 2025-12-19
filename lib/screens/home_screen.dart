import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  bool _loading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    setState(() => _loading = true);

    final token = await TokenStorage.readAccessToken();

    if (!mounted) return;
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _loading = false;
    });
  }

  void _goMain(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.main,
          (route) => false,
    );
  }

  Future<void> _goLogin(BuildContext context) async {
    // 로그인 화면으로 갔다가 돌아오면 다시 체크
    await Navigator.pushNamed(context, AppRoutes.login);
    await _checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 로그인 안 됨: 로그인 유도 화면
    if (!_isLoggedIn) {
      return WillPopScope(
        onWillPop: () async {
          _goMain(context);
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('내 캐릭터', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
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
                  const SizedBox(height: 6),
                  Text(
                    '캐릭터/만보기 기능을 사용하려면\n로그인 해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _goLogin(context),
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
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 로그인 됨
    // 나중에 만보기/캐릭터 API로 교체
    const characterName = '캐릭터 이름';
    const steps = 1791;
    const goal = 10000;

    return WillPopScope(
      onWillPop: () async {
        _goMain(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              characterName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('이름 편집'),
                                    content: const Text('다음 업데이트에서 지원 예정입니다.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('확인'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              splashRadius: 18,
                              tooltip: '이름 편집',
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_fmt(steps)} / ${_fmt(goal)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('만보기 안내'),
                                    content: const Text('만보기 연동은 다음 업데이트에서 제공됩니다.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('확인'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.help_outline, size: 18),
                              splashRadius: 18,
                              tooltip: '도움말',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 220,
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(150),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '캐릭터',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
