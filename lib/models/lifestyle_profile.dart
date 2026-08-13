/// Lifestyle Profile Model for Dincharya App
/// 
/// Represents different lifestyle types with their default routines
/// and preferences for time blocks, activities, and seasonal adaptations.
library;

class LifestyleProfile {
  final String id;
  final String name;
  final String nameHindi;
  final String description;
  final String icon;
  final String wakeTime;
  final String sleepTime;
  final List<String> focusAreas;
  final Map<String, dynamic> defaultRoutine;
  final bool isCustom;

  const LifestyleProfile({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.description,
    required this.icon,
    required this.wakeTime,
    required this.sleepTime,
    required this.focusAreas,
    required this.defaultRoutine,
    this.isCustom = false,
  });

  /// Predefined Lifestyle Profiles
  static const List<LifestyleProfile> presets = [
    yogic,
    student,
    professional,
    homemaker,
  ];

  /// 🧘 Yogic Lifestyle - Brahmacharya Focus
  static const LifestyleProfile yogic = LifestyleProfile(
    id: 'yogic',
    name: 'Yogic Lifestyle',
    nameHindi: 'योगी जीवनशैली',
    description: 'Brahma Muhurta wake up, full pranayam & asana practice, minimal technology',
    icon: 'self_improvement',
    wakeTime: '03:00',
    sleepTime: '22:00',
    focusAreas: ['meditation', 'pranayam', 'asana', 'swadhyay', 'puja'],
    defaultRoutine: {
      'brahma_muhurta': [
        {'time': '03:00', 'activity': 'Jagran', 'duration': 5, 'category': 'dainik'},
        {'time': '03:10', 'activity': 'Shauch & Fresh', 'duration': 20, 'category': 'dainik'},
        {'time': '03:30', 'activity': 'Dhyan', 'duration': 60, 'category': 'adhyatmik'},
        {'time': '04:30', 'activity': 'Pranayam', 'duration': 30, 'category': 'adhyatmik'},
        {'time': '05:00', 'activity': 'Asana Abhyas', 'duration': 30, 'category': 'sharirik'},
      ],
      'pratah': [
        {'time': '05:30', 'activity': 'Bhigoye Chane/Dry Fruits', 'duration': 10, 'category': 'dainik'},
        {'time': '05:45', 'activity': 'Walking & Running', 'duration': 45, 'category': 'sharirik'},
        {'time': '06:30', 'activity': 'Vyayam', 'duration': 30, 'category': 'sharirik'},
        {'time': '07:00', 'activity': 'Snan', 'duration': 30, 'category': 'dainik'},
        {'time': '07:30', 'activity': 'Puja Path', 'duration': 20, 'category': 'adhyatmik'},
        {'time': '08:00', 'activity': 'Bhagavad Gita Paath', 'duration': 30, 'category': 'adhyatmik'},
      ],
      'madhyahna': [
        {'time': '12:00', 'activity': 'Madhyahna Dhyan', 'duration': 30, 'category': 'adhyatmik'},
      ],
      'sandhya': [
        {'time': '16:00', 'activity': 'Sandhya Walking', 'duration': 30, 'category': 'sharirik'},
        {'time': '16:30', 'activity': 'Khel', 'duration': 90, 'category': 'sharirik'},
        {'time': '19:00', 'activity': 'Adhyayan', 'duration': 60, 'category': 'manasik'},
        {'time': '20:30', 'activity': 'Ratri Dhyan', 'duration': 30, 'category': 'adhyatmik'},
      ],
    },
  );

  /// 📚 Student Lifestyle
  static const LifestyleProfile student = LifestyleProfile(
    id: 'student',
    name: 'Student Life',
    nameHindi: 'विद्यार्थी जीवन',
    description: 'Study-focused with flexible morning, evening study sessions, quick exercises',
    icon: 'school',
    wakeTime: '05:30',
    sleepTime: '23:00',
    focusAreas: ['study', 'meditation', 'exercise', 'goal_setting'],
    defaultRoutine: {
      'pratah': [
        {'time': '05:30', 'activity': 'Jagran & Fresh', 'duration': 30, 'category': 'dainik'},
        {'time': '06:00', 'activity': 'Quick Meditation', 'duration': 15, 'category': 'adhyatmik'},
        {'time': '06:15', 'activity': 'Light Exercise', 'duration': 20, 'category': 'sharirik'},
        {'time': '06:45', 'activity': 'Morning Study', 'duration': 60, 'category': 'manasik'},
        {'time': '08:00', 'activity': 'Breakfast', 'duration': 30, 'category': 'dainik'},
      ],
      'madhyahna': [
        {'time': '12:30', 'activity': 'Lunch Break', 'duration': 45, 'category': 'dainik'},
        {'time': '13:15', 'activity': 'Power Nap', 'duration': 20, 'category': 'dainik'},
      ],
      'sandhya': [
        {'time': '17:00', 'activity': 'Sports/Exercise', 'duration': 60, 'category': 'sharirik'},
        {'time': '18:30', 'activity': 'Evening Study', 'duration': 120, 'category': 'manasik'},
        {'time': '21:00', 'activity': 'Revision & Planning', 'duration': 45, 'category': 'manasik'},
        {'time': '22:00', 'activity': 'Night Meditation', 'duration': 15, 'category': 'adhyatmik'},
      ],
    },
  );

