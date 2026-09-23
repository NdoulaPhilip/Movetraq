import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.signIn(emailOrPhone: _emailCtrl.text.trim(), password: _passwordCtrl.text);
    if (ok && mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  Future<void> _showResetPassword(AuthProvider auth) async {
    final resetFormKey = GlobalKey<FormState>();
    final loginCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    var obscurePassword = true;
    var resetting = false;
    String? dialogError;

    try {
      final didReset = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> reset() async {
                if (!resetFormKey.currentState!.validate()) return;
                setDialogState(() {
                  dialogError = null;
                  resetting = true;
                });
                final ok = await auth.resetPassword(
                  emailOrPhone: loginCtrl.text.trim(),
                  newPassword: newPasswordCtrl.text,
                );
                if (!mounted) return;
                if (ok) {
                  Navigator.of(dialogContext).pop(true);
                  return;
                }
                setDialogState(() {
                  resetting = false;
                  dialogError = auth.errorMessage;
                });
              }

              return AlertDialog(
                title: const Text('Reset password'),
                content: SingleChildScrollView(
                  child: Form(
                    key: resetFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enter your account email or phone and choose a new password.',
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: loginCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email or phone',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: newPasswordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: TextButton(
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                              child: Text(
                                obscurePassword ? 'Show' : 'Hide',
                                style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          validator: (value) => (value == null || value.length < 6) ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: obscurePassword,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                          validator: (value) => value != newPasswordCtrl.text ? 'Passwords do not match' : null,
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: resetting ? null : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(
                    width: 132,
                    child: PrimaryButton(
                      label: 'Reset',
                      height: 46,
                      loading: resetting,
                      onPressed: reset,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (didReset == true && mounted) {
        _passwordCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset. Sign in with your new password.')),
        );
      }
    } finally {
      loginCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 30),
                Text('Welcome back.', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
                const SizedBox(height: 12),
                const Text('Sign in to keep moving your parcels across the city.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.inkSoft)),
                const SizedBox(height: 30),
                const Text('Email or phone', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const Text('Password', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.shield_outlined),
                    suffixIcon: TextButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      child: Text(_obscure ? 'Show' : 'Hide', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton(
                      onPressed: auth.isBusy ? null : () => _showResetPassword(auth),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Forgot password?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    ),
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(auth.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Sign in',
                  trailingIcon: Icons.arrow_forward,
                  loading: auth.isBusy,
                  onPressed: () => _submit(auth),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Row(children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Google',
                        height: 50,
                        fontSize: 14,
                        radius: 14,
                        onPressed: () => _submit(auth),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Apple',
                        height: 50,
                        fontSize: 14,
                        radius: 14,
                        onPressed: () => _submit(auth),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(children: [
                    const Text('New to MoveTraq? ', style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/create'),
                      child: const Text('Create account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
