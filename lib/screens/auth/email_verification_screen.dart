import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _sending = false;
  bool _checking = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _autoSendVerification();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoSendVerification() async {
    try {
      await AuthService.sendVerificationEmail();
    } catch (_) {}
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _sending = true);
    try {
      await AuthService.sendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Verification email sent. Check your inbox.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _checking = true);
    try {
      await AuthService.reloadCurrentUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status refreshed.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final email = AuthService.currentUser?.email ?? 'your email';
    final r = Responsive(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.secondary,
              cs.secondary.withValues(alpha: 0.65),
              cs.surface,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: r.s(24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.maxFormWidth),
                child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseCtrl.value * 0.08);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: r.s(88),
                      height: r.s(88),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Icon(Icons.mark_email_unread_rounded,
                          size: r.icon(44), color: Colors.white),
                    ),
                  ),
                  SizedBox(height: r.s(20)),
                  Text('Check Your Email',
                      style: tt.headlineMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('We sent a verification link to',
                      style: tt.bodyLarge?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: tt.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
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
                    child: Column(
                      children: [
                        Icon(Icons.verified_outlined,
                            size: r.icon(40), color: cs.primary),
                        SizedBox(height: r.s(12)),
                        Text(
                          'After verifying, tap the button below',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        SizedBox(height: r.s(20)),
                        SizedBox(
                          width: double.infinity,
                          height: r.h(52),
                          child: FilledButton.icon(
                            onPressed:
                                _checking ? null : _checkVerificationStatus,
                            icon: _checking
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                                : const Icon(Icons.verified),
                            label: const Text('I Have Verified',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(12)),
                        SizedBox(
                          width: double.infinity,
                          height: r.h(48),
                          child: OutlinedButton.icon(
                            onPressed:
                                _sending ? null : _resendVerificationEmail,
                            icon: _sending
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                            label: const Text('Resend Email'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => AuthService.signOut(),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Use a different account'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
