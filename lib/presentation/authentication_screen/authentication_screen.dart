import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/utils/validators.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import './widgets/auth_footer_widget.dart';
import './widgets/auth_form_widget.dart';
import './widgets/auth_header_widget.dart';
import './signup_screen.dart';
import './forgot_password_screen.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        Validators.isValidEmail(_emailController.text);
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _breathingController.repeat(reverse: true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Use real Supabase authentication
      final result =
          await _authService.signIn(email: email, password: password);

      if (result['success'] == true) {
        // Success haptic feedback
        HapticFeedback.lightImpact();

        // Navigate to dashboard
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/routine-dashboard');
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Invalid credentials. Please try again.';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _breathingController.stop();
        _breathingController.reset();
      }
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  void _handleCreateAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _breathingController.repeat(reverse: true);

    try {
      final result = await _authService.signInWithGoogle();

      if (result['success'] == true) {
        // Success haptic feedback
        HapticFeedback.lightImpact();

        // Navigate to dashboard
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/routine-dashboard');
        }
      } else {
        setState(() {
          _errorMessage =
              result['message'] ?? 'Google sign-in failed. Please try again.';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in error. Please try again.';
      });
      HapticFeedback.mediumImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _breathingController.stop();
        _breathingController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 2.h),

                    // Header with logo and back button
                    AuthHeaderWidget(
                      onBackPressed: () => Navigator.pushReplacementNamed(
                          context, '/splash-screen'),
                    ),

                    SizedBox(height: 4.h),

                    // Authentication form
                    Expanded(
                      child: AuthFormWidget(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        isPasswordVisible: _isPasswordVisible,
                        isLoading: _isLoading,
                        rememberMe: _rememberMe,
                        errorMessage: _errorMessage,
                        isFormValid: _isFormValid,
                        breathingAnimation: _breathingAnimation,
                        onPasswordVisibilityToggle: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        onRememberMeChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        onSignIn: _handleSignIn,
                        onForgotPassword: _handleForgotPassword,
                        onGoogleSignIn: _handleGoogleSignIn,
                      ),
                    ),

                    SizedBox(height: 2.h),

                    // Footer with create account option
                    AuthFooterWidget(
                      onCreateAccount: _handleCreateAccount,
                    ),

                    SizedBox(height: 4.h),
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
