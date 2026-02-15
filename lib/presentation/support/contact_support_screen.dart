import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../services/supabase_service.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> with TickerProviderStateMixin {
  // App theme colors
  final Color warmBackground = const Color(0xFFFDF8F3);
  final Color softPeach = const Color(0xFFFAF0E6);
  final Color lightBrown = const Color(0xFFD4A574);
  final Color darkBrown = const Color(0xFF2C1810);
  final Color accentBrown = const Color(0xFF8B4513);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  final SupabaseService _supabaseService = SupabaseService();
  
  String _selectedCategory = 'General';
  bool _isSubmitting = false;
  bool _isSuccess = false;

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _formController;
  late AnimationController _successController;
  late Animation<double> _headerScale;
  late Animation<double> _successScale;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'General', 'label': 'General Inquiry', 'icon': Icons.help, 'color': Colors.blue, 'emoji': '❓'},
    {'value': 'Bug', 'label': 'Bug Report', 'icon': Icons.bug_report, 'color': Colors.red, 'emoji': '🐛'},
    {'value': 'Feature', 'label': 'Feature Request', 'icon': Icons.lightbulb, 'color': Colors.amber, 'emoji': '✨'},
    {'value': 'Account', 'label': 'Account Issue', 'icon': Icons.person, 'color': Colors.purple, 'emoji': '👤'},
    {'value': 'Subscription', 'label': 'Subscription Help', 'icon': Icons.credit_card, 'color': Colors.green, 'emoji': '💳'},
    {'value': 'Other', 'label': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey, 'emoji': '📝'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _initAnimations();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _formController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
    );
    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _formController.forward();
    });
  }

  void _loadUserEmail() {
    final user = _supabaseService.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    _headerController.dispose();
    _formController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final client = await _supabaseService.client;
      if (client != null) {
        await client.from('support_tickets').insert({
          'user_id': _supabaseService.currentUser?.id,
          'email': _emailController.text.trim(),
          'category': _selectedCategory,
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        });

        setState(() {
          _isSuccess = true;
          _isSubmitting = false;
        });
        _successController.forward();
      } else {
        _showEmailFallback();
      }
    } catch (e) {
      debugPrint('Error submitting ticket: $e');
      _showEmailFallback();
    }
  }

  void _showEmailFallback() {
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            SizedBox(width: 2.w),
            Expanded(
              child: Text('कृपया email से संपर्क करें: akashyam10@gmail.com', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warmBackground,
      appBar: AppBar(
        backgroundColor: softPeach,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkBrown, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Support',
          style: TextStyle(
            color: darkBrown,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSuccess ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildMyTicketsButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/my-tickets'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentBrown.withOpacity(0.12), lightBrown.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentBrown.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: accentBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.confirmation_num_rounded, color: accentBrown, size: 22),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Tickets',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  Text(
                    'अपने tickets का status देखें',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: darkBrown.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accentBrown.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        return Transform.scale(
          scale: _successScale.value,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(6.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated success icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.2),
                              Colors.teal.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.teal],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(Icons.check, size: 50, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  
                  Text(
                    'धन्यवाद! 🙏',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: darkBrown,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  
                  Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'आपका message successfully submit हो गया!',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: darkBrown,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.access_time, color: Colors.green, size: 20),
                            SizedBox(width: 1.w),
                            Text(
                              'हम 24-48 hours में respond करेंगे',
                              style: TextStyle(
                                fontSize: 15.sp,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 5.h),
                  
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentBrown, Color(0xFFA0522D)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accentBrown.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, size: 22),
                      label: Text(
                        'Back to Settings',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card (no animation fade during scroll)
              _buildHeaderCard(),
              SizedBox(height: 3.h),

              // Form fields (no staggered animation)
              _buildSection('Category चुनें', _buildCategorySelector()),
              SizedBox(height: 3.h),
              _buildSection('Email Address', _buildEmailField()),
              SizedBox(height: 3.h),
              _buildSection('Subject', _buildSubjectField()),
              SizedBox(height: 3.h),
              _buildSection('Your Message', _buildMessageField()),
              SizedBox(height: 4.h),
              _buildSubmitButton(),
              SizedBox(height: 3.h),
              // My Tickets button
              _buildMyTicketsButton(),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
            color: darkBrown,
          ),
        ),
        SizedBox(height: 1.5.h),
        child,
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.15),
            Colors.blue.withOpacity(0.15),
            Colors.pink.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Text('💬', style: TextStyle(fontSize: 40)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'हमसे संपर्क करें',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'कोई भी सवाल या feedback हो,\nनीचे form fill करें',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: darkBrown.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: lightBrown.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final isSelected = _selectedCategory == category['value'];
          
          return Column(
            children: [
              InkWell(
                onTap: () => setState(() => _selectedCategory = category['value']),
                borderRadius: BorderRadius.circular(index == 0 ? 16 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              (category['color'] as Color).withOpacity(0.15),
                              (category['color'] as Color).withOpacity(0.05),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(index == 0 ? 16 : 0),
                      topRight: Radius.circular(index == 0 ? 16 : 0),
                      bottomLeft: Radius.circular(index == _categories.length - 1 ? 16 : 0),
                      bottomRight: Radius.circular(index == _categories.length - 1 ? 16 : 0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(category['emoji'] as String, style: TextStyle(fontSize: 22)),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          category['label'] as String,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? category['color'] as Color : darkBrown,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 28 : 24,
                        height: isSelected ? 28 : 24,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? category['color'] as Color 
                              : Colors.grey.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (index < _categories.length - 1)
                Divider(height: 1, color: lightBrown.withOpacity(0.1), indent: 15.w),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(fontSize: 16.sp, color: darkBrown),
      decoration: InputDecoration(
        hintText: 'आपका email address',
        hintStyle: TextStyle(color: darkBrown.withOpacity(0.4), fontSize: 15.sp),
        prefixIcon: Container(
          margin: EdgeInsets.all(2.w),
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: accentBrown.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.email, color: accentBrown, size: 22),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightBrown.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentBrown, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildSubjectField() {
    return TextFormField(
      controller: _subjectController,
      style: TextStyle(fontSize: 16.sp, color: darkBrown),
      decoration: InputDecoration(
        hintText: 'विषय लिखें (e.g., App not opening)',
        hintStyle: TextStyle(color: darkBrown.withOpacity(0.4), fontSize: 15.sp),
        prefixIcon: Container(
          margin: EdgeInsets.all(2.w),
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.subject, color: Colors.blue, size: 22),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightBrown.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentBrown, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a subject';
        }
        return null;
      },
    );
  }

  Widget _buildMessageField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: lightBrown.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextFormField(
        controller: _messageController,
        maxLines: 8,
        cursorColor: Colors.white,
        style: TextStyle(
          fontSize: 16.sp, 
          color: Colors.white, // White text for visibility
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'अपना message यहाँ लिखें...\n\n💡 जितना detail दे सकें उतना अच्छा!',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14.sp, height: 1.6),
          contentPadding: EdgeInsets.all(4.w),
          border: InputBorder.none,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your message';
          }
          if (value.length < 10) {
            return 'Please provide more details (min 10 characters)';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isSubmitting 
              ? [Colors.grey, Colors.grey.shade600]
              : [accentBrown, Color(0xFFA0522D), Colors.orange.shade800],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isSubmitting ? [] : [
          BoxShadow(
            color: accentBrown.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitTicket,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 2.5.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Submitting...',
                    style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 24),
                  SizedBox(width: 2.w),
                  Text(
                    'Submit Message',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 2.w),
                  Text('🚀', style: TextStyle(fontSize: 20)),
                ],
              ),
      ),
    );
  }
}
