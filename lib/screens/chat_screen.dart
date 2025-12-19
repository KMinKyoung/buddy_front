import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';
import 'chatroom_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
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
    await Navigator.pushNamed(context, AppRoutes.login);
    await _checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    // 로딩
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 로그인 필요 화면
    if (!_isLoggedIn) {
      return WillPopScope(
        onWillPop: () async {
          _goMain(context);
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('채팅', style: TextStyle(color: Colors.black)),
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
                    '채팅 기능을 사용하려면\n로그인 해주세요.',
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

    // 로그인 된 경우: 기존 채팅방 목록
    final rooms = [
      {
        'roomId': 1,
        'name': '러닝메이트 1',
        'lastMessage': '오늘 몇 시에 뛸까요?',
        'time': '2025.12.17',
        'unread': 2,
      },
      {
        'roomId': 2,
        'name': '스터디룸 팀',
        'lastMessage': '내일 회의 2시에 확정!',
        'time': '2025.12.16',
        'unread': 0,
      },
      {
        'roomId': 3,
        'name': '친구',
        'lastMessage': '오케이~',
        'time': '2025.12.15',
        'unread': 5,
      },
    ];

    return WillPopScope(
      onWillPop: () async {
        _goMain(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('채팅', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
          itemBuilder: (context, i) {
            final r = rooms[i];
            final roomId = r['roomId'] as int;
            final name = r['name'] as String;
            final last = r['lastMessage'] as String;
            final time = r['time'] as String;
            final unread = r['unread'] as int;

            return ListTile(
              leading: const CircleAvatar(radius: 22),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(last, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      roomId: roomId,
                      roomName: name,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
