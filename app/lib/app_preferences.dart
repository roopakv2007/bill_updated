import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UiPalette {
  const UiPalette({
    required this.canvas,
    required this.surface,
    required this.inset,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.teal,
    required this.gold,
    required this.leaf,
    required this.navIndicator,
    required this.isDark,
  });

  final Color canvas, surface, inset, border, ink, muted;
  final Color accent, teal, gold, leaf, navIndicator;
  final bool isDark;
}

const _appleLight = UiPalette(
  canvas: Color(0xFFF7F8FA),
  surface: Color(0xFFFFFFFF),
  inset: Color(0xFFF0F1F4),
  border: Color(0xFFE1E3E8),
  ink: Color(0xFF1D1D1F),
  muted: Color(0xFF6E6E73),
  accent: Color(0xFF0071E3),
  teal: Color(0xFF168A8A),
  gold: Color(0xFFC58A19),
  leaf: Color(0xFF438B5B),
  navIndicator: Color(0xFFE5F1FF),
  isDark: false,
);

const _atelierLinen = UiPalette(
  canvas: Color(0xFFFBF9F5),
  surface: Color(0xFFFFFFFF),
  inset: Color(0xFFF5F1E9),
  border: Color(0xFFE7E2D8),
  ink: Color(0xFF141B2D),
  muted: Color(0xFF6F7785),
  accent: Color(0xFFD9381E),
  teal: Color(0xFF238C87),
  gold: Color(0xFFD3A343),
  leaf: Color(0xFF75A66A),
  navIndicator: Color(0xFFFBE5DF),
  isDark: false,
);

const _midnight = UiPalette(
  canvas: Color(0xFF111318),
  surface: Color(0xFF1B1E25),
  inset: Color(0xFF252A33),
  border: Color(0xFF373D49),
  ink: Color(0xFFF4F5F7),
  muted: Color(0xFFA7ACB6),
  accent: Color(0xFF6EA8FE),
  teal: Color(0xFF62C9BA),
  gold: Color(0xFFF4C76B),
  leaf: Color(0xFF90C98A),
  navIndicator: Color(0xFF26364C),
  isDark: true,
);

class AppPreferences extends ChangeNotifier {
  String _language = 'en';
  String _theme = 'apple';
  String _defaultFileType = 'image';

  bool get isTamil => _language == 'ta';
  String get language => _language;
  String get theme => _theme;
  String get defaultFileType => _defaultFileType;
  UiPalette get palette => switch (_theme) {
    'linen' => _atelierLinen,
    'midnight' => _midnight,
    _ => _appleLight,
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('gm_language') ?? 'en';
    _theme = prefs.getString('gm_theme') ?? 'apple';
    _defaultFileType = prefs.getString('gm_default_file_type') ?? 'image';
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _language = language == 'ta' ? 'ta' : 'en';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gm_language', _language);
    notifyListeners();
  }

  Future<void> setTheme(String theme) async {
    _theme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gm_theme', theme);
    notifyListeners();
  }

  Future<void> setDefaultFileType(String type) async {
    _defaultFileType = type == 'pdf' ? 'pdf' : 'image';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gm_default_file_type', _defaultFileType);
    notifyListeners();
  }
}

final appPreferences = AppPreferences();
UiPalette get appPalette => appPreferences.palette;
Color get ledgerCanvas => appPalette.canvas;
Color get ledgerSurface => appPalette.surface;
Color get ledgerInset => appPalette.inset;
Color get ledgerBorder => appPalette.border;
Color get ledgerInk => appPalette.ink;
Color get ledgerMuted => appPalette.muted;
Color get vermilion => appPalette.accent;
Color get ledgerTeal => appPalette.teal;
Color get ledgerGold => appPalette.gold;
Color get ledgerLeaf => appPalette.leaf;

String tx(String english) {
  if (!appPreferences.isTamil) return english;
  final weekMatch = RegExp(r'^Week (\d+)$').firstMatch(english);
  if (weekMatch != null) return 'வாரம் ${weekMatch.group(1)}';
  return _tamilTranslations[english] ?? english;
}

