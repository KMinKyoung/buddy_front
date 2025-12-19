import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_api.dart';
import '../../storage/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  final _api = AuthApi();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final token = await _api.login(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      await TokenStorage.saveAccessToken(token);

      if (!mounted) return;

      // 메인으로 이동
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    // 나중에 구글 OAuth 연동 로직으로 교체
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('준비중'),
        content: const Text('구글 로그인은 다음 업데이트에서 제공됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('로그인'),
        centerTitle: true,
        backgroundColor: _primaryPink,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ✅ Buddy + 문구 가운데
                          Align(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  'Buddy',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '다시 만나서 반가워요.',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: '이메일',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return '이메일을 입력해주세요.';
                              if (!value.contains('@')) return '이메일 형식이 올바르지 않아요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _pwCtrl,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: '비밀번호',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return '비밀번호를 입력해주세요.';
                              if (value.length < 4) return '비밀번호는 4자 이상을 권장해요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // 기본 로그인 버튼
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryPink,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Text(_loading ? '로그인 중...' : '로그인'),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // 구분선
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.grey.shade300, thickness: 1),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('또는', style: TextStyle(fontSize: 12)),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey.shade300, thickness: 1),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Google 로그인 버튼
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _loginWithGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _primaryPink,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'G',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Google로 로그인',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // 회원가입 이동
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pushNamed(context, AppRoutes.signup),
                            style: TextButton.styleFrom(foregroundColor: Colors.black),
                            child: const Text('회원가입 하러가기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
