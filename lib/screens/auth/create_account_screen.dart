import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _agree = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms of Service and Privacy Policy.')),
      );
      return;
    }
    final ok = await auth.signUp(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (ok && mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
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
                Text('Create your\naccount.', style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32)),
                const SizedBox(height: 12),
                const Text('Join MoveTraq and send your first parcel in minutes.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.inkSoft)),
                const SizedBox(height: 26),
                const Text('Full name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                const Text('Email address', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 16),
                const Text('Phone number', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF3F2EC), borderRadius: BorderRadius.circular(9)),
                          child: const Text('🇳🇬 +234', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ),
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().length < 7) ? 'Enter a valid phone number' : null,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _agree = !_agree),
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: _agree ? AppColors.accent : Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: _agree ? null : Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: _agree ? const Icon(Icons.check, size: 14, color: AppColors.ink) : null,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.inkSoft),
                            children: [
                              TextSpan(text: "I agree to MoveTraq's "),
                              TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                              TextSpan(text: ' and '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                              TextSpan(text: '.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(auth.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Create account',
                  trailingIcon: Icons.arrow_forward,
                  loading: auth.isBusy,
                  onPressed: () => _submit(auth),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Wrap(children: [
                    const Text('Already have an account? ', style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
                      child: const Text('Sign in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
