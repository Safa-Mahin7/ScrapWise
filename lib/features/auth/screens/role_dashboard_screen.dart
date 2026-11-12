import 'package:flutter/material.dart';

import '../services/session_controller.dart';

/// Temporary protected landing page. Functional role dashboards come later.
class RoleDashboardScreen extends StatefulWidget {
  const RoleDashboardScreen({super.key, required this.role});

  final String role;

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await SessionController.instance.signOut();
    } catch (_) {
      // The local token is cleared even when server revocation fails.
      // A server-side token may remain valid until expiry in that case.
      // Do not claim that remote revocation succeeded.
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionController.instance.user;
    final title = '${widget.role[0].toUpperCase()}${widget.role.substring(1)}';
    final name = user?['full_name'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text('$title Dashboard')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome${name == null || name.isEmpty ? '' : ', $name'}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Signed in as ${widget.role}. Your session was verified '
                    'by ScrapWise FastAPI.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This is a temporary route-test screen. The real role '
                    'dashboard and pickup actions are not connected yet.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _signingOut ? null : _signOut,
                    child: Text(_signingOut ? 'Signing out...' : 'Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
