import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../core/utils/validators.dart';

class AuthFormWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool isLoading;
  final bool rememberMe;
  final String? errorMessage;
  final bool isFormValid;
  final Animation<double> breathingAnimation;
  final VoidCallback onPasswordVisibilityToggle;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;

  const AuthFormWidget({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.isLoading,
    required this.rememberMe,
    required this.errorMessage,
    required this.isFormValid,
    required this.breathingAnimation,
    required this.onPasswordVisibilityToggle,
    required this.onRememberMeChanged,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lightTheme.colorScheme.shadow
                      .withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: true,
              enabled: !isLoading,
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'Enter your email',
                filled: true,
                fillColor: AppTheme.lightTheme.colorScheme.surface,
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'email',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                ),
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
          ),

          SizedBox(height: 3.h),

          // Password field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lightTheme.colorScheme.shadow
                      .withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              textInputAction: TextInputAction.done,
              enabled: !isLoading,
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                filled: true,
                fillColor: AppTheme.lightTheme.colorScheme.surface,
                prefixIcon: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: 'lock',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                suffixIcon: GestureDetector(
                  onTap: onPasswordVisibilityToggle,
                  child: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: CustomIconWidget(
                      iconName:
                          isPasswordVisible ? 'visibility_off' : 'visibility',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (!Validators.isValidPassword(value)) {
                  return 'Password must meet complexity requirements';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (isFormValid && !isLoading) {
                  onSignIn();
                }
              },
            ),
          ),

          SizedBox(height: 2.h),

          // Remember me and forgot password row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: Checkbox(
                        value: rememberMe,
                        onChanged: isLoading ? null : onRememberMeChanged,
                        activeColor: AppTheme.lightTheme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        'Remember me',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color:
                              AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onForgotPassword,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                ),
                child: Text(
                  'Forgot Password?',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          // Error message
          if (errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.error
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.error
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'error_outline',
                    color: AppTheme.lightTheme.colorScheme.error,
                    size: 20,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 3.h),
          ],

          // Sign in button
          AnimatedBuilder(
            animation: breathingAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isLoading ? breathingAnimation.value : 1.0,
                child: Container(
                  height: 7.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isFormValid && !isLoading
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.lightTheme.colorScheme.primary,
                              AppTheme.lightTheme.colorScheme.secondary,
                            ],
                          )
                        : null,
                    color: !isFormValid || isLoading
                        ? AppTheme.lightTheme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3)
                        : null,
                    boxShadow: isFormValid && !isLoading
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
                    onPressed: (isFormValid && !isLoading) ? onSignIn : null,
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
                    child: isLoading
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
                                'Signing In...',
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
                            'Sign In',
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

          // Google Sign In button
          SizedBox(
            height: 6.h,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onGoogleSignIn,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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

          SizedBox(height: 2.h),
        ],
      ),
    );
  }
}
