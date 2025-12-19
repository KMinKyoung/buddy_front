import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_api.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color _primaryPink = Color(0xFFFFE8E8);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  final _api = AuthApi();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await _api.signup(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        name: _nameCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 완료! 로그인 해주세요.')),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입'),
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
                                  '처음 오셨군요. 반가워요.',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

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
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: '이름',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return '이름을 입력해주세요.';
                              if (value.length < 2) return '이름은 2자 이상을 권장해요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _pwCtrl,
                            obscureText: _obscure1,
                            decoration: InputDecoration(
                              labelText: '비밀번호',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure1 = !_obscure1),
                                icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return '비밀번호를 입력해주세요.';
                              if (value.length < 4) return '비밀번호는 4자 이상을 권장해요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _pw2Ctrl,
                            obscureText: _obscure2,
                            decoration: InputDecoration(
                              labelText: '비밀번호 확인',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                                icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return '비밀번호 확인을 입력해주세요.';
                              if (value != _pwCtrl.text) return '비밀번호가 일치하지 않아요.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

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
                              child: Text(_loading ? '가입 중...' : '회원가입'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                            style: TextButton.styleFrom(foregroundColor: Colors.black),
                            child: const Text('이미 계정이 있어요 (로그인)'),
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
