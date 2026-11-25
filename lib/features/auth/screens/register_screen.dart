import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/google_identity_provider.dart';
import '../widgets/auth_components.dart';
import '../widgets/google_sign_in_action_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.authService,
    this.googleIdentityProvider,
  });

  final AuthService? authService;
  final GoogleIdentityProvider? googleIdentityProvider;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _localityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late final AuthService _authService;

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _googleIdToken;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService.shared;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _localityController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (_isSubmitting) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final mobile = _mobileController.text.trim();
    final googleIdToken = _googleIdToken;

    try {
      if (googleIdToken == null) {
        await _authService.registerHousehold(
          fullName: _nameController.text.trim(),
          mobile: mobile,
          localityId: _localityController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.registerGoogleHousehold(
          idToken: googleIdToken,
          fullName: _nameController.text.trim(),
          mobile: mobile,
          localityId: _localityController.text.trim(),
        );
      }

      if (!mounted) return;

      // Navigate only when the backend accepted registration.
      context.go(
        '/otp/registration',
        extra: mobile,
      );
    } on DioException catch (error) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          401 => l10n.googleIdentityInvalid,
          403 => l10n.googleAccountUnavailable,
          409 => googleIdToken == null
              ? l10n.mobileAlreadyRegistered
              : l10n.googleAccountConflict,
          422 => l10n.registrationDetailsInvalid,
          429 => l10n.otpRateLimited,
          503 => googleIdToken == null
              ? l10n.smsUnavailable
              : l10n.googleVerificationUnavailable,
          _ => error.response == null
              ? l10n.authNetworkUnavailable
              : l10n.errorGeneric,
        };
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = AppLocalizations.of(context).errorGeneric;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _onGoogleToken(String idToken) {
    if (!mounted) return;
    setState(() {
      _googleIdToken = idToken;
      _errorMessage = null;
    });
  }

  void _onGoogleError(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _errorMessage = error is GoogleIdentityConfigurationException
          ? l10n.googleConfigurationMissing
          : l10n.googleSignInFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthScreenShell(
      title: l10n.createAccount,
      subtitle: l10n.selfRegisterNote,
      onBack: () => context.go(AppConstants.routeLanding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_googleIdToken == null) ...[
              GoogleSignInActionButton(
                label: l10n.continueWithGoogle,
                provider: widget.googleIdentityProvider,
                disabled: _isSubmitting,
                onIdToken: (idToken) async => _onGoogleToken(idToken),
                onError: _onGoogleError,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.orContinueWithMobile,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ] else ...[
              AuthNotice(message: l10n.googleSignupHelp),
              const SizedBox(height: 16),
            ],
            SwTextField(
              controller: _nameController,
              label: l10n.fullName,
              hint: l10n.nameHint,
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) {
                final name = value?.trim() ?? '';

                if (name.isEmpty) return l10n.nameRequired;

                if (name.length < 2 || name.length > 120) {
                  return 'Name must be 2â€“120 characters.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _mobileController,
              label: l10n.mobileNumber,
              hint: l10n.mobileHint,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              textInputAction: TextInputAction.next,
              inputFormatters: mobileInputFormatters,
              autofillHints: const [
                AutofillHints.telephoneNumber,
              ],
              validator: (value) => validateMobileNumber(
                value,
                l10n.mobileRequired,
                l10n.mobileInvalid,
              ),
            ),
            const SizedBox(height: 16),
            SwTextField(
              controller: _localityController,
              label: l10n.locality,
              hint: l10n.localityHint,
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final locality = value?.trim() ?? '';

                if (locality.isEmpty) {
                  return l10n.localityRequired;
                }

                if (locality.length > 100) {
                  return 'Locality must be at most 100 characters.';
                }

                return null;
              },
            ),
            if (_googleIdToken == null) ...[
              const SizedBox(height: 16),
              SwTextField(
                controller: _passwordController,
                label: l10n.password,
                hint: l10n.passwordCreateHint,
                obscureText: true,
                showPasswordLabel: l10n.showPassword,
                hidePasswordLabel: l10n.hidePassword,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.passwordRequired;
                  }
                  if (value.length < 10 || value.length > 128) {
                    return 'Password must be 10â€“128 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwTextField(
                controller: _confirmController,
                label: l10n.confirmPassword,
                hint: l10n.confirmPasswordHint,
                obscureText: true,
                showPasswordLabel: l10n.showPassword,
                hidePasswordLabel: l10n.hidePassword,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onRegister(),
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.confirmPasswordRequired;
                  }
                  if (value != _passwordController.text) {
                    return l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              AuthNotice(
                message: _errorMessage!,
                isError: true,
              ),
            ],
            const SizedBox(height: 24),
            SwButton(
              label: _googleIdToken == null
                  ? l10n.createAccount
                  : l10n.continueButton,
              onPressed: _isSubmitting ? null : _onRegister,
              isLoading: _isSubmitting,
            ),
            if (_googleIdToken != null)
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() {
                          _googleIdToken = null;
                          _errorMessage = null;
                        }),
                child: Text(l10n.useMobilePasswordInstead),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => context.go(AppConstants.routeLogin),
              child: Text(l10n.signIn),
            ),
          ],
        ),
      ),
    );
  }
}