  /// 💼 Working Professional
  static const LifestyleProfile professional = LifestyleProfile(
    id: 'professional',
    name: 'Working Professional',
    nameHindi: 'कार्यरत व्यक्ति',
    description: 'Office-compatible routines, micro-meditations, weekend longer sessions',
    icon: 'work',
    wakeTime: '06:00',
    sleepTime: '22:30',
    focusAreas: ['productivity', 'stress_relief', 'quick_meditation', 'evening_exercise'],
    defaultRoutine: {
      'pratah': [
        {'time': '06:00', 'activity': 'Wake Up & Fresh', 'duration': 30, 'category': 'dainik'},
        {'time': '06:30', 'activity': 'Morning Meditation', 'duration': 15, 'category': 'adhyatmik'},
        {'time': '06:45', 'activity': 'Quick Yoga', 'duration': 15, 'category': 'sharirik'},
        {'time': '07:00', 'activity': 'Exercise/Running', 'duration': 30, 'category': 'sharirik'},
        {'time': '07:30', 'activity': 'Breakfast & Ready', 'duration': 45, 'category': 'dainik'},
      ],
      'madhyahna': [
        {'time': '12:30', 'activity': 'Lunch Break', 'duration': 30, 'category': 'dainik'},
        {'time': '13:00', 'activity': 'Micro Meditation', 'duration': 10, 'category': 'adhyatmik'},
      ],
      'sandhya': [
        {'time': '18:30', 'activity': 'Evening Walk', 'duration': 30, 'category': 'sharirik'},
        {'time': '19:00', 'activity': 'Family Time', 'duration': 60, 'category': 'dainik'},
        {'time': '20:30', 'activity': 'Reading/Learning', 'duration': 45, 'category': 'manasik'},
        {'time': '21:30', 'activity': 'Night Meditation', 'duration': 15, 'category': 'adhyatmik'},
      ],
    },
  );

  /// 🏠 Homemaker
  static const LifestyleProfile homemaker = LifestyleProfile(
    id: 'homemaker',
    name: 'Homemaker',
    nameHindi: 'गृहस्थ जीवन',
    description: 'Family-oriented schedule, micro-meditations, practical timing',
    icon: 'home',
    wakeTime: '05:30',
    sleepTime: '22:00',
    focusAreas: ['puja', 'family_wellness', 'micro_meditation', 'evening_relaxation'],
    defaultRoutine: {
      'pratah': [
        {'time': '05:30', 'activity': 'Wake Up', 'duration': 15, 'category': 'dainik'},
        {'time': '05:45', 'activity': 'Morning Puja', 'duration': 20, 'category': 'adhyatmik'},
        {'time': '06:15', 'activity': 'Light Yoga', 'duration': 20, 'category': 'sharirik'},
        {'time': '07:00', 'activity': 'Family Breakfast', 'duration': 60, 'category': 'dainik'},
      ],
      'madhyahna': [
        {'time': '11:00', 'activity': 'Micro Meditation', 'duration': 10, 'category': 'adhyatmik'},
        {'time': '14:00', 'activity': 'Afternoon Rest', 'duration': 30, 'category': 'dainik'},
      ],
      'sandhya': [
        {'time': '17:00', 'activity': 'Evening Walk', 'duration': 30, 'category': 'sharirik'},
        {'time': '18:00', 'activity': 'Sandhya Puja', 'duration': 15, 'category': 'adhyatmik'},
        {'time': '20:00', 'activity': 'Satsang/Reading', 'duration': 30, 'category': 'adhyatmik'},
        {'time': '21:00', 'activity': 'Night Relaxation', 'duration': 15, 'category': 'adhyatmik'},
      ],
    },
  );

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_hindi': nameHindi,
      'description': description,
      'icon': icon,
      'wake_time': wakeTime,
      'sleep_time': sleepTime,
      'focus_areas': focusAreas,
      'default_routine': defaultRoutine,
      'is_custom': isCustom,
    };
  }

  /// Create from JSON
  factory LifestyleProfile.fromJson(Map<String, dynamic> json) {
    return LifestyleProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameHindi: json['name_hindi'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'person',
      wakeTime: json['wake_time'] ?? '06:00',
      sleepTime: json['sleep_time'] ?? '22:00',
      focusAreas: List<String>.from(json['focus_areas'] ?? []),
      defaultRoutine: json['default_routine'] ?? {},
      isCustom: json['is_custom'] ?? false,
    );
  }
}

