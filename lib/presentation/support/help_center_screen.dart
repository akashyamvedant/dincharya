import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with TickerProviderStateMixin {
  // App theme colors matching the app
  final Color warmBackground = const Color(0xFFFDF8F3);
  final Color softPeach = const Color(0xFFFAF0E6);
  final Color lightBrown = Color(0xFFD4A574);
  final Color darkBrown = const Color(0xFF2C1810);
  final Color accentBrown = Color(0xFF8B4513);

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _listController;
  late Animation<double> _headerScale;
  late Animation<double> _headerFade;

  // Track expanded FAQ items
  final Set<int> _expandedItems = {};

  // FAQ Data organized by category
  final List<Map<String, dynamic>> _faqCategories = [
    {
      'icon': Icons.rocket_launch,
      'color': Colors.blue,
      'title': 'Getting Started',
      'emoji': '🚀',
      'faqs': [
        {
          'question': 'DinCharya क्या है?',
          'answer': 'DinCharya एक daily routine और habit tracking app है जो आपको disciplined lifestyle जीने में मदद करती है। आप अपनी daily tasks को track कर सकते हैं, reminders set कर सकते हैं, और अपने progress को देख सकते हैं।'
        },
        {
          'question': 'अपनी पहली routine कैसे बनाएं?',
          'answer': 'App खोलें → Profile Selection में जाएं → अपना lifestyle (Student, Working Professional, या Homemaker) चुनें → App automatically आपके लिए एक routine बना देगी जिसे आप customize कर सकते हैं।'
        },
        {
          'question': 'Lifestyle profiles को कैसे switch करें?',
          'answer': 'Me tab → Activity section → "Change Profile" पर tap करें → नया lifestyle चुनें। ध्यान दें कि profile बदलने से आपकी पुरानी tasks reset हो जाएंगी।'
        },
      ],
    },
    {
      'icon': Icons.task_alt,
      'color': Colors.green,
      'title': 'Tasks & Routines',
      'emoji': '✅',
      'faqs': [
        {
          'question': 'Task को complete कैसे mark करें?',
          'answer': 'Home screen पर task card के right side में green checkmark ✓ button पर tap करें। Task complete होने पर card green हो जाएगा।'
        },
        {
          'question': 'अगर कोई task miss हो जाए तो?',
          'answer': 'कोई बात नहीं! Miss हुई task automatically "missed" status में चली जाएगी। आप History tab में अपनी missed tasks देख सकते हैं और अगले दिन फिर से try कर सकते हैं।'
        },
        {
          'question': 'Task को skip कैसे करें?',
          'answer': 'Task card पर ⊘ (skip) button दबाएं → Skip reason select करें → Submit करें। Skip की गई tasks differently track होती हैं।'
        },
        {
          'question': 'Custom task कैसे add करें?',
          'answer': 'Home screen पर + button दबाएं → Task details भरें (name, time, icon) → Save करें। आपका custom task routine में add हो जाएगा।'
        },
      ],
    },
    {
      'icon': Icons.notifications_active,
      'color': Colors.orange,
      'title': 'Notifications',
      'emoji': '🔔',
      'faqs': [
        {
          'question': 'Notifications कैसे enable/disable करें?',
          'answer': 'Me tab → Notifications section → "Task Reminders" toggle को on/off करें।'
        },
        {
          'question': 'Reminders क्यों नहीं आ रहे?',
          'answer': '1. Phone Settings → Apps → DinCharya → Notifications check करें\n2. Battery optimization में app को "Don\'t optimize" करें\n3. App permissions में Notification permission allow करें\n4. Me tab में Task Reminders toggle on होना चाहिए'
        },
        {
          'question': 'Notification timing क्या है?',
          'answer': 'Notifications task start होने से 5 minutes पहले आती हैं ताकि आप time पर prepare हो सकें।'
        },
      ],
    },
    {
      'icon': Icons.cloud_sync,
      'color': Colors.purple,
      'title': 'Account & Sync',
      'emoji': '☁️',
      'faqs': [
        {
          'question': 'Account कैसे बनाएं?',
          'answer': 'Me tab → Sign In button → Email और password से register करें या Google Sign In use करें। Account बनाने के बाद आपका data cloud पर sync होगा।'
        },
        {
          'question': 'क्या data multiple devices पर sync होता है?',
          'answer': 'हां! जब आप logged in हैं, तो आपका data automatically cloud पर save होता है और किसी भी device पर login करके access कर सकते हैं।'
        },
        {
          'question': 'Password कैसे reset करें?',
          'answer': 'Me tab → Account section → "Change Password" → Current password डालें → New password set करें। Password में minimum 8 characters, uppercase, lowercase, number और special character होना चाहिए।'
        },
      ],
    },
    {
      'icon': Icons.workspace_premium,
      'color': Colors.amber,
      'title': 'Subscription',
      'emoji': '👑',
      'faqs': [
        {
          'question': 'Premium में क्या मिलता है?',
          'answer': '• Ad-free experience 🚫\n• Guided meditation sessions 🧘\n• Advanced analytics 📊\n• Priority support 💬\n• Early access to new features 🆕'
        },
        {
          'question': 'Subscription price क्या है?',
          'answer': 'Premium subscription ₹199/month या ₹1999/year (Save 17%) में available है। 7-day free trial भी available है!'
        },
        {
          'question': 'Subscription कैसे cancel करें?',
          'answer': 'Google Play Store → Menu → Subscriptions → DinCharya → Cancel subscription। Cancel करने के बाद भी current billing period तक premium benefits मिलेंगे।'
        },
      ],
    },
    {
      'icon': Icons.build,
      'color': Colors.red,
      'title': 'Troubleshooting',
      'emoji': '🔧',
      'faqs': [
        {
          'question': 'App crash हो रही है, क्या करें?',
          'answer': '1. App को force close करें और restart करें\n2. Phone restart करें\n3. Play Store से app update check करें\n4. Last resort: App uninstall करके reinstall करें (logged in हैं तो data safe रहेगा)'
        },
        {
          'question': 'Tasks load नहीं हो रहे?',
          'answer': '1. Internet connection check करें\n2. App को restart करें\n3. Profile selection में जाकर same profile फिर से select करें'
        },
        {
          'question': 'Support से कैसे contact करें?',
          'answer': 'Me tab → Support & Info → "Contact Support" पर tap करें → Form fill करके submit करें। हम 24-48 hours में respond करेंगे।'
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _headerScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
    );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeIn),
    );
    
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _listController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card (no animation fade)
              _buildHeaderCard(),
              SizedBox(height: 3.h),

              // Quick Category Pills
              _buildQuickCategoryPills(),
              SizedBox(height: 3.h),

              // FAQ Categories (no fade animation)
              ..._faqCategories.asMap().entries.map((entry) {
                final categoryIndex = entry.key;
                final category = entry.value;
                return Column(
                  children: [
                    _buildCategorySection(category, categoryIndex),
                    SizedBox(height: 2.5.h),
                  ],
                );
              }),

              // Footer
              _buildFooter(),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
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
            Colors.blue.withOpacity(0.15),
            Colors.purple.withOpacity(0.15),
            Colors.pink.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated emoji stack
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.withOpacity(0.3), Colors.purple.withOpacity(0.3)],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Text('🙏', style: TextStyle(fontSize: 40)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'हम यहाँ मदद के लिए हैं!',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'नीचे frequently asked questions देखें\nया हमसे directly contact करें',
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

  Widget _buildQuickCategoryPills() {
    return SizedBox(
      height: 5.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _faqCategories.length,
        itemBuilder: (context, index) {
          final category = _faqCategories[index];
          return Container(
            margin: EdgeInsets.only(right: 2.w),
            child: InkWell(
              onTap: () {
                // Scroll to category would be implemented here
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: (category['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (category['color'] as Color).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category['emoji'] as String, style: TextStyle(fontSize: 16)),
                    SizedBox(width: 1.w),
                    Text(
                      category['title'] as String,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: category['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(Map<String, dynamic> category, int categoryIndex) {
    final faqs = category['faqs'] as List;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: (category['color'] as Color).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category Header with gradient
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (category['color'] as Color).withOpacity(0.15),
                  (category['color'] as Color).withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category['color'] as Color,
                        (category['color'] as Color).withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (category['color'] as Color).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    category['icon'] as IconData,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    category['title'] as String,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
                    '${faqs.length} FAQs',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: category['color'] as Color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FAQ Items with animation
          ...faqs.asMap().entries.map((entry) {
            final faqIndex = entry.key;
            final faq = entry.value;
            final globalIndex = categoryIndex * 100 + faqIndex;
            final isExpanded = _expandedItems.contains(globalIndex);
            
            return Column(
              children: [
                if (faqIndex > 0)
                  Divider(height: 1, color: lightBrown.withOpacity(0.15), indent: 4.w, endIndent: 4.w),
                _buildFaqItem(faq, globalIndex, isExpanded, category['color'] as Color),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFaqItem(Map<String, String> faq, int index, bool isExpanded, Color accentColor) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedItems.remove(index);
          } else {
            _expandedItems.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isExpanded ? accentColor.withOpacity(0.05) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    faq['question']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: EdgeInsets.all(1.w),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: EdgeInsets.only(top: 2.h, left: 5.w),
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                         Theme.of(context).colorScheme.surfaceContainerHighest,
                        accentColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withOpacity(0.1)),
                  ),
                  child: Text(
                    faq['answer']!,
                    style: TextStyle(
                      fontSize: 15.sp,
                       color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentBrown.withOpacity(0.15),
            lightBrown.withOpacity(0.1),
            Colors.orange.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accentBrown.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentBrown.withOpacity(0.2), lightBrown.withOpacity(0.2)],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Text('💬', style: TextStyle(fontSize: 35)),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'अभी भी help चाहिए?',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'हमारी team से directly contact करें\nहम 24-48 hours में respond करेंगे',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: darkBrown.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          SizedBox(height: 3.h),
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
              onPressed: () {
                Navigator.pushNamed(context, '/contact-support');
              },
              icon: Icon(Icons.support_agent, size: 24),
              label: Text(
                'Contact Support',
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
    );
  }
}
