import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../subscription/pro_paywall_screen.dart';
import '../subscription/subscription_service.dart';
import 'auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException
              ? e.message
              : 'Sign-in is unavailable. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).asData?.value;
    final pro = ref.watch(entitlementProvider).asData?.value ?? false;
    final cloudReady = ref.watch(supabaseProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Your creative space')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 56,
                color: Color(0xFF8E91FF),
              ),
              const SizedBox(height: 24),
              Text(
                user == null ? 'Keep your inspiration close.' : 'Welcome back.',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                user?.email ?? 'Save prompts, build private boards, and pick up where you left off.',
              ),
              const SizedBox(height: 28),
              if (!cloudReady)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Cloud accounts are being connected. You can explore and customize the public library now.',
                  ),
                ),
              if (user == null) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || !cloudReady
                      ? null
                      : () => _run(
                          () => ref
                              .read(authServiceProvider)
                              .sendMagicLink(_email.text),
                          'Check your email for a secure sign-in link.',
                        ),
                  child: const Text('Email me a sign-in link'),
                ),
                const SizedBox(height: 12),
                if (AppConfig.googleAuthEnabled)
                  OutlinedButton.icon(
                    onPressed: _busy || !cloudReady
                        ? null
                        : () => _run(
                            () => ref
                                .read(authServiceProvider)
                                .oauth(OAuthProvider.google),
                            'Continue sign-in in your browser.',
                          ),
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ),
                const SizedBox(height: 12),
                if (AppConfig.appleAuthEnabled)
                  OutlinedButton.icon(
                    onPressed: _busy || !cloudReady
                        ? null
                        : () => _run(
                            () => ref
                                .read(authServiceProvider)
                                .oauth(OAuthProvider.apple),
                            'Continue sign-in in your browser.',
                          ),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(pro ? 'PromptVault Pro' : 'Free creator plan'),
                  subtitle: const Text(
                    'Your subscription is verified securely.',
                  ),
                ),
                FilledButton(
                  onPressed: () => showProPaywall(context),
                  child: Text(pro ? 'Manage your plan' : 'Explore Pro'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref.read(authServiceProvider).signOut(),
                          'Signed out.',
                        ),
                  child: const Text('Sign out'),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_message!),
                ),
              const SizedBox(height: 36),
              const Text(
                'Your boards are private. Public discovery works without an account.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