/// Activity Category Enum
enum ActivityCategory {
  adhyatmik('Adhyatmik', 'आध्यात्मिक', 'Spiritual', 'self_improvement'),
  sharirik('Sharirik', 'शारीरिक', 'Physical', 'fitness_center'),
  manasik('Manasik', 'मानसिक', 'Mental', 'psychology'),
  dainik('Dainik', 'दैनिक', 'Daily', 'today');

  final String name;
  final String nameHindi;
  final String description;
  final String icon;

  const ActivityCategory(this.name, this.nameHindi, this.description, this.icon);
}

/// Prahar (Time Block) Definition
class Prahar {
  final String id;
  final String name;
  final String nameHindi;
  final String startTime;
  final String endTime;
  final String icon;
  final String description;

  const Prahar({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.startTime,
    required this.endTime,
    required this.icon,
    required this.description,
  });

  static const List<Prahar> all = [
    brahmaMuhurta,
    pratah,
    purvahna,
    madhyahna,
    aparahna,
    sandhya,
    ratri,
  ];

  static const Prahar brahmaMuhurta = Prahar(
    id: 'brahma_muhurta',
    name: 'Brahma Muhurta',
    nameHindi: 'ब्रह्म मुहूर्त',
    startTime: '03:00',
    endTime: '05:30',
    icon: 'dark_mode',
    description: 'Divine time for meditation and spiritual practice',
  );

  static const Prahar pratah = Prahar(
    id: 'pratah',
    name: 'Pratah Kaal',
    nameHindi: 'प्रातः काल',
    startTime: '05:30',
    endTime: '08:00',
    icon: 'wb_twilight',
    description: 'Morning time for exercise and daily preparation',
  );

  static const Prahar purvahna = Prahar(
    id: 'purvahna',
    name: 'Purvahna',
    nameHindi: 'पूर्वाह्न',
    startTime: '08:00',
    endTime: '12:00',
    icon: 'wb_sunny',
    description: 'Forenoon - productive work time',
  );

  static const Prahar madhyahna = Prahar(
    id: 'madhyahna',
    name: 'Madhyahna',
    nameHindi: 'मध्याह्न',
    startTime: '12:00',
    endTime: '16:00',
    icon: 'light_mode',
    description: 'Midday - lunch and afternoon activities',
  );

  static const Prahar aparahna = Prahar(
    id: 'aparahna',
    name: 'Aparahna',
    nameHindi: 'अपराह्न',
    startTime: '16:00',
    endTime: '18:00',
    icon: 'wb_twilight',
    description: 'Afternoon - transition time',
  );

  static const Prahar sandhya = Prahar(
    id: 'sandhya',
    name: 'Sandhya Kaal',
    nameHindi: 'सन्ध्या काल',
    startTime: '18:00',
    endTime: '20:00',
    icon: 'nights_stay',
    description: 'Evening - relaxation and family time',
  );

  static const Prahar ratri = Prahar(
    id: 'ratri',
    name: 'Ratri',
    nameHindi: 'रात्रि',
    startTime: '20:00',
    endTime: '22:00',
    icon: 'bedtime',
    description: 'Night - wind down and sleep preparation',
  );

  /// Get current Prahar based on time
  static Prahar getCurrentPrahar() {
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    for (final prahar in all) {
      if (_isTimeBetween(currentTime, prahar.startTime, prahar.endTime)) {
        return prahar;
      }
    }
    return ratri; // Default to night if outside all ranges
  }

  static bool _isTimeBetween(String current, String start, String end) {
    return current.compareTo(start) >= 0 && current.compareTo(end) < 0;
  }
}
