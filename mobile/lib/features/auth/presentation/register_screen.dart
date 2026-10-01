import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/exceptions.dart';
import '../../../core/validators.dart';
import '../../../core/widgets.dart';
import '../data/auth_controller.dart';

/// Company names for the register dropdown — public endpoint, no auth needed.
final registerCompaniesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/api/auth/companies');
    return List<String>.from(res.data['data'] as List? ?? []);
  } on DioException catch (e) {
    throw toApiException(e);
  }
});

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _companyName;
  bool _showPassword = false;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _password, _confirmPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final company = _companyName; // local so null-promotion works below
    try {
      await ref.read(authControllerProvider.notifier).register({
        'fullName': _fullName.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'confirmPassword': _confirmPassword.text,
        // Company is optional; omit when empty so "no company" is unambiguous.
        if (company != null && company.isNotEmpty) 'companyName': company,
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Registration successful. Please log in.');
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e.fieldErrors);
      showAppSnackBar(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).loading;
    final companiesAsync = ref.watch(registerCompaniesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _fullName,
                      label: 'Full name',
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['fullName'],
                      validator: Validators.fullName,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _username,
                      label: 'Username',
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['username'],
                      validator: Validators.username,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['email'],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _password,
                      label: 'Password',
                      obscure: !_showPassword,
                      textInputAction: TextInputAction.next,
                      errorText: _fieldErrors['password'],
                      validator: Validators.password,
                      suffix: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _confirmPassword,
                      label: 'Confirm password',
                      obscure: !_showPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      errorText: _fieldErrors['confirmPassword'],
                      validator: Validators.confirmPassword(() => _password.text),
                    ),
                    const SizedBox(height: 16),
                    // Optional: new users may pick their company now (validated
                    // against the directory server-side) or leave it unassigned.
                    companiesAsync.when(
                      loading: () => DropdownButtonFormField<String>(
                        initialValue: null,
                        decoration: const InputDecoration(labelText: 'Company (optional)'),
                        items: const [],
                        onChanged: null,
                      ),
                      error: (_, __) => DropdownButtonFormField<String>(
                        initialValue: _companyName,
                        decoration: const InputDecoration(
                          labelText: 'Company (optional)',
                          helperText: 'Could not load companies — tap retry',
                        ),
                        items: const [],
                        onChanged: (_) {},
                      ),
                      data: (companies) => DropdownButtonFormField<String>(
                        initialValue: _companyName,
                        decoration: const InputDecoration(labelText: 'Company (optional)'),
                        hint: const Text('Choose your company'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('— No company —')),
                          ...companies.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                        ],
                        onChanged: (v) => setState(() => _companyName = v),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Register', onPressed: _submit, loading: loading),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Log in'),
                    ),
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
