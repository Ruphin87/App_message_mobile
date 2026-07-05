import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../controllers/auth_controller.dart';

enum _ResetStep {
  email,
  code,
  password,
  success,
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.errorEmailRequired;
    }
    if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(value.trim())) {
      return AppStrings.errorEmailInvalid;
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le code est requis';
    }
    if (value.trim().length < 6) {
      return 'Entrez le code complet reçu par email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppStrings.errorPasswordRequired;
    }
    if (value.length < 6) {
      return AppStrings.errorPasswordTooShort;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return AppStrings.errorPasswordsDoNotMatch;
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).sendPasswordResetCode(_email);
    if (success && mounted) {
      setState(() => _step = _ResetStep.code);
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).verifyPasswordResetCode(
          email: _email,
          code: _codeController.text.trim(),
        );
    if (success && mounted) {
      setState(() => _step = _ResetStep.password);
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .updateRecoveredPassword(_passwordController.text);
    if (success && mounted) {
      setState(() => _step = _ResetStep.success);
    }
  }

  Future<void> _resendCode() async {
    _codeController.clear();
    await ref.read(authProvider.notifier).sendPasswordResetCode(_email);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildStepContent(authState),
        ),
      ),
    );
  }

  Widget _buildStepContent(AuthState authState) {
    switch (_step) {
      case _ResetStep.email:
        return _buildEmailContent(authState);
      case _ResetStep.code:
        return _buildCodeContent(authState);
      case _ResetStep.password:
        return _buildPasswordContent(authState);
      case _ResetStep.success:
        return _buildSuccessContent();
    }
  }

  Widget _buildEmailContent(AuthState authState) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildHeader(
            icon: Icons.lock_reset,
            title: 'Mot de passe oublié ?',
            subtitle: 'Entrez votre email pour recevoir un code de vérification.',
          ),
          const SizedBox(height: 40),
          CustomTextField(
            label: AppStrings.email,
            controller: _emailController,
            hintText: 'exemple@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            textInputAction: TextInputAction.done,
            validator: _validateEmail,
            onSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: 32),
          CustomButton(
            text: 'Envoyer le code',
            onPressed: _sendCode,
            isLoading: authState.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeContent(AuthState authState) {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildHeader(
            icon: Icons.mark_email_read_outlined,
            title: 'Code de vérification',
            subtitle: 'Un code a été envoyé à $_email. Consultez votre boite mail puis entrez le code ici.',
          ),
          const SizedBox(height: 40),
          CustomTextField(
            label: 'Code reçu par email',
            controller: _codeController,
            hintText: '123456',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_outlined,
            textInputAction: TextInputAction.done,
            validator: _validateCode,
            onSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: authState.isLoading ? null : _resendCode,
            child: const Text('Renvoyer le code'),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Vérifier le code',
            onPressed: _verifyCode,
            isLoading: authState.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordContent(AuthState authState) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _buildHeader(
            icon: Icons.password_outlined,
            title: 'Nouveau mot de passe',
            subtitle: 'Le code est valide. Choisissez maintenant votre nouveau mot de passe.',
          ),
          const SizedBox(height: 40),
          CustomTextField(
            label: AppStrings.password,
            controller: _passwordController,
            hintText: 'Minimum 6 caractères',
            obscureText: !_showPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: _showPassword ? Icons.visibility_off : Icons.visibility,
            onSuffixIconPressed: () => setState(() => _showPassword = !_showPassword),
            textInputAction: TextInputAction.next,
            validator: _validatePassword,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: AppStrings.confirmPassword,
            controller: _confirmPasswordController,
            hintText: 'Confirmez le mot de passe',
            obscureText: !_showConfirmPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
            onSuffixIconPressed: () => setState(
              () => _showConfirmPassword = !_showConfirmPassword,
            ),
            textInputAction: TextInputAction.done,
            validator: _validateConfirmPassword,
            onSubmitted: (_) => _saveNewPassword(),
          ),
          const SizedBox(height: 32),
          CustomButton(
            text: 'Changer le mot de passe',
            onPressed: _saveNewPassword,
            isLoading: authState.isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 48),
        _buildHeader(
          icon: Icons.check_circle_outline,
          title: 'Mot de passe changé',
          subtitle: 'Votre mot de passe a été modifié. Connectez-vous avec le nouveau mot de passe.',
          iconColor: AppColors.success,
          backgroundColor: AppColors.successLight,
        ),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Retour à la connexion',
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    Color iconColor = AppColors.primary,
    Color? backgroundColor,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Icon(icon, size: 40, color: iconColor),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
