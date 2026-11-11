import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/auth_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.isLoading = false});

  final bool isLoading;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  final _authService = AuthService();

  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (_isSubmitting || widget.isLoading) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Authenticate with FastAPI.
      final user = await _authService.login(
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
      );

      // Step 2: Use the login token to access the
      // protected /api/auth/me endpoint.
      final verifiedUser = await _authService.currentUser();

      // Step 3: Verify the returned user details.
      if (verifiedUser['role'] != user['role'] ||
          verifiedUser['user_id'] != user['user_id']) {
        throw StateError('Authenticated user details mismatch');
      }

      if (!mounted) return;

      // Temporary success dialog until role dashboards
      // are connected.
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Login successful'),
          content: Text(
            'Authenticated as ${verifiedUser['role'] ?? 'user'}. '
            'The role dashboard will be connected next.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;

      String message;

      switch (error.response?.statusCode) {
        case 401:
          message = 'Authentication failed or your session is invalid.';
          break;

        case 403:
          message = 'Your account is awaiting verification or approval.';
          break;

        case 422:
          message = 'Invalid login details. Please check your input.';
          break;

        case 429:
          message = 'Too many attempts. Please try again later.';
          break;

        case 503:
          message = 'Authentication service is temporarily unavailable.';
          break;

        default:
          if (error.response == null) {
            message = 'Cannot connect to the server. Check your connection '
                'and make sure FastAPI is running.';
          } else {
            message = 'Login failed. Please try again.';
          }
      }

      setState(() {
        _errorMessage = message;
      });
    } on StateError catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Could not verify your login session. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'An unexpected login error occurred.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthScreenShell(
      title: l10n.signInToAccount,
      subtitle: AppConstants.appName,
      onBack: () => context.go(AppConstants.routeLanding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwTextField(
              controller: _mobileController,
              label: l10n.mobileNumber,
              hint: l10n.mobileHint,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                _passwordFocus.requestFocus();
              },
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
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
              controller: _passwordController,
              label: l10n.password,
              hint: l10n.passwordHint,
              obscureText: true,
              showPasswordLabel: l10n.showPassword,
              hidePasswordLabel: l10n.hidePassword,
              prefixIcon: Icons.lock_outline_rounded,
              focusNode: _passwordFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                _onSignIn();
              },
              autofillHints: const [
                AutofillHints.password,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordRequired;
                }

                return null;
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () {
                  context.go(AppConstants.routeForgotPassword);
                },
                child: Text(l10n.forgotPassword),
              ),
            ),
            if (_errorMessage != null) ...[
              AuthNotice(
                message: _errorMessage!,
                isError: true,
              ),
              const SizedBox(height: 16),
            ],
            SwButton(
              label: l10n.signIn,
              onPressed: (_isSubmitting || widget.isLoading) ? null : _onSignIn,
              isLoading: _isSubmitting || widget.isLoading,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.noAccount,
                  style: AppTextStyles.bodySmall,
                ),
                TextButton(
                  onPressed: () {
                    context.go(AppConstants.routeRegister);
                  },
                  child: Text(l10n.createAccount),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
