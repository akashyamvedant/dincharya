import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../core/utils/validators.dart';
import './widgets/auth_footer_widget.dart';
import './widgets/auth_header_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;
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
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _agreeToTerms &&
        Validators.isValidEmail(_emailController.text) &&
        _passwordController.text == _confirmPasswordController.text;
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _breathingController.repeat(reverse: true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      // Use real Supabase authentication
      final result = await _authService.signUp(
        email: email,
        password: password,
        fullName: name,
      );

      if (result['success'] == true) {
        // Success haptic feedback
        HapticFeedback.lightImpact();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome to DinCharya! Let\'s set up your lifestyle.'),
              backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            ),
          );

          // Navigate to lifestyle selection (new user needs to pick lifestyle)
          Navigator.pushReplacementNamed(context, AppRoutes.profileSelection);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ??
              'Failed to create account. Please try again.';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Network error. Please check your connection and try again.';
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

  Future<void> _handleGoogleSignUp() async {
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

        // Navigate to lifestyle selection (new user)
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.profileSelection);
        }
      } else {
        setState(() {
          _errorMessage =
              result['message'] ?? 'Google sign-up failed. Please try again.';
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-up error. Please try again.';
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
                      onBackPressed: () => Navigator.pop(context),
                      title: 'Create Account',
                      subtitle:
                          'Join DinCharya and start your wellness journey',
                    ),

                    SizedBox(height: 4.h),

                    // Sign Up form
                    Expanded(
                      child: _buildSignUpForm(),
                    ),

                    SizedBox(height: 2.h),

                    // Footer with sign in option
                    AuthFooterWidget(
                      onCreateAccount: null,
                      onSignIn: () => Navigator.pop(context),
                      isSignUp: true,
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

  Widget _buildSignUpForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          _buildInputField(
            controller: _nameController,
            labelText: 'Full Name',
            hintText: 'Enter your full name',
            iconName: 'person',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              if (!Validators.isValidName(value)) {
                return 'Please enter a valid name (letters only)';
              }
              return null;
            },
          ),

          SizedBox(height: 3.h),

          // Email field
          _buildInputField(
            controller: _emailController,
            labelText: 'Email Address',
            hintText: 'Enter your email',
            iconName: 'email',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email address';
              }
              if (!Validators.isValidEmail(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          SizedBox(height: 3.h),

          // Password field
          _buildInputField(
            controller: _passwordController,
            labelText: 'Password',
            hintText: 'Create a password',
            iconName: 'lock',
            isPassword: true,
            isPasswordVisible: _isPasswordVisible,
            onPasswordToggle: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a password';
              }
              if (!Validators.isValidPassword(value)) {
                return 'Password must meet complexity requirements';
              }
              return null;
            },
          ),

          SizedBox(height: 3.h),

          // Confirm Password field
          _buildInputField(
            controller: _confirmPasswordController,
            labelText: 'Confirm Password',
            hintText: 'Confirm your password',
            iconName: 'lock',
            isPassword: true,
            isPasswordVisible: _isConfirmPasswordVisible,
            onPasswordToggle: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          SizedBox(height: 2.h),

          // Terms and conditions
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: _agreeToTerms,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _agreeToTerms = value ?? false;
                          });
                        },
                  activeColor: AppTheme.lightTheme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: 'I agree to the ',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms of Service',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' and ',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.error
                      .withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.lightTheme.colorScheme.error,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
          ],

          // Sign up button
          AnimatedBuilder(
            animation: _breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isLoading ? _breathingAnimation.value : 1.0,
                child: Container(
                  height: 7.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: _isFormValid && !_isLoading
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.lightTheme.colorScheme.primary,
                              AppTheme.lightTheme.colorScheme.secondary,
                            ],
                          )
                        : null,
                    color: !_isFormValid || _isLoading
                        ? AppTheme.lightTheme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3)
                        : null,
                    boxShadow: _isFormValid && !_isLoading
                        ? [
                            BoxShadow(
                              color: AppTheme.lightTheme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed:
                        (_isFormValid && !_isLoading) ? _handleSignUp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor:
                          AppTheme.lightTheme.colorScheme.onPrimary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 5.w,
                                height: 5.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.lightTheme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Creating Account...',
                                style: AppTheme.lightTheme.textTheme.titleMedium
                                    ?.copyWith(
                                  color:
                                      AppTheme.lightTheme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            'Create Account',
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 3.h),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.3),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: Text(
                  'OR',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.3),
                  thickness: 1,
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Google Sign Up button
          SizedBox(
            height: 7.h,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignUp,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: AppTheme.lightTheme.colorScheme.surface,
              ),
              icon: GoogleIconWidget(
                size: 24,
              ),
              label: Text(
                'Continue with Google',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required String iconName,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onPasswordToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? !isPasswordVisible : false,
        enabled: !_isLoading,
        style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
          color: AppTheme.lightTheme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          filled: true,
          fillColor: AppTheme.lightTheme.colorScheme.surface,
          prefixIcon: Padding(
            padding: EdgeInsets.all(3.w),
            child: CustomIconWidget(
              iconName: iconName,
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 20,
            ),
          ),
          suffixIcon: isPassword && onPasswordToggle != null
              ? GestureDetector(
                  onTap: onPasswordToggle,
                  child: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: CustomIconWidget(
                      iconName:
                          isPasswordVisible ? 'visibility_off' : 'visibility',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.lightTheme.colorScheme.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.lightTheme.colorScheme.error,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.lightTheme.colorScheme.error,
              width: 2,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }
}
