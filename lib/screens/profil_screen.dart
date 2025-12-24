import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../storage/token_storage.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {


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
    // 로그인 화면으로 이동 후 돌아오면 다시 로그인 상태 체크
    await Navigator.pushNamed(context, AppRoutes.login);
    await _checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 로그인 안 된 경우: "로그인 해주세요" 화면
    if (!_isLoggedIn) {
      return WillPopScope(
        onWillPop: () async {
          _goMain(context);
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('내 프로필', style: TextStyle(color: Colors.black)),
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
                    '프로필/내 글/내 댓글/좋아요를 보려면\n로그인 해주세요.',
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
                        backgroundColor: Colors.white,
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

    // 로그인 된 경우
    return _ProfileAuthedView(
      goMain: _goMain,
      primaryPink: Colors.white,
      onLoggedOut: () async {
        // 로그아웃 후 이 StatefulWidget도 즉시 상태 반영
        await _checkLogin();
      },
    );
  }
}

//  로그인된 프로필 화면

enum _ProfileMenu { settings, logout }

class _ProfileAuthedView extends StatelessWidget {
  final void Function(BuildContext context) goMain;
  final Color primaryPink;
  final Future<void> Function() onLoggedOut;

  const _ProfileAuthedView({
    required this.goMain,
    required this.primaryPink,
    required this.onLoggedOut,
  });

  Future<void> _logout(BuildContext context) async {
    await TokenStorage.deleteAccessToken();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었습니다.')),
      );
    }

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
            (route) => false,
      );
    }

    await onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: 나중에 API로 교체
    final myPosts = [
      {'postId': 101, 'title': '오늘 러닝 후기', 'content': '5km 뛰고 왔어요. 컨디션 최고.', 'date': '2025.12.17'},
      {'postId': 102, 'title': '러닝화 추천', 'content': '발볼 넓은 분들 어떤 거 쓰시나요?', 'date': '2025.12.16'},
    ];

    final myComments = [
      {'postId': 201, 'title': '비 오는 날 러닝', 'content': '비 오면 실내 트레드밀도 괜찮아요.', 'date': '2025.12.17'},
      {'postId': 202, 'title': '러닝 페이스 질문', 'content': '초반에 페이스 너무 올리면 후반에 무너져요.', 'date': '2025.12.15'},
    ];

    final likedPosts = [
      {'postId': 301, 'title': '스트레칭 루틴 공유', 'content': '러닝 전후 10분 루틴 추천합니다.', 'date': '2025.12.14'},
    ];

    return WillPopScope(
      onWillPop: () async {
        goMain(context);
        return false;
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('내 프로필', style: TextStyle(color: Colors.black)),
            backgroundColor: primaryPink,
            foregroundColor: Colors.black,
            elevation: 0,

            actions: [
              PopupMenuButton<_ProfileMenu>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) async {
                  switch (value) {
                    case _ProfileMenu.settings:
                    // 나중에 설정 페이지 만들면 여기 연결
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('설정은 다음 업데이트 예정입니다.')),
                        );
                      }
                      break;
                    case _ProfileMenu.logout:
                      await _logout(context);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ProfileMenu.settings,
                    child: Text('설정(추후)'),
                  ),
                  PopupMenuItem(
                    value: _ProfileMenu.logout,
                    child: Text('로그아웃'),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Column(
            children: [
              const Divider(height: 1, thickness: 1),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(radius: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '공주님',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '프로필/팔로우 기능은 다음 업데이트 예정입니다.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),
              const TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.black,
                tabs: [
                  Tab(text: '내 글'),
                  Tab(text: '내 댓글'),
                  Tab(text: '좋아요'),
                ],
              ),
              const Divider(height: 1, thickness: 1),

              Expanded(
                child: TabBarView(
                  children: [
                    _SimplePostList(
                      items: myPosts,
                      emptyText: '작성한 글이 없습니다.',
                      onTap: (postId) {
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: postId);
                      },
                    ),
                    _SimplePostList(
                      items: myComments,
                      emptyText: '작성한 댓글이 없습니다.',
                      onTap: (postId) {
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: postId);
                      },
                    ),
                    _SimplePostList(
                      items: likedPosts,
                      emptyText: '좋아요한 글이 없습니다.',
                      onTap: (postId) {
                        Navigator.pushNamed(context, AppRoutes.postDetail, arguments: postId);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimplePostList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String emptyText;
  final void Function(dynamic postId) onTap;

  const _SimplePostList({
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
      itemBuilder: (context, i) {
        final p = items[i];
        final postId = p['postId'];
        final title = (p['title'] ?? '').toString();
        final content = (p['content'] ?? '').toString();
        final date = (p['date'] ?? '').toString();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            title.isEmpty ? '(제목 없음)' : title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            date,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          onTap: () => onTap(postId),
        );
      },
    );
  }
}
