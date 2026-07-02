import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  Future<void> _openForgotPasswordDialog() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    bool isSending = false;
    bool sent = false;
    String? errorText;

    Future<void> sendResetEmail(StateSetter setDialogState) async {
      if (isSending) return;
      if (!formKey.currentState!.validate()) return;

      setDialogState(() {
        isSending = true;
        errorText = null;
      });

      try {
        await AuthService.sendPasswordResetEmail(emailController.text.trim());
        setDialogState(() {
          isSending = false;
          sent = true;
        });
      } on FirebaseAuthException catch (e) {
        final msg = e.code == 'user-not-found'
            ? 'No user found for that email.'
            : 'Failed: ${e.message ?? e.code}';
        setDialogState(() {
          isSending = false;
          errorText = msg;
        });
      } catch (_) {
        setDialogState(() {
          isSending = false;
          errorText = 'Unexpected error';
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cs = Theme.of(ctx).colorScheme;
          final email = emailController.text.trim();

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(sent ? 'Email sent' : 'Reset password'),
            content: sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Done — password reset email sent.'),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  )
                : Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !isSending,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a valid email';
                            }
                            if (!_isValidEmail(value.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        if (errorText != null && errorText!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              errorText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
            actions: sent
                ? [
                    FilledButton(
                      onPressed: isSending
                          ? null
                          : () => sendResetEmail(setDialogState),
                      child: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Resend email'),
                    ),
                    TextButton(
                      onPressed:
                          isSending ? null : () => Navigator.of(ctx).pop(),
                      child: const Text('Go back'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed:
                          isSending ? null : () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: isSending
                          ? null
                          : () => sendResetEmail(setDialogState),
                      child: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    ),
                  ],
          );
        },
      ),
    );
    emailController.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.signIn(
          _emailController.text.trim(), _passwordController.text);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'invalid-email' || e.code == 'user-not-found') {
          _emailError = 'Enter a valid email';
        } else if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          _passwordError = 'Password is incorrect';
        } else {
          _generalError = 'Login failed: ${e.message ?? 'Unknown error'}';
        }
      });
      _formKey.currentState?.validate();
    } catch (_) {
      if (!mounted) return;
      setState(() => _generalError = 'Unexpected error during login');
      _formKey.currentState?.validate();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = Responsive(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.75), cs.surface],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: r.s(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.maxFormWidth),
                child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.06), end: Offset.zero)
                      .animate(_fadeAnim),
                  child: Column(
                    children: [
                      Container(
                        width: r.s(80),
                        height: r.s(80),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Icon(Icons.task_alt_rounded,
                            size: r.icon(44), color: Colors.white),
                      ),
                      SizedBox(height: r.s(14)),
                      Text('Welcome Back',
                          style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: r.s(4)),
                      Text('Sign in to continue',
                          style:
                              tt.bodyLarge?.copyWith(color: Colors.white70)),
                      SizedBox(height: r.s(32)),

                      Container(
                        padding: EdgeInsets.all(r.s(24)),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.disabled,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(16)),
                                ),
                                onChanged: (_) {
                                  if (_emailError != null ||
                                      _generalError != null) {
                                    setState(() {
                                      _emailError = null;
                                      _generalError = null;
                                    });
                                  }
                                },
                                validator: (v) {
                                  if (_emailError != null) return _emailError;
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter a valid email';
                                  }
                                  if (!_isValidEmail(v.trim())) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () => setState(() =>
                                        _obscurePassword =
                                            !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(16)),
                                ),
                                onChanged: (_) {
                                  if (_passwordError != null ||
                                      _generalError != null) {
                                    setState(() {
                                      _passwordError = null;
                                      _generalError = null;
                                    });
                                  }
                                },
                                validator: (v) {
                                  if (_passwordError != null) {
                                    return _passwordError;
                                  }
                                  if (v == null || v.isEmpty) {
                                    return 'Enter your password';
                                  }
                                  return null;
                                },
                              ),
                              if (_generalError != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cs.errorContainer
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 18, color: cs.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(_generalError!,
                                              style: TextStyle(
                                                  color: cs.error,
                                                  fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPasswordDialog,
                                  child: const Text('Forgot password?'),
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                height: r.h(52),
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white))
                                      : const Text('Sign In',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?",
                              style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SignupScreen())),
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
