import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import 'subscription_service.dart';

Future<void> showProPaywall(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const ProPaywallScreen(),
);

class ProPaywallScreen extends ConsumerStatefulWidget {
  const ProPaywallScreen({super.key});
  @override
  ConsumerState<ProPaywallScreen> createState() => _ProPaywallState();
}

class _ProPaywallState extends ConsumerState<ProPaywallScreen> {
  bool _busy = false;
  String? _message;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(
          () => _message = 'Store request complete. Your access will update after verification.',
        );
      }
      ref.invalidate(entitlementProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not complete the store request. No access has been changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).asData?.value;
    final service = ref.watch(subscriptionServiceProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, size: 40, color: Color(0xFF8E91FF)),
            const SizedBox(height: 20),
            Text(
              'More room to create.',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unlock commercial packs, unlimited private collections, saved presets, and more image-to-prompt scans.',
            ),
            const SizedBox(height: 20),
            if (user == null)
              const Text(
                'Sign in from your account before subscribing or restoring purchases.',
              )
            else if (kIsWeb)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final response = await ref
                            .read(supabaseProvider)!
                            .functions
                            .invoke(
                              'create-checkout',
                              body: {'plan': 'monthly'},
                            );
                        if (response.status != 200) {
                          throw StateError('Checkout is not ready');
                        }
                        final uri = Uri.parse(response.data['url'] as String);
                        if (uri.scheme != 'https' ||
                            !{
                              'store.lemonsqueezy.com',
                              'checkout.lemonsqueezy.com',
                              'polar.sh',
                            }.any(
                              (h) => uri.host == h || uri.host.endsWith('.$h'),
                            )) {
                          throw StateError('Invalid checkout host');
                        }
                        if (!await launchUrl(
                          uri,
                          webOnlyWindowName: '_blank',
                        )) {
                          throw StateError('Could not open checkout');
                        }
                      }),
                child: const Text('Continue to secure checkout'),
              )
            else
              FutureBuilder<List<Package>>(
                future: service.packages(user.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Store subscriptions are not available yet.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Text(
                      'No store plans are currently available.',
                    );
                  }
                  return Column(
                    children: snapshot.data!
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() => service.purchase(p)),
                              child: Text(
                                '${p.storeProduct.title} · ${p.storeProduct.priceString}',
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            if (user != null && service.supported)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => service.restore(user.id)),
                child: const Text('Restore purchases'),
              ),
            if (_message != null) Text(_message!),
            const SizedBox(height: 16),
            const Text(
              'Prices and billing terms come from your store. Subscriptions renew until cancelled in your store settings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep exploring'),
            ),
          ],
        ),
      ),
    );
  }
}
