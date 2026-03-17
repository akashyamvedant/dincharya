import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AuthFooterWidget extends StatelessWidget {
  final VoidCallback? onCreateAccount;
  final VoidCallback? onSignIn;
  final bool isSignUp;

  const AuthFooterWidget({
    super.key,
    this.onCreateAccount,
    this.onSignIn,
    this.isSignUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Text(
                'OR',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
            ),
          ],
        ),

        SizedBox(height: 3.h),

        // Create account or sign in section
        if (!isSignUp && onCreateAccount != null) ...[
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'New to DinCharya?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: OutlinedButton(
                    onPressed: onCreateAccount,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomIconWidget(
                          iconName: 'person_add',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Create Account',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (isSignUp && onSignIn != null) ...[
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Already have an account?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: OutlinedButton(
                    onPressed: onSignIn,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomIconWidget(
                          iconName: 'person',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'Sign In',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 2.h),

        // Help text
        Text(
          'By continuing, you agree to our Terms of Service\nand Privacy Policy',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