const _tamilTranslations = <String, String>{
  'Home': 'முகப்பு',
  'History': 'வரலாறு',
  'Analysis': 'பகுப்பாய்வு',
  'Settings': 'அமைப்புகள்',
  'New bill': 'புதிய பில்',
  'THE LEDGER': 'வரவு பதிவேடு',
  'GM TAILORS': 'ஜி.எம். டெய்லர்ஸ்',
  'Your business, well measured.': 'உங்கள் வணிகம், துல்லியமாக.',
  'Income recorded': 'பதிவு செய்த வருமானம்',
  'records this month': 'இந்த மாத பதிவுகள்',
  'manual': 'கைமுறை',
  'Create bill': 'பில் உருவாக்கு',
  'Build an invoice': 'விலைப்பட்டியல் உருவாக்கு',
  'Add income': 'வருமானம் சேர்',
  'Record without a bill': 'பில் இல்லாமல் பதிவு செய்',
  'Recent activity': 'சமீபத்திய செயல்பாடுகள்',
  'A running record of your shop': 'உங்கள் கடையின் தொடர்ச்சியான பதிவு',
  'View all': 'அனைத்தையும் காண்க',
  'Your saved bills and income will appear here.':
      'சேமித்த பில்களும் வருமானமும் இங்கே தோன்றும்.',
  'Bills & income': 'பில்கள் மற்றும் வருமானம்',
  'Every transaction, in one place.': 'அனைத்து பரிவர்த்தனைகளும் ஒரே இடத்தில்.',
  'RECORDS': 'பதிவுகள்',
  'ALL TIME': 'மொத்தம்',
  'Search name or phone': 'பெயர் அல்லது தொலைபேசி தேடு',
  'All records': 'அனைத்து பதிவுகள்',
  'Manual income': 'கைமுறை வருமானம்',
  'shown': 'காட்டப்படுகிறது',
  'No matching bills yet.': 'பொருந்தும் பில்கள் இல்லை.',
  'Business overview': 'வணிக கண்ணோட்டம்',
  'MONTHLY INCOME': 'மாத வருமானம்',
  'New this month': 'இந்த மாதம் புதியது',
  'No change yet': 'இன்னும் மாற்றம் இல்லை',
  'vs last month': 'கடந்த மாதத்துடன் ஒப்பிடுக',
  'GENERATED BILLS': 'உருவாக்கிய பில்கள்',
  'MANUAL INCOME': 'கைமுறை வருமானம்',
  'BILLS THIS MONTH': 'இந்த மாத பில்கள்',
  'AVERAGE RECORD': 'சராசரி பதிவு',
  'Income rhythm': 'வருமான போக்கு',
  'Month': 'மாதம்',
  'Week': 'வாரம்',
  'Daily income': 'தினசரி வருமானம்',
  'Week by week': 'வாரம் வாரமாக',
  'Where income comes from': 'வருமானப் பிரிவு',
  'Income by item & entry type': 'பொருள் மற்றும் பதிவு வகை வருமானம்',
  'No income recorded for this month':
      'இந்த மாதம் வருமானம் பதிவு செய்யப்படவில்லை',
  'Six month trend': 'ஆறு மாத போக்கு',
  'Record new income': 'புதிய வருமானம் பதிவு செய்',
  'Generated bills': 'உருவாக்கிய பில்கள்',
  'Other': 'மற்றவை',
  'YOUR WORKSPACE': 'உங்கள் பணியிடம்',
  'Your shop details and app preferences.':
      'கடை விவரங்கள் மற்றும் செயலி விருப்பங்கள்.',
  'Morai, Chennai': 'மொரை, சென்னை',
  'Language': 'மொழி',
  'English': 'ஆங்கிலம்',
  'Tamil': 'தமிழ்',
  'App language': 'செயலி மொழி',
  'Change every screen to English or Tamil':
      'அனைத்து திரைகளையும் ஆங்கிலம் அல்லது தமிழாக மாற்றவும்',
  'Appearance': 'தோற்றம்',
  'Choose a color theme': 'வண்ணத் தீமைத் தேர்ந்தெடுக்கவும்',
  'Apple Light': 'ஆப்பிள் லைட்',
  'Atelier Linen': 'அட்லியர் லினன்',
  'Midnight Ledger': 'மிட்நைட் பதிவேடு',
  'Default bill file': 'இயல்புநிலை பில் கோப்பு',
  'Choose the default format for download and share': 'பதிவிறக்கம் மற்றும் பகிர்வுக்கான இயல்புநிலை வடிவத்தைத் தேர்ந்தெடுக்கவும்',
  'Image': 'படம்',
  'PDF': 'பிடிஎஃப்',
  'Restore defaults': 'இயல்புநிலைக்கு மீட்டமை',
  'Close': 'மூடு',
  'Print bill': 'பில்லை அச்சிடு',
  'Share bill': 'பில்லைப் பகிர்',
  'Could not save bill': 'பில்லைச் சேமிக்க முடியவில்லை',
  'Could not share bill': 'பில்லைப் பகிர முடியவில்லை',
  'Shop details': 'கடை விவரங்கள்',
  'Open shop details': 'கடை விவரங்களைத் திற',
  'Save preferences': 'விருப்பங்களைச் சேமி',
  'Your bill records': 'உங்கள் பில் பதிவுகள்',
  'Saved on this device and available in History':
      'இந்த சாதனத்தில் சேமிக்கப்பட்டு வரலாற்றில் கிடைக்கும்',
  'Bill template': 'பில் வடிவம்',
  'Original GM Tailors invoice layout is preserved':
      'அசல் ஜி.எம். டெய்லர்ஸ் பில் வடிவம் பாதுகாக்கப்பட்டுள்ளது',
  'Invoice language': 'பில் மொழி',
  'Choose English or Tamil when creating each bill': 'ஒவ்வொரு பில் உருவாக்கும் போதும் ஆங்கிலம் அல்லது தமிழைத் தேர்ந்தெடுக்கவும்',
  'Bills & business overview': 'பில்கள் மற்றும் வணிக கண்ணோட்டம்',
  'Bill preview': 'பில் முன்னோட்டம்',
  'Edit bill': 'பில்லைத் திருத்து',
  'Download': 'பதிவிறக்கு',
  'Share': 'பகிர்',
  'Save image': 'படத்தைச் சேமி',
  'Share image': 'படத்தைப் பகிர்',
  'Save PDF': 'PDF-ஐச் சேமி',
  'Share PDF': 'PDF-ஐப் பகிர்',
  'Saved to files': 'கோப்புகளில் சேமிக்கப்பட்டது',
  'Edit invoice': 'விலைப்பட்டியலைத் திருத்து',
  'Create invoice': 'விலைப்பட்டியல் உருவாக்கு',
  'Customer details': 'வாடிக்கையாளர் விவரங்கள்',
  'Income details': 'வருமான விவரங்கள்',
  'Items': 'பொருட்கள்',
  'Customer name': 'வாடிக்கையாளர் பெயர்',
  'Phone number (optional)': 'தொலைபேசி எண் (விருப்பம்)',
  'Name / source (optional)': 'பெயர் / மூலம் (விருப்பம்)',
  'Amount (₹)': 'தொகை (₹)',
  'Note': 'குறிப்பு',
  'Number of items': 'பொருட்களின் எண்ணிக்கை',
  'Description': 'விவரம்',
  'Qty': 'அளவு',
  'Rate': 'விலை',
  'Amount': 'தொகை',
  'Total Amount': 'மொத்த தொகை',
  'In words': 'வார்த்தைகளில்',
  'Generate Invoice': 'விலைப்பட்டியல் உருவாக்கு',
  'Delete this record?': 'இந்த பதிவை நீக்கவா?',
  'This cannot be undone.': 'இதை மீட்டெடுக்க முடியாது.',
  'Cancel': 'ரத்து செய்',
  'Delete': 'நீக்கு',
  'Edit': 'திருத்து',
  'Invoice': 'விலைப்பட்டியல்',
  'Invoice total': 'விலைப்பட்டியல் மொத்தம்',
  'Customer': 'வாடிக்கையாளர்',
  'Manual entry': 'கைமுறை பதிவு',
  'Other income': 'பிற வருமானம்',
  'No data for this period': 'இந்த காலத்திற்கு தரவு இல்லை',
  'Week 1': 'வாரம் 1',
  'Week 2': 'வாரம் 2',
  'Week 3': 'வாரம் 3',
  'Week 4': 'வாரம் 4',
  'Week 5': 'வாரம் 5',
  'Version 1.0.0': 'பதிப்பு 1.0.0',
};
