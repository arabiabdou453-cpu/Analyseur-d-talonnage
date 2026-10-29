import 'package:flutter/material.dart';

import '../services/auth.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Affiche [child] seulement si un utilisateur est connecté, sinon l'écran de connexion.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.child});
  final AuthService auth;
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthUser?> _users = widget.auth.userChanges;

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthUser?>(
        stream: _users,
        initialData: widget.auth.current,
        builder: (context, snap) => snap.data == null ? LoginPage(auth: widget.auth) : widget.child,
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false, _busy = false, _hide = true;
  String? _error, _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on AuthError catch (e) {
      if (mounted) setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'auth.failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    final email = _email.text.trim(), password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'auth.invalidEmail');
      return;
    }
    if (_register && password.length < 8) {
      setState(() => _error = 'auth.weakPassword');
      return;
    }
    _run(() => _register ? widget.auth.register(email, password) : widget.auth.signInWithEmail(email, password));
  }

  void _forgot() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'auth.invalidEmail');
      return;
    }
    _run(() async {
      await widget.auth.resetPassword(email);
      if (mounted) setState(() => _info = 'auth.resetSent');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: [TextButton(onPressed: s.toggleLang, child: Text(s.t('lang')))]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Palette.primary, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.speed, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                Text(s.t('app.title'), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.t('auth.sub'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                _GoogleButton(label: s.t('auth.google'), onPressed: _busy ? null : () => _run(widget.auth.signInWithGoogle)),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(s.t('auth.or'))),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: s.t('auth.email'), prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  textDirection: TextDirection.ltr,
                  autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: s.t('auth.password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null) ...[const SizedBox(height: 12), AlertBox(s.t(_error!), tone: Tone.error)],
                if (_info != null) ...[const SizedBox(height: 12), AlertBox(s.t(_info!), tone: Tone.ok)],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(s.t(_register ? 'auth.register' : 'auth.signIn')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                  child: Text(s.t(_register ? 'auth.haveAccount' : 'auth.noAccount')),
                ),
                if (!_register) TextButton(onPressed: _busy ? null : _forgot, child: Text(s.t('auth.forgot'))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton « Continuer avec Google » selon la charte Google (logo G, fond neutre, bord fin).
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
        foregroundColor: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
        side: BorderSide(color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GoogleLogo())),
        const SizedBox(width: 12),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// Logo « G » de Google, dessiné (aucun fichier image à embarquer).
class _GoogleLogo extends CustomPainter {
  const _GoogleLogo();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide, w = s * 0.2, r = (s - w) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);
    Paint p(int color) => Paint()
      ..color = Color(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const deg = 3.141592653589793 / 180;
    canvas.drawArc(rect, 0, 45 * deg, false, p(0xFF4285F4)); // bleu
    canvas.drawArc(rect, 45 * deg, 105 * deg, false, p(0xFF34A853)); // vert
    canvas.drawArc(rect, 150 * deg, 60 * deg, false, p(0xFFFBBC05)); // jaune
    canvas.drawArc(rect, 210 * deg, 108 * deg, false, p(0xFFEA4335)); // rouge
    canvas.drawRect(Rect.fromLTRB(c.dx, c.dy - w / 2, c.dx + r + w / 2, c.dy + w / 2), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
