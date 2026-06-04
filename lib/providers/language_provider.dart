import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dharma_ai/services/supabase_sync.dart';

enum AppLanguage {
  english,
  tamil,
  hindi,
  bengali,
}

AppLanguage? _languageFromCode(String? code) {
  if (code == null) return null;
  for (final l in AppLanguage.values) {
    if (l.code == code) return l;
  }
  return null;
}

extension AppLanguageExt on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.tamil:
        return 'ta';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.bengali:
        return 'bn';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.tamil:
        return 'தமிழ்';
      case AppLanguage.hindi:
        return 'हिन्दी';
      case AppLanguage.bengali:
        return 'বাংলা';
    }
  }
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.english) {
    _load();
  }

  // Per-account key so a shared device doesn't carry one user's language to
  // another (cloud profiles.preferred_language is the cross-device source).
  String get _prefKey => 'preferred_language_${SupabaseSync.userId ?? 'anon'}';

  // Restore the saved language: device cache first (instant, survives refresh),
  // then the account's stored choice so it follows the user across devices.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _languageFromCode(prefs.getString(_prefKey));
    if (local != null) state = local;

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return;
    try {
      final row = await client
          .from('profiles')
          .select('preferred_language')
          .eq('id', uid)
          .maybeSingle();
      final remote = _languageFromCode(row?['preferred_language'] as String?);
      if (remote != null) {
        state = remote;
        await prefs.setString(_prefKey, remote.code);
      }
    } catch (_) {
      // offline / not reachable → keep the local choice
    }
  }

  // Change language and persist it (device + account).
  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language.code);

    final client = SupabaseSync.client;
    final uid = SupabaseSync.userId;
    if (client == null || uid == null) return;
    try {
      await client.from('profiles').update({'preferred_language': language.code}).eq('id', uid);
    } catch (_) {
      // best-effort cross-device sync; local copy already saved
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

class AppTranslations {
  static const Map<String, Map<AppLanguage, String>> _dict = {
    // Welcome Screen
    'seekDivineWisdom': {
      AppLanguage.english: 'Seek Divine Wisdom',
      AppLanguage.tamil: 'தெய்வீக ஞானத்தைத் தேடுங்கள்',
      AppLanguage.hindi: 'दिव्य ज्ञान की खोज करें',
      AppLanguage.bengali: 'দিব্য জ্ঞান সন্ধান করুন',
    },
    'welcomeSubtitle': {
      AppLanguage.english: 'Align your actions, explore ancient scriptures, and discover inner clarity with your spiritual AI guide.',
      AppLanguage.tamil: 'உங்கள் செயல்களை சீரமைக்கவும், பண்டைய வேதங்களை ஆராயவும், உங்கள் ஆன்மீக AI வழிகாட்டியுடன் உள் தெளிவைக் கண்டறியவும்.',
      AppLanguage.hindi: 'अपने कर्मों को संरेखित करें, प्राचीन ग्रंथों का पता लगाएं, और अपने आध्यात्मिक एआई मार्गदर्शक के साथ आंतरिक स्पष्टता की खोज करें।',
      AppLanguage.bengali: 'আপনার কর্মকে সামঞ্জস্যপূর্ণ করুন, প্রাচীন শাস্ত্রসমূহ অনুসন্ধান করুন এবং আপনার আধ্যাত্মিক এআই গাইডের সাথে অভ্যন্তরীণ স্বচ্ছতা আবিষ্কার করুন।',
    },
    'beginYourPath': {
      AppLanguage.english: 'BEGIN YOUR PATH',
      AppLanguage.tamil: 'உங்கள் பாதையைத் தொடங்குங்கள்',
      AppLanguage.hindi: 'अपनी यात्रा शुरू करें',
      AppLanguage.bengali: 'আপনার পথ শুরু করুন',
    },
    'selectLanguage': {
      AppLanguage.english: 'Select Language',
      AppLanguage.tamil: 'மொழியைத் தேர்ந்தெடுக்கவும்',
      AppLanguage.hindi: 'भाषा चुनें',
      AppLanguage.bengali: 'ভাষা নির্বাচন করুন',
    },

    // Shloka card headers
    'shlokaLabel': {
      AppLanguage.english: 'DAILY REFLECTION',
      AppLanguage.tamil: 'தினசரி சிந்தனை',
      AppLanguage.hindi: 'दैनिक विचार',
      AppLanguage.bengali: 'দৈনিক প্রতিফলন',
    },
    'labelTranslation': {
      AppLanguage.english: 'TRANSLATION',
      AppLanguage.tamil: 'மொழிபெயர்ப்பு',
      AppLanguage.hindi: 'अनुवाद',
      AppLanguage.bengali: 'অনুবাদ',
    },
    'labelCommentary': {
      AppLanguage.english: 'COMMENTARY',
      AppLanguage.tamil: 'விளக்கவுரை',
      AppLanguage.hindi: 'व्याख्या',
      AppLanguage.bengali: 'ভাষ্য',
    },

    // Default landing shloka (Gita 2.47)
    'shlokaVerse': {
      AppLanguage.english: 'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन ।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि ॥',
      AppLanguage.tamil: 'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन ।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि ॥',
      AppLanguage.hindi: 'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन ।\nमा कर्मफलहेतुर्भूर्मा ते सङ्गोऽस्त्वकर्मणि ॥',
      AppLanguage.bengali: 'কর্মণ্যেবাধিকারস্তে মা ফলেষু কদাচন।\nমা কর্মফলহেতুর্ভূর্মা তে সঙ্গো\nঽস্ত্বকর্মণি॥',
    },
    'shlokaTranslation': {
      AppLanguage.english: '"You have a right to perform your prescribed duty, but you are not entitled to the fruits of action. Never consider yourself the cause of results, nor yield to inaction."',
      AppLanguage.tamil: '"கடமையைச் செய்ய மட்டுமே உனக்கு அதிகாரம் உண்டு, அதன் பலன்களில் எப்போதும் இல்லை. செயலின் பலனுக்கு உன்னை காரணியாக்கிக் கொள்ளாதே, அதே சமயம் செயலின்மையில் பற்று கொள்ளாதே."',
      AppLanguage.hindi: '"कर्म करने में ही तुम्हारा अधिकार है, उसके फलों में कभी नहीं। तुम कर्मों के फल की इच्छा वाले मत बनो और तुम्हारी अकर्मण्यता में भी आसक्ति न हो।"',
      AppLanguage.bengali: '"কর্মে তোমার অধিকার আছে, কিন্তু ফলে কখনো অধিকার নেই। ফলের আশা করো না, আবার নিষ্ক্রিয়তায়ও আসক্ত হয়ো না।"',
    },

    // Personalize Screen
    'personalizeTitle': {
      AppLanguage.english: 'Personalize Your Path',
      AppLanguage.tamil: 'உங்கள் பாதையைத் தனிப்பயனாக்குங்கள்',
      AppLanguage.hindi: 'अपने पथ को वैयक्तिकृत करें',
      AppLanguage.bengali: 'আপনার পথ ব্যক্তিগত করুন',
    },
    'personalizeSubtitle': {
      AppLanguage.english: 'Choose your primary spiritual intent and level of scriptural study to configure your feed.',
      AppLanguage.tamil: 'உங்கள் ஊட்டத்தை உள்ளமைக்க உங்கள் முதன்மை ஆன்மீக நோக்கம் மற்றும் வேதப் படிப்பின் அளவைத் தேர்ந்தெடுக்கவும்.',
      AppLanguage.hindi: 'अपने फीड को कॉन्फ़िगर करने के लिए अपना प्राथमिक आध्यात्मिक उद्देश्य और शास्त्र अध्ययन का स्तर चुनें।',
      AppLanguage.bengali: 'আপনার ফিড কনফিগার করতে আপনার প্রাথমিক আধ্যাত্মিক উদ্দেশ্য এবং শাস্ত্রীয় অধ্যয়নের স্তর চয়ন করুন।',
    },
    'primaryGoal': {
      AppLanguage.english: 'YOUR PRIMARY GOAL',
      AppLanguage.tamil: 'உங்களின் முதன்மை இலக்கு',
      AppLanguage.hindi: 'आपका प्राथमिक लक्ष्य',
      AppLanguage.bengali: 'আপনার প্রাথমিক লক্ষ্য',
    },
    'scriptureFamiliarity': {
      AppLanguage.english: 'SCRIPTURE FAMILIARITY',
      AppLanguage.tamil: 'வேத அறிமுகம்',
      AppLanguage.hindi: 'ग्रंथों से परिचय का स्तर',
      AppLanguage.bengali: 'शास्त्रীয় পরিচিতি',
    },
    'continueBtn': {
      AppLanguage.english: 'CONTINUE',
      AppLanguage.tamil: 'தொடரவும்',
      AppLanguage.hindi: 'आगे बढ़ें',
      AppLanguage.bengali: 'এগিয়ে যান',
    },

    // Goals options
    'goal0': {
      AppLanguage.english: 'Inner Peace & Anxiety Relief',
      AppLanguage.tamil: 'உள் அமைதி மற்றும் கவலை நிவாரணம்',
      AppLanguage.hindi: 'आंतरिक शांति और चिंता से मुक्ति',
      AppLanguage.bengali: 'মানসিক শান্তি ও উদ্বেগ মুক্তি',
    },
    'goal1': {
      AppLanguage.english: 'Understanding Duty & Karma',
      AppLanguage.tamil: 'கடமை மற்றும் கர்மாவை புரிந்து கொள்ளுதல்',
      AppLanguage.hindi: 'कर्तव्य और कर्म की समझ',
      AppLanguage.bengali: 'কর্তব্য ও কর্মের বোধ',
    },
    'goal2': {
      AppLanguage.english: 'Studying Sacred Scriptures',
      AppLanguage.tamil: 'புனித நூல்களைப் படித்தல்',
      AppLanguage.hindi: 'पवित्र ग्रंथों का अध्ययन',
      AppLanguage.bengali: 'পবিত্র গ্রন্থাবলী অধ্যয়ন',
    },
    'goal3': {
      AppLanguage.english: 'Daily Sadhana & Meditation',
      AppLanguage.tamil: 'தினசரி சாதனா மற்றும் தியானம்',
      AppLanguage.hindi: 'दैनिक साधना और ध्यान',
      AppLanguage.bengali: 'দৈনিক সাধনা ও ধ্যান',
    },
    'goal4': {
      AppLanguage.english: 'Devotional Music & Chanting',
      AppLanguage.tamil: 'பதிவுசெய்யப்பட்ட பக்தி இசை மற்றும் ஜெபம்',
      AppLanguage.hindi: 'भक्ति संगीत और कीर्तन',
      AppLanguage.bengali: 'ভক্তি গীতি ও কীর্তন',
    },

    // Level options
    'level0': {
      AppLanguage.english: 'Beginner (Curious Explorer)',
      AppLanguage.tamil: 'தொடக்கநிலை (ஆர்வம் உள்ளவர்)',
      AppLanguage.hindi: 'प्रारंभिक (जिज्ञासु खोजी)',
      AppLanguage.bengali: 'শিক্ষানবিস (জিজ্ঞাসু গবেষক)',
    },
    'level1': {
      AppLanguage.english: 'Practitioner (Regular Reader)',
      AppLanguage.tamil: 'பயிற்சியாளர் (வழக்கமான வாசகர்)',
      AppLanguage.hindi: 'अभ्यासी (नियमित पाठक)',
      AppLanguage.bengali: 'সাধক (নিয়মিত পাঠক)',
    },
    'level2': {
      AppLanguage.english: 'Advanced (Dedicated Scholar)',
      AppLanguage.tamil: 'உயர்ந்த நிலை (அர்ப்பணிக்கப்பட்ட அறிஞர்)',
      AppLanguage.hindi: 'उन्नत (समर्पित विद्वान)',
      AppLanguage.bengali: 'উন্নত (উত্সর্গীকৃত পণ্ডিত)',
    },

    // Home shell tabs
    'tabFeed': {
      AppLanguage.english: 'Feed',
      AppLanguage.tamil: 'ஊட்டம்',
      AppLanguage.hindi: 'फीड',
      AppLanguage.bengali: 'ফিড',
    },
    'tabWisdom': {
      AppLanguage.english: 'Wisdom',
      AppLanguage.tamil: 'ஞானம்',
      AppLanguage.hindi: 'ज्ञान',
      AppLanguage.bengali: 'জ্ঞান',
    },
    'tabAiGuru': {
      AppLanguage.english: 'AI Guru',
      AppLanguage.tamil: 'AI குரு',
      AppLanguage.hindi: 'एआई गुरु',
      AppLanguage.bengali: 'এআই গুরু',
    },
    'tabSadhana': {
      AppLanguage.english: 'Sadhana',
      AppLanguage.tamil: 'சாதனா',
      AppLanguage.hindi: 'साधना',
      AppLanguage.bengali: 'সাধনা',
    },
    'tabSangha': {
      AppLanguage.english: 'Sangha',
      AppLanguage.tamil: 'சங்கம்',
      AppLanguage.hindi: 'संघ',
      AppLanguage.bengali: 'সংঘ',
    },

    // Chat
    'welcomeScripture': {
      AppLanguage.english: 'Radhey Radhey, {name}. I am your AI Scripture Scholar. Ask me anything about the Bhagavad Gita or other scriptures, and I will cross-reference them to give you precise philosophical context and verse citations.',
      AppLanguage.tamil: 'ராதே ராதே, {name}. நான் உங்கள் AI வேத அறிஞர். பகவத் கீதை அல்லது பிற புனித நூல்களைப் பற்றி என்னிடம் எதையும் கேளுங்கள், துல்லியமான தத்துவ பின்னணி மற்றும் வசன மேற்கோள்களை உங்களுக்கு வழங்க நான் அவற்றை ஒப்பிடுவேன்.',
      AppLanguage.hindi: 'राधे राधे, {name}। मैं आपका एआई शास्त्र विद्वान हूँ। मुझसे भगवद्गीता या अन्य ग्रंथों के बारे में कुछ भी पूछें, और मैं आपको सटीक दार्शनिक संदर्भ और श्लोक संदर्भ देने के लिए उनका मिलान करूँगा।',
      AppLanguage.bengali: 'রাধে রাধে, {name}। আমি আপনার এআই শাস্ত্র পণ্ডিত। আমাকে ভগবদ্গীতা বা অন্যান্য শাস্ত্র সম্পর্কে যেকোনো প্রশ্ন জিজ্ঞাসা করুন এবং আমি আপনাকে সঠিক দার্শনিক প্রসঙ্গ এবং শ্লোক উদ্ধৃতি দেওয়ার জন্য সেগুলি যাচাই করব।',
    },
    'welcomeGuru': {
      AppLanguage.english: 'Radhey Radhey, {name}. I am here to walk beside you on your path. Tell me what is in your heart, or what doubts cloud your mind, and let us seek clarity together.',
      AppLanguage.tamil: 'ராதே ராதே, {name}. உங்கள் பாதையில் உங்களுடன் நடக்க நான் இங்கே இருக்கிறேன். உங்கள் இதயத்தில் என்ன இருக்கிறது, அல்லது உங்கள் மனதை என்ன சந்தேகங்கள் மேகமூட்டுகின்றன என்று எனக்குச் சொல்லுங்கள், நாம் சேர்ந்து தெளிவு தேடுவோம்.',
      AppLanguage.hindi: 'राधे राधे, {name}। मैं आपकी यात्रा में आपके साथ चलने के लिए यहाँ हूँ। मुझे बताएं कि आपके दिल में क्या है, या कौन से संदेह आपके दिमाग को बादलों की तरह घेरे हुए हैं, और आइए मिलकर स्पष्टता खोजें।',
      AppLanguage.bengali: 'রাধে রাধে, {name}। আমি আপনার পথে আপনার পাশে হাঁটার জন্য এখানে আছি। আপনার হৃদয়ে কী আছে বা কী ধরণের সন্দেহ আপনার মনকে মেঘাচ্ছন্ন করেছে তা আমাকে বলুন এবং আসুন একসাথে স্বচ্ছতা সন্ধান করি।',
    },
    'errorScripture': {
      AppLanguage.english: 'I apologize, dear seeker. A connection issue occurred. Please try again.',
      AppLanguage.tamil: 'என்னை மன்னியுங்கள், அன்பான தேடுபவரே. இணைப்பு சிக்கல் ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்.',
      AppLanguage.hindi: 'मुझे खेद है, प्रिय साधक। एक कनेक्शन समस्या उत्पन्न हुई। कृपया पुनः प्रयास करें।',
      AppLanguage.bengali: 'আমি দুঃখিত, প্রিয় অন্বেষক। একটি সংযোগের সমস্যা ঘটেছে। অনুগ্রহ করে আবার চেষ্টা করুন।',
    },
    'errorGuru': {
      AppLanguage.english: 'Radhey Radhey. A disturbance in the ether occurred. Let us breathe deeply and try again.',
      AppLanguage.tamil: 'ராதே ராதே. ஆகாயத்தில் ஒரு தொந்தரவு ஏற்பட்டது. ஆழ்ந்த மூச்சு எடுத்து மீண்டும் முயற்சிப்போம்.',
      AppLanguage.hindi: 'राधे राधे। वातावरण में कोई व्यवधान उत्पन्न हुआ है। आइए गहरी सांस लें और पुनः प्रयास करें।',
      AppLanguage.bengali: 'রাধে রাধে। ইথারে একটি বিঘ্ন ঘটেছে। আসুন দীর্ঘশ্বাস নিই এবং আবার চেষ্টা করি।',
    },
    'greetingSeeker': {
      AppLanguage.english: 'Radhey Radhey, Seeker',
      AppLanguage.tamil: 'ராதே ராதே, தேடுபவரே',
      AppLanguage.hindi: 'राधे राधे, साधक',
      AppLanguage.bengali: 'রাধে রাধে, অন্বেষক',
    },
    'greetingHariOm': {
      AppLanguage.english: 'Radhey Radhey,',
      AppLanguage.tamil: 'ராதே ராதே,',
      AppLanguage.hindi: 'राधे राधे,',
      AppLanguage.bengali: 'রাধে রাধে,',
    },
    'fairUseLimit': {
      AppLanguage.english: "🙏 You've reached today's fair-use limit of 101 messages. It resets tomorrow — thank you for your understanding.",
      AppLanguage.tamil: '🙏 இன்றைய நியாயமான பயன்பாட்டு வரம்பான 101 செய்திகளை அடைந்துவிட்டீர்கள். நாளை மீட்டமைக்கப்படும் — உங்கள் புரிதலுக்கு நன்றி.',
      AppLanguage.hindi: '🙏 आप आज की उचित-उपयोग सीमा (101 संदेश) तक पहुँच गए हैं। यह कल पुनः आरंभ होगी — आपकी समझ के लिए धन्यवाद।',
      AppLanguage.bengali: '🙏 আপনি আজকের ন্যায্য-ব্যবহার সীমা ১০১টি বার্তায় পৌঁছেছেন। এটি আগামীকাল রিসেট হবে — আপনার বোঝাপড়ার জন্য ধন্যবাদ।',
    },
    'streakInfoTitle': {
      AppLanguage.english: 'Your Sadhana Streak',
      AppLanguage.tamil: 'உங்கள் சாதனைத் தொடர்',
      AppLanguage.hindi: 'आपकी साधना श्रृंखला',
      AppLanguage.bengali: 'আপনার সাধনা ধারা',
    },
    'streakInfoBody': {
      AppLanguage.english: 'Complete all your daily goals — meditation, scripture reading and chanting — to keep the flame alive and grow your streak. Consistency is the heart of sadhana.',
      AppLanguage.tamil: 'தியானம், வேதபாடம், ஜபம் ஆகிய அனைத்து தினசரி இலக்குகளையும் நிறைவேற்றி, உங்கள் தொடரை வளர்த்துக் கொள்ளுங்கள். நிலைத்தன்மையே சாதனையின் இதயம்.',
      AppLanguage.hindi: 'अपने सभी दैनिक लक्ष्य — ध्यान, शास्त्र पठन और जप — पूरा करें ताकि ज्योति जलती रहे और आपकी श्रृंखला बढ़ती रहे। निरंतरता ही साधना का हृदय है।',
      AppLanguage.bengali: 'ধ্যান, শাস্ত্র পাঠ ও জপ — আপনার সমস্ত দৈনিক লক্ষ্য সম্পূর্ণ করুন যাতে শিখা জ্বলতে থাকে এবং আপনার ধারা বৃদ্ধি পায়। ধারাবাহিকতাই সাধনার হৃদয়।',
    },
    'streakInfoBtn': {
      AppLanguage.english: 'KEEP GOING',
      AppLanguage.tamil: 'தொடருங்கள்',
      AppLanguage.hindi: 'जारी रखें',
      AppLanguage.bengali: 'চালিয়ে যান',
    },
    'sanghaIntro': {
      AppLanguage.english: 'Sangha is your community of fellow seekers. Share reflections from your practice, celebrate milestones, and draw inspiration from others walking the path of dharma.',
      AppLanguage.tamil: 'சங்கம் உங்கள் சக சாதகர்களின் சமூகம். உங்கள் பயிற்சியின் சிந்தனைகளைப் பகிருங்கள், மைல்கற்களைக் கொண்டாடுங்கள், தர்மப் பாதையில் நடப்பவர்களிடமிருந்து உத்வேகம் பெறுங்கள்.',
      AppLanguage.hindi: 'संघ आपके सहयात्री साधकों का समुदाय है। अपने अभ्यास के विचार साझा करें, उपलब्धियों का उत्सव मनाएं, और धर्म-पथ पर चलने वाले अन्य लोगों से प्रेरणा लें।',
      AppLanguage.bengali: 'সঙ্ঘ আপনার সহ-অন্বেষকদের সম্প্রদায়। আপনার অনুশীলনের ভাবনা ভাগ করুন, মাইলফলক উদযাপন করুন, এবং ধর্মপথে চলা অন্যদের থেকে অনুপ্রেরণা নিন।',
    },
    'greetingSubtitle': {
      AppLanguage.english: 'May peace guide your day.',
      AppLanguage.tamil: 'அமைதி உங்கள் நாளை வழிநடத்தட்டும்.',
      AppLanguage.hindi: 'शांति आपके दिन का मार्गदर्शन करे।',
      AppLanguage.bengali: 'শান্তি আপনার দিনটিকে পরিচালিত করুক।',
    },
    'dailySadhanaCheckIn': {
      AppLanguage.english: 'DAILY SADHANA CHECK-IN',
      AppLanguage.tamil: 'தினசரி சாதனா செக்-இன்',
      AppLanguage.hindi: 'दैनिक साधना चेक-इन',
      AppLanguage.bengali: 'দৈনিক সাধনা চেক-ইন',
    },
    'goToSadhana': {
      AppLanguage.english: 'Go to Sadhana',
      AppLanguage.tamil: 'சாதனாவிற்கு செல்லவும்',
      AppLanguage.hindi: 'साधना पर जाएं',
      AppLanguage.bengali: 'সাধনায় যান',
    },
    'chakraDawn': {
      AppLanguage.english: 'The wheel of dharma turns with the dawn.',
      AppLanguage.hindi: 'धर्म का चक्र भोर के साथ घूमता है।',
      AppLanguage.tamil: 'அறத்தின் சக்கரம் விடியலுடன் சுழல்கிறது.',
      AppLanguage.bengali: 'ধর্মের চক্র ভোরের সাথে ঘোরে।',
    },
    'chakraNoon': {
      AppLanguage.english: 'Act without attachment. Serve with love.',
      AppLanguage.hindi: 'आसक्ति के बिना कर्म करें। प्रेम से सेवा करें।',
      AppLanguage.tamil: 'பற்றின்றி செயல்படு. அன்புடன் சேவை செய்.',
      AppLanguage.bengali: 'আসক্তি ছাড়া কর্ম করুন। ভালোবেসে সেবা করুন।',
    },
    'chakraDusk': {
      AppLanguage.english: 'Reflect with gratitude at dusk.',
      AppLanguage.hindi: 'संध्या के समय कृतज्ञता के साथ चिंतन करें।',
      AppLanguage.tamil: 'அந்தி வேளையில் நன்றியுடன் சிந்தியுங்கள்.',
      AppLanguage.bengali: 'সন্ধ্যায় কৃতজ্ঞতার সাথে ধ্যান করুন।',
    },
    'chakraNight': {
      AppLanguage.english: 'In stillness, the eternal awakens.',
      AppLanguage.hindi: 'स्थिरता में, शाश्वत जागता है।',
      AppLanguage.tamil: 'அமைதியில், நித்தியம் விழித்தெழுகிறது.',
      AppLanguage.bengali: 'নিস্তব্ধতায়, চিরন্তন জেগে ওঠে।',
    },
    'logoTagline': {
      AppLanguage.english: 'Wisdom · Intelligence · Purpose',
      AppLanguage.hindi: 'ज्ञान · बुद्धि · उद्देश्य',
      AppLanguage.tamil: 'ஞானம் · அறிவு · நோக்கம்',
      AppLanguage.bengali: 'জ্ঞান · বুদ্ধি · উদ্দেশ্য',
    },
    // ── Shared ──
    'upgradeToUnlock': {
      AppLanguage.english: 'UPGRADE TO UNLOCK',
      AppLanguage.hindi: 'अनलॉक करने के लिए अपग्रेड करें',
      AppLanguage.tamil: 'திறக்க மேம்படுத்தவும்',
      AppLanguage.bengali: 'আনলক করতে আপগ্রেড করুন',
    },
    // ── Gift subscription ──
    'giftScreenTitle': {
      AppLanguage.english: 'Gift a Subscription',
      AppLanguage.hindi: 'एक सदस्यता उपहार दें',
      AppLanguage.tamil: 'ஒரு சந்தாவை பரிசளிக்கவும்',
      AppLanguage.bengali: 'একটি সাবস্ক্রিপশন উপহার দিন',
    },
    'giftShareTitle': {
      AppLanguage.english: 'Share the Path of Wisdom',
      AppLanguage.hindi: 'ज्ञान का मार्ग साझा करें',
      AppLanguage.tamil: 'ஞானத்தின் பாதையைப் பகிருங்கள்',
      AppLanguage.bengali: 'জ্ঞানের পথ ভাগ করুন',
    },
    'giftRecipientHint': {
      AppLanguage.english: 'e.g. Ramesh Devi',
      AppLanguage.hindi: 'उदा. रमेश देवी',
      AppLanguage.tamil: 'எ.கா. ரமேஷ் தேவி',
      AppLanguage.bengali: 'যেমন রমেশ দেবী',
    },
    'giftPlanLabel': {
      AppLanguage.english: 'GIFT PLAN',
      AppLanguage.hindi: 'उपहार योजना',
      AppLanguage.tamil: 'பரிசு திட்டம்',
      AppLanguage.bengali: 'উপহার পরিকল্পনা',
    },
    'giftPayButton': {
      AppLanguage.english: 'PAY & GET GIFT CODE',
      AppLanguage.hindi: 'भुगतान करें और उपहार कोड पाएं',
      AppLanguage.tamil: 'பணம் செலுத்தி பரிசு குறியீட்டைப் பெறுங்கள்',
      AppLanguage.bengali: 'পরিশোধ করুন ও উপহার কোড পান',
    },
    'giftCopy': {
      AppLanguage.english: 'Copy',
      AppLanguage.hindi: 'कॉपी करें',
      AppLanguage.tamil: 'நகலெடு',
      AppLanguage.bengali: 'কপি করুন',
    },
    'giftCopied': {
      AppLanguage.english: 'Code copied',
      AppLanguage.hindi: 'कोड कॉपी हो गया',
      AppLanguage.tamil: 'குறியீடு நகலெடுக்கப்பட்டது',
      AppLanguage.bengali: 'কোড কপি হয়েছে',
    },
    'giftDone': {
      AppLanguage.english: 'DONE',
      AppLanguage.hindi: 'हो गया',
      AppLanguage.tamil: 'முடிந்தது',
      AppLanguage.bengali: 'সম্পন্ন',
    },
    'giftSignIn': {
      AppLanguage.english: 'Please sign in to gift a pass.',
      AppLanguage.hindi: 'पास उपहार देने के लिए कृपया साइन इन करें।',
      AppLanguage.tamil: 'பாஸ் பரிசளிக்க உள்நுழையவும்.',
      AppLanguage.bengali: 'একটি পাস উপহার দিতে সাইন ইন করুন।',
    },
    // ── Redeem code ──
    'redeemTitle': {
      AppLanguage.english: 'Redeem a Gift Code',
      AppLanguage.hindi: 'एक उपहार कोड भुनाएं',
      AppLanguage.tamil: 'பரிசு குறியீட்டை மீட்டெடுக்கவும்',
      AppLanguage.bengali: 'একটি উপহার কোড রিডিম করুন',
    },
    'redeemReceivedGift': {
      AppLanguage.english: 'Received a Gift?',
      AppLanguage.hindi: 'एक उपहार मिला?',
      AppLanguage.tamil: 'பரிசு கிடைத்ததா?',
      AppLanguage.bengali: 'একটি উপহার পেয়েছেন?',
    },
    'redeemDescription': {
      AppLanguage.english: 'Enter the gift code a friend shared with you to unlock your Sadhaka Premium pass.',
      AppLanguage.hindi: 'अपना साधक प्रीमियम पास अनलॉक करने के लिए किसी मित्र द्वारा साझा किया गया उपहार कोड दर्ज करें।',
      AppLanguage.tamil: 'உங்கள் சாதக பிரீமியம் பாஸைத் திறக்க ஒரு நண்பர் பகிர்ந்த பரிசு குறியீட்டை உள்ளிடவும்.',
      AppLanguage.bengali: 'আপনার সাধক প্রিমিয়াম পাস আনলক করতে একজন বন্ধুর শেয়ার করা উপহার কোড লিখুন।',
    },
    'redeemCodeLabel': {
      AppLanguage.english: 'GIFT CODE',
      AppLanguage.hindi: 'उपहार कोड',
      AppLanguage.tamil: 'பரிசு குறியீடு',
      AppLanguage.bengali: 'উপহার কোড',
    },
    'redeemButton': {
      AppLanguage.english: 'REDEEM',
      AppLanguage.hindi: 'भुनाएं',
      AppLanguage.tamil: 'மீட்டெடு',
      AppLanguage.bengali: 'রিডিম করুন',
    },
    'redeemEnterCode': {
      AppLanguage.english: 'Please enter your gift code.',
      AppLanguage.hindi: 'कृपया अपना उपहार कोड दर्ज करें।',
      AppLanguage.tamil: 'உங்கள் பரிசு குறியீட்டை உள்ளிடவும்.',
      AppLanguage.bengali: 'আপনার উপহার কোড লিখুন।',
    },
    'redeemSignIn': {
      AppLanguage.english: 'Please sign in to redeem a code.',
      AppLanguage.hindi: 'कोड भुनाने के लिए कृपया साइन इन करें।',
      AppLanguage.tamil: 'குறியீட்டை மீட்டெடுக்க உள்நுழையவும்.',
      AppLanguage.bengali: 'একটি কোড রিডিম করতে সাইন ইন করুন।',
    },
    'redeemSuccessBody': {
      AppLanguage.english: 'Your gift has been redeemed and Premium is now unlocked. May your path be blessed with wisdom.',
      AppLanguage.hindi: 'आपका उपहार भुना लिया गया है और प्रीमियम अब अनलॉक हो गया है। आपका मार्ग ज्ञान से धन्य हो।',
      AppLanguage.tamil: 'உங்கள் பரிசு மீட்டெடுக்கப்பட்டது, பிரீமியம் இப்போது திறக்கப்பட்டது. உங்கள் பாதை ஞானத்தால் ஆசீர்வதிக்கப்படட்டும்.',
      AppLanguage.bengali: 'আপনার উপহার রিডিম হয়েছে এবং প্রিমিয়াম এখন আনলক হয়েছে। আপনার পথ জ্ঞানে আশীর্বাদপ্রাপ্ত হোক।',
    },
    // ── Audio Wisdom ──
    'audioGateBody': {
      AppLanguage.english: 'All 18 Bhagavad Gita chapter chantings are available on Sadhaka Premium and Annual plans.',
      AppLanguage.hindi: 'सभी 18 भगवद्गीता अध्याय मंत्रोच्चारण साधक प्रीमियम और वार्षिक योजनाओं पर उपलब्ध हैं।',
      AppLanguage.tamil: 'அனைத்து 18 பகவத் கீதை அத்தியாய பாராயணங்களும் சாதக பிரீமியம் மற்றும் ஆண்டு திட்டங்களில் கிடைக்கும்.',
      AppLanguage.bengali: 'সমস্ত 18টি ভগবদ্গীতা অধ্যায়ের জপ সাধক প্রিমিয়াম ও বার্ষিক প্ল্যানে উপলব্ধ।',
    },
    // ── Reader premium gate ──
    'gatePremiumScripture': {
      AppLanguage.english: 'A Premium Scripture',
      AppLanguage.hindi: 'एक प्रीमियम ग्रंथ',
      AppLanguage.tamil: 'ஒரு பிரீமியம் வேதம்',
      AppLanguage.bengali: 'একটি প্রিমিয়াম শাস্ত্র',
    },
    'gateAccessBody': {
      AppLanguage.english: 'Access to this scripture is part of the Sadhaka Premium and Annual paths.',
      AppLanguage.hindi: 'इस ग्रंथ तक पहुंच साधक प्रीमियम और वार्षिक मार्गों का हिस्सा है।',
      AppLanguage.tamil: 'இந்த வேதத்திற்கான அணுகல் சாதக பிரீமியம் மற்றும் ஆண்டு பாதைகளின் ஒரு பகுதியாகும்.',
      AppLanguage.bengali: 'এই শাস্ত্রে প্রবেশ সাধক প্রিমিয়াম ও বার্ষিক পথের অংশ।',
    },
    // ── Set new password ──
    'spSetNewPassword': {
      AppLanguage.english: 'Set a new password',
      AppLanguage.hindi: 'एक नया पासवर्ड सेट करें',
      AppLanguage.tamil: 'புதிய கடவுச்சொல்லை அமைக்கவும்',
      AppLanguage.bengali: 'একটি নতুন পাসওয়ার্ড সেট করুন',
    },
    'spSubtitle': {
      AppLanguage.english: 'Choose a new password for your account. You\'ll use it to sign in from now on.',
      AppLanguage.hindi: 'अपने खाते के लिए एक नया पासवर्ड चुनें। अब से आप इसका उपयोग साइन इन करने के लिए करेंगे।',
      AppLanguage.tamil: 'உங்கள் கணக்கிற்கு புதிய கடவுச்சொல்லைத் தேர்ந்தெடுக்கவும். இனிமேல் உள்நுழைய இதைப் பயன்படுத்துவீர்கள்.',
      AppLanguage.bengali: 'আপনার অ্যাকাউন্টের জন্য একটি নতুন পাসওয়ার্ড বেছে নিন। এখন থেকে সাইন ইন করতে এটি ব্যবহার করবেন।',
    },
    'spNewPassword': {
      AppLanguage.english: 'New password',
      AppLanguage.hindi: 'नया पासवर्ड',
      AppLanguage.tamil: 'புதிய கடவுச்சொல்',
      AppLanguage.bengali: 'নতুন পাসওয়ার্ড',
    },
    'spConfirmPassword': {
      AppLanguage.english: 'Confirm new password',
      AppLanguage.hindi: 'नया पासवर्ड पुष्टि करें',
      AppLanguage.tamil: 'புதிய கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      AppLanguage.bengali: 'নতুন পাসওয়ার্ড নিশ্চিত করুন',
    },
    'spUpdateButton': {
      AppLanguage.english: 'UPDATE PASSWORD',
      AppLanguage.hindi: 'पासवर्ड अपडेट करें',
      AppLanguage.tamil: 'கடவுச்சொல்லைப் புதுப்பிக்கவும்',
      AppLanguage.bengali: 'পাসওয়ার্ড আপডেট করুন',
    },
    'spMinChars': {
      AppLanguage.english: 'Password must be at least 6 characters.',
      AppLanguage.hindi: 'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।',
      AppLanguage.tamil: 'கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்.',
      AppLanguage.bengali: 'পাসওয়ার্ড কমপক্ষে 6টি অক্ষরের হতে হবে।',
    },
    'spMismatch': {
      AppLanguage.english: 'The passwords do not match.',
      AppLanguage.hindi: 'पासवर्ड मेल नहीं खाते।',
      AppLanguage.tamil: 'கடவுச்சொற்கள் பொருந்தவில்லை.',
      AppLanguage.bengali: 'পাসওয়ার্ডগুলি মিলছে না।',
    },
    'spUpdated': {
      AppLanguage.english: 'Your password has been updated. Welcome back.',
      AppLanguage.hindi: 'आपका पासवर्ड अपडेट हो गया है। वापसी पर स्वागत है।',
      AppLanguage.tamil: 'உங்கள் கடவுச்சொல் புதுப்பிக்கப்பட்டது. மீண்டும் வரவேற்கிறோம்.',
      AppLanguage.bengali: 'আপনার পাসওয়ার্ড আপডেট হয়েছে। আবার স্বাগতম।',
    },
    // ── Forgot password dialog ──
    'fpTitle': {
      AppLanguage.english: 'Reset your password',
      AppLanguage.hindi: 'अपना पासवर्ड रीसेट करें',
      AppLanguage.tamil: 'உங்கள் கடவுச்சொல்லை மீட்டமைக்கவும்',
      AppLanguage.bengali: 'আপনার পাসওয়ার্ড রিসেট করুন',
    },
    'fpBody': {
      AppLanguage.english: 'Enter your account email and we\'ll send you a link to set a new password.',
      AppLanguage.hindi: 'अपना खाता ईमेल दर्ज करें और हम आपको नया पासवर्ड सेट करने के लिए एक लिंक भेजेंगे।',
      AppLanguage.tamil: 'உங்கள் கணக்கு மின்னஞ்சலை உள்ளிடவும், புதிய கடவுச்சொல்லை அமைக்க ஒரு இணைப்பை அனுப்புவோம்.',
      AppLanguage.bengali: 'আপনার অ্যাকাউন্ট ইমেল লিখুন এবং আমরা নতুন পাসওয়ার্ড সেট করার একটি লিঙ্ক পাঠাব।',
    },
    'fpCancel': {
      AppLanguage.english: 'CANCEL',
      AppLanguage.hindi: 'रद्द करें',
      AppLanguage.tamil: 'ரத்து செய்',
      AppLanguage.bengali: 'বাতিল করুন',
    },
    'fpSend': {
      AppLanguage.english: 'SEND RESET LINK',
      AppLanguage.hindi: 'रीसेट लिंक भेजें',
      AppLanguage.tamil: 'மீட்டமைப்பு இணைப்பை அனுப்பு',
      AppLanguage.bengali: 'রিসেট লিঙ্ক পাঠান',
    },
    'fpInvalidEmail': {
      AppLanguage.english: 'Please enter a valid email address.',
      AppLanguage.hindi: 'कृपया एक मान्य ईमेल पता दर्ज करें।',
      AppLanguage.tamil: 'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.',
      AppLanguage.bengali: 'একটি বৈধ ইমেল ঠিকানা লিখুন।',
    },
    'fpSent': {
      AppLanguage.english: 'If an account exists, a password reset link is on its way. Check your inbox.',
      AppLanguage.hindi: 'यदि कोई खाता मौजूद है, तो पासवर्ड रीसेट लिंक भेजा जा रहा है। अपना इनबॉक्स देखें।',
      AppLanguage.tamil: 'ஒரு கணக்கு இருந்தால், கடவுச்சொல் மீட்டமைப்பு இணைப்பு அனுப்பப்படுகிறது. உங்கள் இன்பாக்ஸைச் சரிபார்க்கவும்.',
      AppLanguage.bengali: 'একটি অ্যাকাউন্ট থাকলে, পাসওয়ার্ড রিসেট লিঙ্ক পাঠানো হচ্ছে। আপনার ইনবক্স দেখুন।',
    },
    // ── Subscription expiry dialog ──
    'expiryTitle': {
      AppLanguage.english: 'Subscription ended',
      AppLanguage.hindi: 'सदस्यता समाप्त हो गई',
      AppLanguage.tamil: 'சந்தா முடிந்தது',
      AppLanguage.bengali: 'সাবস্ক্রিপশন শেষ হয়েছে',
    },
    'expiryUpgradeBenefits': {
      AppLanguage.english: 'Upgrade to continue benefits.',
      AppLanguage.hindi: 'लाभ जारी रखने के लिए अपग्रेड करें।',
      AppLanguage.tamil: 'நன்மைகளைத் தொடர மேம்படுத்தவும்.',
      AppLanguage.bengali: 'সুবিধা চালিয়ে যেতে আপগ্রেড করুন।',
    },
    'expiryMaybeLater': {
      AppLanguage.english: 'MAYBE LATER',
      AppLanguage.hindi: 'बाद में',
      AppLanguage.tamil: 'பிறகு',
      AppLanguage.bengali: 'পরে',
    },
    'expiryUpgrade': {
      AppLanguage.english: 'UPGRADE',
      AppLanguage.hindi: 'अपग्रेड करें',
      AppLanguage.tamil: 'மேம்படுத்து',
      AppLanguage.bengali: 'আপগ্রেড',
    },
    // ── Profile / My Sanctuary ──
    'profileMySanctuary': {
      AppLanguage.english: 'My Sanctuary',
      AppLanguage.hindi: 'मेरा आश्रय',
      AppLanguage.tamil: 'என் புகலிடம்',
      AppLanguage.bengali: 'আমার আশ্রয়',
    },
    'profileLevelPractitioner': {
      AppLanguage.english: 'Level: Practitioner',
      AppLanguage.hindi: 'स्तर: साधक',
      AppLanguage.tamil: 'நிலை: பயிற்சியாளர்',
      AppLanguage.bengali: 'স্তর: অনুশীলনকারী',
    },
    'profileUpgradeAccount': {
      AppLanguage.english: 'Upgrade Account',
      AppLanguage.hindi: 'खाता अपग्रेड करें',
      AppLanguage.tamil: 'கணக்கை மேம்படுத்து',
      AppLanguage.bengali: 'অ্যাকাউন্ট আপগ্রেড করুন',
    },
    'profileGiftPass': {
      AppLanguage.english: 'Gift a Wisdom Pass',
      AppLanguage.hindi: 'एक विजडम पास उपहार दें',
      AppLanguage.tamil: 'ஒரு ஞான பாஸ் பரிசளிக்கவும்',
      AppLanguage.bengali: 'একটি উইজডম পাস উপহার দিন',
    },
    'profileRedeemCode': {
      AppLanguage.english: 'Redeem a Gift Code',
      AppLanguage.hindi: 'एक उपहार कोड भुनाएं',
      AppLanguage.tamil: 'பரிசு குறியீட்டை மீட்டெடுக்கவும்',
      AppLanguage.bengali: 'একটি উপহার কোড রিডিম করুন',
    },
    'profileLanguage': {
      AppLanguage.english: 'Language',
      AppLanguage.hindi: 'भाषा',
      AppLanguage.tamil: 'மொழி',
      AppLanguage.bengali: 'ভাষা',
    },
    'profileSignOut': {
      AppLanguage.english: 'Sign Out',
      AppLanguage.hindi: 'साइन आउट करें',
      AppLanguage.tamil: 'வெளியேறு',
      AppLanguage.bengali: 'সাইন আউট',
    },
    'profileChooseLanguage': {
      AppLanguage.english: 'Choose Language',
      AppLanguage.hindi: 'भाषा चुनें',
      AppLanguage.tamil: 'மொழியைத் தேர்ந்தெடுக்கவும்',
      AppLanguage.bengali: 'ভাষা নির্বাচন করুন',
    },
    'profileSignInToSave': {
      AppLanguage.english: 'Please sign in to save your note.',
      AppLanguage.hindi: 'अपना नोट सहेजने के लिए कृपया साइन इन करें।',
      AppLanguage.tamil: 'உங்கள் குறிப்பைச் சேமிக்க உள்நுழையவும்.',
      AppLanguage.bengali: 'আপনার নোট সংরক্ষণ করতে সাইন ইন করুন।',
    },
    'profileSavedWisdom': {
      AppLanguage.english: 'SAVED WISDOM',
      AppLanguage.hindi: 'सहेजा गया ज्ञान',
      AppLanguage.tamil: 'சேமித்த ஞானம்',
      AppLanguage.bengali: 'সংরক্ষিত জ্ঞান',
    },
    'profilePersonalNoteTab': {
      AppLanguage.english: 'PERSONAL NOTE',
      AppLanguage.hindi: 'व्यक्तिगत नोट',
      AppLanguage.tamil: 'தனிப்பட்ட குறிப்பு',
      AppLanguage.bengali: 'ব্যক্তিগত নোট',
    },
    'profileYourPersonalNote': {
      AppLanguage.english: 'YOUR PERSONAL NOTE',
      AppLanguage.hindi: 'आपका व्यक्तिगत नोट',
      AppLanguage.tamil: 'உங்கள் தனிப்பட்ட குறிப்பு',
      AppLanguage.bengali: 'আপনার ব্যক্তিগত নোট',
    },
    'profileNoteDescription': {
      AppLanguage.english: 'Write down your reflections, realizations and personal goals. Saved to your account, so it stays with you on every device.',
      AppLanguage.hindi: 'अपने विचार, अनुभूतियां और व्यक्तिगत लक्ष्य लिखें। आपके खाते में सहेजा गया, ताकि यह हर डिवाइस पर आपके साथ रहे।',
      AppLanguage.tamil: 'உங்கள் சிந்தனைகள், உணர்தல்கள் மற்றும் தனிப்பட்ட இலக்குகளை எழுதுங்கள். உங்கள் கணக்கில் சேமிக்கப்படுகிறது, எனவே இது ஒவ்வொரு சாதனத்திலும் உங்களுடன் இருக்கும்.',
      AppLanguage.bengali: 'আপনার চিন্তা, উপলব্ধি ও ব্যক্তিগত লক্ষ্য লিখুন। আপনার অ্যাকাউন্টে সংরক্ষিত, তাই এটি প্রতিটি ডিভাইসে আপনার সাথে থাকে।',
    },
    'profileNoteHint': {
      AppLanguage.english: 'Enter your thoughts here...',
      AppLanguage.hindi: 'अपने विचार यहां लिखें...',
      AppLanguage.tamil: 'உங்கள் எண்ணங்களை இங்கே உள்ளிடவும்...',
      AppLanguage.bengali: 'আপনার চিন্তা এখানে লিখুন...',
    },
    'profileSaveNote': {
      AppLanguage.english: 'SAVE NOTE',
      AppLanguage.hindi: 'नोट सहेजें',
      AppLanguage.tamil: 'குறிப்பைச் சேமி',
      AppLanguage.bengali: 'নোট সংরক্ষণ করুন',
    },
    'profileNoteSaved': {
      AppLanguage.english: 'Note saved to your account — available on all your devices.',
      AppLanguage.hindi: 'नोट आपके खाते में सहेजा गया — आपके सभी डिवाइस पर उपलब्ध।',
      AppLanguage.tamil: 'குறிப்பு உங்கள் கணக்கில் சேமிக்கப்பட்டது — உங்கள் அனைத்து சாதனங்களிலும் கிடைக்கும்.',
      AppLanguage.bengali: 'নোট আপনার অ্যাকাউন্টে সংরক্ষিত — আপনার সব ডিভাইসে উপলব্ধ।',
    },
    'profileNoteSaveError': {
      AppLanguage.english: 'Could not save. Please check your connection and try again.',
      AppLanguage.hindi: 'सहेजा नहीं जा सका। कृपया अपना कनेक्शन जांचें और पुनः प्रयास करें।',
      AppLanguage.tamil: 'சேமிக்க முடியவில்லை. உங்கள் இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
      AppLanguage.bengali: 'সংরক্ষণ করা যায়নি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
    },
    'profileNoSavedVerses': {
      AppLanguage.english: 'No saved verses yet. Tap the bookmark icon on scripture cards to preserve them in your sanctuary.',
      AppLanguage.hindi: 'अभी तक कोई सहेजा गया श्लोक नहीं। उन्हें अपने आश्रय में सहेजने के लिए शास्त्र कार्ड पर बुकमार्क आइकन पर टैप करें।',
      AppLanguage.tamil: 'இன்னும் சேமித்த வசனங்கள் இல்லை. அவற்றை உங்கள் புகலிடத்தில் பாதுகாக்க வேத அட்டைகளில் புக்மார்க் ஐகானைத் தட்டவும்.',
      AppLanguage.bengali: 'এখনও কোনো সংরক্ষিত শ্লোক নেই। আপনার আশ্রয়ে সংরক্ষণ করতে শাস্ত্র কার্ডে বুকমার্ক আইকনে আলতো চাপুন।',
    },
    'profileDayStreak': {
      AppLanguage.english: 'Day Streak',
      AppLanguage.hindi: 'दिन की लय',
      AppLanguage.tamil: 'நாள் தொடர்',
      AppLanguage.bengali: 'দিনের স্ট্রিক',
    },
    // ── Subscription paywall ──
    'pwChooseYourPath': {
      AppLanguage.english: 'Choose Your Path',
      AppLanguage.hindi: 'अपना मार्ग चुनें',
      AppLanguage.tamil: 'உங்கள் பாதையைத் தேர்ந்தெடுக்கவும்',
      AppLanguage.bengali: 'আপনার পথ বেছে নিন',
    },
    'pwChooseSubtitle': {
      AppLanguage.english: 'Choose a membership level to align with your personal sadhana requirements.',
      AppLanguage.hindi: 'अपनी व्यक्तिगत साधना के अनुरूप एक सदस्यता स्तर चुनें।',
      AppLanguage.tamil: 'உங்கள் தனிப்பட்ட சாதனைக்கு ஏற்ப ஒரு உறுப்பினர் நிலையைத் தேர்ந்தெடுக்கவும்.',
      AppLanguage.bengali: 'আপনার ব্যক্তিগত সাধনার সাথে মানানসই একটি সদস্যপদ স্তর বেছে নিন।',
    },
    'pwAnnualTitle': {
      AppLanguage.english: 'Sadhaka Annual',
      AppLanguage.hindi: 'साधक वार्षिक',
      AppLanguage.tamil: 'சாதக ஆண்டு',
      AppLanguage.bengali: 'সাধক বার্ষিক',
    },
    'pwQuarterlyTitle': {
      AppLanguage.english: 'Sadhaka Quarterly',
      AppLanguage.hindi: 'साधक त्रैमासिक',
      AppLanguage.tamil: 'சாதக காலாண்டு',
      AppLanguage.bengali: 'সাধক ত্রৈমাসিক',
    },
    'pwPremiumTitle': {
      AppLanguage.english: 'Sadhaka Premium',
      AppLanguage.hindi: 'साधक प्रीमियम',
      AppLanguage.tamil: 'சாதக பிரீமியம்',
      AppLanguage.bengali: 'সাধক প্রিমিয়াম',
    },
    'pwFreeTitle': {
      AppLanguage.english: 'Free Seeker',
      AppLanguage.hindi: 'निःशुल्क साधक',
      AppLanguage.tamil: 'இலவச தேடுபவர்',
      AppLanguage.bengali: 'বিনামূল্যে অন্বেষক',
    },
    'pwPerYear': {
      AppLanguage.english: '/ Year',
      AppLanguage.hindi: '/ वर्ष',
      AppLanguage.tamil: '/ ஆண்டு',
      AppLanguage.bengali: '/ বছর',
    },
    'pwPerMonth': {
      AppLanguage.english: '/ Month',
      AppLanguage.hindi: '/ माह',
      AppLanguage.tamil: '/ மாதம்',
      AppLanguage.bengali: '/ মাস',
    },
    'pwPer3Months': {
      AppLanguage.english: '/ 3 Months',
      AppLanguage.hindi: '/ 3 माह',
      AppLanguage.tamil: '/ 3 மாதங்கள்',
      AppLanguage.bengali: '/ 3 মাস',
    },
    'pwBadgeRecommended': {
      AppLanguage.english: 'RECOMMENDED',
      AppLanguage.hindi: 'अनुशंसित',
      AppLanguage.tamil: 'பரிந்துரைக்கப்படுகிறது',
      AppLanguage.bengali: 'প্রস্তাবিত',
    },
    'pwBadgeQuarterly': {
      AppLanguage.english: 'QUARTERLY',
      AppLanguage.hindi: 'त्रैमासिक',
      AppLanguage.tamil: 'காலாண்டு',
      AppLanguage.bengali: 'ত্রৈমাসিক',
    },
    'pwBadgeMonthly': {
      AppLanguage.english: 'MONTHLY',
      AppLanguage.hindi: 'मासिक',
      AppLanguage.tamil: 'மாதாந்திரம்',
      AppLanguage.bengali: 'মাসিক',
    },
    'pwBenefitEverythingPremium': {
      AppLanguage.english: 'Everything in Sadhaka Premium',
      AppLanguage.hindi: 'साधक प्रीमियम की सभी सुविधाएं',
      AppLanguage.tamil: 'சாதக பிரீமியத்தில் உள்ள அனைத்தும்',
      AppLanguage.bengali: 'সাধক প্রিমিয়ামের সবকিছু',
    },
    'pwBenefitBestValue': {
      AppLanguage.english: 'Best value — save ₹889 vs monthly',
      AppLanguage.hindi: 'सर्वोत्तम मूल्य — मासिक की तुलना में ₹889 बचाएं',
      AppLanguage.tamil: 'சிறந்த மதிப்பு — மாதாந்திரத்தை விட ₹889 சேமிக்கவும்',
      AppLanguage.bengali: 'সেরা মূল্য — মাসিকের তুলনায় ₹889 সাশ্রয়',
    },
    'pwBenefitAnnualBadge': {
      AppLanguage.english: 'Exclusive annual seeker badge',
      AppLanguage.hindi: 'विशेष वार्षिक साधक बैज',
      AppLanguage.tamil: 'பிரத்யேக ஆண்டு தேடுபவர் பேட்ஜ்',
      AppLanguage.bengali: 'একচেটিয়া বার্ষিক অন্বেষক ব্যাজ',
    },
    'pwBenefit3xMemory': {
      AppLanguage.english: '3× longer AI Guru session memory',
      AppLanguage.hindi: '3 गुना लंबी एआई गुरु सत्र स्मृति',
      AppLanguage.tamil: '3 மடங்கு நீண்ட AI குரு அமர்வு நினைவகம்',
      AppLanguage.bengali: '3 গুণ দীর্ঘ এআই গুরু সেশন স্মৃতি',
    },
    'pwBenefitSave98': {
      AppLanguage.english: 'Save ₹98 vs paying monthly',
      AppLanguage.hindi: 'मासिक भुगतान की तुलना में ₹98 बचाएं',
      AppLanguage.tamil: 'மாதாந்திரம் செலுத்துவதை விட ₹98 சேமிக்கவும்',
      AppLanguage.bengali: 'মাসিক পরিশোধের তুলনায় ₹98 সাশ্রয়',
    },
    'pwBenefit166Month': {
      AppLanguage.english: '₹166 / month — an easy commitment',
      AppLanguage.hindi: '₹166 / माह — एक आसान प्रतिबद्धता',
      AppLanguage.tamil: '₹166 / மாதம் — எளிதான உறுதிமொழி',
      AppLanguage.bengali: '₹166 / মাস — একটি সহজ প্রতিশ্রুতি',
    },
    'pwBenefitAllScriptures': {
      AppLanguage.english: 'Access all scriptures (Upanishads, Vedas)',
      AppLanguage.hindi: 'सभी ग्रंथों तक पहुंच (उपनिषद, वेद)',
      AppLanguage.tamil: 'அனைத்து வேதங்களையும் அணுகவும் (உபநிடதங்கள், வேதங்கள்)',
      AppLanguage.bengali: 'সমস্ত শাস্ত্রে প্রবেশ (উপনিষদ, বেদ)',
    },
    'pwBenefitUnlimitedScholar': {
      AppLanguage.english: 'Unlimited AI-powered Chat Scholar',
      AppLanguage.hindi: 'असीमित एआई-संचालित चैट विद्वान',
      AppLanguage.tamil: 'வரம்பற்ற AI-இயங்கும் அரட்டை அறிஞர்',
      AppLanguage.bengali: 'সীমাহীন এআই-চালিত চ্যাট পণ্ডিত',
    },
    'pwBenefitUnlimitedGuru': {
      AppLanguage.english: 'Unlimited introspective AI Guru counseling',
      AppLanguage.hindi: 'असीमित आत्मनिरीक्षण एआई गुरु परामर्श',
      AppLanguage.tamil: 'வரம்பற்ற உள்நோக்கு AI குரு ஆலோசனை',
      AppLanguage.bengali: 'সীমাহীন আত্মদর্শী এআই গুরু পরামর্শ',
    },
    'pwBenefitAudioPlayer': {
      AppLanguage.english: 'Background Audio Wisdom player (18 chapters)',
      AppLanguage.hindi: 'पृष्ठभूमि ऑडियो विजडम प्लेयर (18 अध्याय)',
      AppLanguage.tamil: 'பின்னணி ஆடியோ ஞான பிளேயர் (18 அத்தியாயங்கள்)',
      AppLanguage.bengali: 'ব্যাকগ্রাউন্ড অডিও উইজডম প্লেয়ার (18 অধ্যায়)',
    },
    'pwBenefitGifting': {
      AppLanguage.english: 'Sangha community pass gifting actions',
      AppLanguage.hindi: 'संघ समुदाय पास उपहार क्रियाएं',
      AppLanguage.tamil: 'சங்க சமூக பாஸ் பரிசு செயல்கள்',
      AppLanguage.bengali: 'সংঘ সম্প্রদায় পাস উপহার ক্রিয়া',
    },
    'pwBenefitStandardReader': {
      AppLanguage.english: 'Standard Bhagavad Gita Reader',
      AppLanguage.hindi: 'मानक भगवद्गीता रीडर',
      AppLanguage.tamil: 'நிலையான பகவத் கீதை வாசிப்பான்',
      AppLanguage.bengali: 'স্ট্যান্ডার্ড ভগবদ্গীতা রিডার',
    },
    'pwBenefit6Prompts': {
      AppLanguage.english: '6 daily AI Scripture Scholar prompts',
      AppLanguage.hindi: 'प्रतिदिन 6 एआई शास्त्र विद्वान प्रश्न',
      AppLanguage.tamil: 'தினமும் 6 AI வேத அறிஞர் கேள்விகள்',
      AppLanguage.bengali: 'প্রতিদিন 6টি এআই শাস্ত্র পণ্ডিত প্রম্পট',
    },
    'pwBenefitSadhanaTracker': {
      AppLanguage.english: 'Daily sadhana & streak tracker',
      AppLanguage.hindi: 'दैनिक साधना और स्ट्रीक ट्रैकर',
      AppLanguage.tamil: 'தினசரி சாதனா மற்றும் தொடர் கண்காணிப்பு',
      AppLanguage.bengali: 'দৈনিক সাধনা ও স্ট্রিক ট্র্যাকার',
    },
    'pwActiveAnnual': {
      AppLanguage.english: 'ACTIVE ANNUAL PATH',
      AppLanguage.hindi: 'सक्रिय वार्षिक मार्ग',
      AppLanguage.tamil: 'செயலில் உள்ள ஆண்டு பாதை',
      AppLanguage.bengali: 'সক্রিয় বার্ষিক পথ',
    },
    'pwEmbarkAnnual': {
      AppLanguage.english: 'EMBARK ON ANNUAL PATH',
      AppLanguage.hindi: 'वार्षिक मार्ग शुरू करें',
      AppLanguage.tamil: 'ஆண்டு பாதையில் தொடங்குங்கள்',
      AppLanguage.bengali: 'বার্ষিক পথ শুরু করুন',
    },
    'pwActiveQuarterly': {
      AppLanguage.english: 'ACTIVE QUARTERLY PATH',
      AppLanguage.hindi: 'सक्रिय त्रैमासिक मार्ग',
      AppLanguage.tamil: 'செயலில் உள்ள காலாண்டு பாதை',
      AppLanguage.bengali: 'সক্রিয় ত্রৈমাসিক পথ',
    },
    'pwEmbarkQuarterly': {
      AppLanguage.english: 'EMBARK ON QUARTERLY PATH',
      AppLanguage.hindi: 'त्रैमासिक मार्ग शुरू करें',
      AppLanguage.tamil: 'காலாண்டு பாதையில் தொடங்குங்கள்',
      AppLanguage.bengali: 'ত্রৈমাসিক পথ শুরু করুন',
    },
    'pwActivePremium': {
      AppLanguage.english: 'ACTIVE PREMIUM PATH',
      AppLanguage.hindi: 'सक्रिय प्रीमियम मार्ग',
      AppLanguage.tamil: 'செயலில் உள்ள பிரீமியம் பாதை',
      AppLanguage.bengali: 'সক্রিয় প্রিমিয়াম পথ',
    },
    'pwEmbarkPremium': {
      AppLanguage.english: 'EMBARK ON PREMIUM PATH',
      AppLanguage.hindi: 'प्रीमियम मार्ग शुरू करें',
      AppLanguage.tamil: 'பிரீமியம் பாதையில் தொடங்குங்கள்',
      AppLanguage.bengali: 'প্রিমিয়াম পথ শুরু করুন',
    },
    'pwActivePath': {
      AppLanguage.english: 'ACTIVE PATH',
      AppLanguage.hindi: 'सक्रिय मार्ग',
      AppLanguage.tamil: 'செயலில் உள்ள பாதை',
      AppLanguage.bengali: 'সক্রিয় পথ',
    },
    'pwWelcomeSadhaka': {
      AppLanguage.english: 'Welcome, Sadhaka',
      AppLanguage.hindi: 'स्वागत है, साधक',
      AppLanguage.tamil: 'வரவேற்கிறோம், சாதக',
      AppLanguage.bengali: 'স্বাগতম, সাধক',
    },
    'pwEnterSacredSpace': {
      AppLanguage.english: 'ENTER SACRED SPACE',
      AppLanguage.hindi: 'पवित्र स्थान में प्रवेश करें',
      AppLanguage.tamil: 'புனித இடத்தில் நுழையுங்கள்',
      AppLanguage.bengali: 'পবিত্র স্থানে প্রবেশ করুন',
    },
    // ── Auth screens (login + signup) ──
    'authBeginPath': {
      AppLanguage.english: 'Begin Your Path',
      AppLanguage.hindi: 'अपनी यात्रा शुरू करें',
      AppLanguage.tamil: 'உங்கள் பாதையைத் தொடங்குங்கள்',
      AppLanguage.bengali: 'আপনার পথ শুরু করুন',
    },
    'authWelcomeBack': {
      AppLanguage.english: 'Welcome Back',
      AppLanguage.hindi: 'वापसी पर स्वागत है',
      AppLanguage.tamil: 'மீண்டும் வரவேற்கிறோம்',
      AppLanguage.bengali: 'আবার স্বাগতম',
    },
    'authSignupSubtitle': {
      AppLanguage.english: 'Create an account to save your progress and practice.',
      AppLanguage.hindi: 'अपनी प्रगति और साधना सहेजने के लिए खाता बनाएं।',
      AppLanguage.tamil: 'உங்கள் முன்னேற்றம் மற்றும் பயிற்சியைச் சேமிக்க கணக்கை உருவாக்கவும்.',
      AppLanguage.bengali: 'আপনার অগ্রগতি ও সাধনা সংরক্ষণ করতে একটি অ্যাকাউন্ট তৈরি করুন।',
    },
    'authLoginSubtitle': {
      AppLanguage.english: 'Sign in to continue your spiritual journey.',
      AppLanguage.hindi: 'अपनी आध्यात्मिक यात्रा जारी रखने के लिए साइन इन करें।',
      AppLanguage.tamil: 'உங்கள் ஆன்மீகப் பயணத்தைத் தொடர உள்நுழையவும்.',
      AppLanguage.bengali: 'আপনার আধ্যাত্মিক যাত্রা চালিয়ে যেতে সাইন ইন করুন।',
    },
    'authYourName': {
      AppLanguage.english: 'Your Name',
      AppLanguage.hindi: 'आपका नाम',
      AppLanguage.tamil: 'உங்கள் பெயர்',
      AppLanguage.bengali: 'আপনার নাম',
    },
    'authEmail': {
      AppLanguage.english: 'Email',
      AppLanguage.hindi: 'ईमेल',
      AppLanguage.tamil: 'மின்னஞ்சல்',
      AppLanguage.bengali: 'ইমেল',
    },
    'authPassword': {
      AppLanguage.english: 'Password',
      AppLanguage.hindi: 'पासवर्ड',
      AppLanguage.tamil: 'கடவுச்சொல்',
      AppLanguage.bengali: 'পাসওয়ার্ড',
    },
    'authForgotPassword': {
      AppLanguage.english: 'Forgot password?',
      AppLanguage.hindi: 'पासवर्ड भूल गए?',
      AppLanguage.tamil: 'கடவுச்சொல்லை மறந்தீர்களா?',
      AppLanguage.bengali: 'পাসওয়ার্ড ভুলে গেছেন?',
    },
    'authCreateAccount': {
      AppLanguage.english: 'CREATE ACCOUNT',
      AppLanguage.hindi: 'खाता बनाएं',
      AppLanguage.tamil: 'கணக்கை உருவாக்கு',
      AppLanguage.bengali: 'অ্যাকাউন্ট তৈরি করুন',
    },
    'authSignIn': {
      AppLanguage.english: 'SIGN IN',
      AppLanguage.hindi: 'साइन इन करें',
      AppLanguage.tamil: 'உள்நுழை',
      AppLanguage.bengali: 'সাইন ইন করুন',
    },
    'authOr': {
      AppLanguage.english: 'or',
      AppLanguage.hindi: 'या',
      AppLanguage.tamil: 'அல்லது',
      AppLanguage.bengali: 'অথবা',
    },
    'authContinueGoogle': {
      AppLanguage.english: 'Continue with Google',
      AppLanguage.hindi: 'Google के साथ जारी रखें',
      AppLanguage.tamil: 'Google உடன் தொடரவும்',
      AppLanguage.bengali: 'Google দিয়ে চালিয়ে যান',
    },
    'authAlreadyPath': {
      AppLanguage.english: 'Already on the path? ',
      AppLanguage.hindi: 'पहले से ही पथ पर हैं? ',
      AppLanguage.tamil: 'ஏற்கனவே பாதையில் இருக்கிறீர்களா? ',
      AppLanguage.bengali: 'ইতিমধ্যে পথে আছেন? ',
    },
    'authNewSeeker': {
      AppLanguage.english: 'New seeker? ',
      AppLanguage.hindi: 'नए साधक? ',
      AppLanguage.tamil: 'புதிய தேடுபவரா? ',
      AppLanguage.bengali: 'নতুন অন্বেষক? ',
    },
    'authSignInLink': {
      AppLanguage.english: 'Sign in',
      AppLanguage.hindi: 'साइन इन करें',
      AppLanguage.tamil: 'உள்நுழை',
      AppLanguage.bengali: 'সাইন ইন',
    },
    'authCreateAccountLink': {
      AppLanguage.english: 'Create account',
      AppLanguage.hindi: 'खाता बनाएं',
      AppLanguage.tamil: 'கணக்கை உருவாக்கு',
      AppLanguage.bengali: 'অ্যাকাউন্ট তৈরি',
    },
    'readScripture': {
      AppLanguage.english: 'Read Scripture',
      AppLanguage.tamil: 'வேதங்கள் படித்தல்',
      AppLanguage.hindi: 'शास्त्र पठन',
      AppLanguage.bengali: 'शास्त्र পাঠ',
    },
    'readScriptureSub': {
      AppLanguage.english: 'Study 1 verse from the Bhagavad Gita',
      AppLanguage.tamil: 'பகவத் கீதையில் இருந்து 1 ஸ்லோகம் படிக்கவும்',
      AppLanguage.hindi: 'भगवद्गीता से 1 श्लोक का अध्ययन करें',
      AppLanguage.bengali: 'ভগবদ্গীতা থেকে ১টি শ্লোক অধ্যয়ন করুন',
    },
    'meditateBreathe': {
      AppLanguage.english: 'Meditate & Breathe',
      AppLanguage.tamil: 'தியானம் & சுவாசம்',
      AppLanguage.hindi: 'ध्यान और श्वास',
      AppLanguage.bengali: 'ধ্যান ও শ্বাস',
    },
    'meditateBreatheSub': {
      AppLanguage.english: '10 minutes of silent awareness',
      AppLanguage.tamil: '10 நிமிடங்கள் அமைதியான விழிப்புணர்வு',
      AppLanguage.hindi: '10 मिनट की मौन जागरूकता',
      AppLanguage.bengali: '১০ মিনিট নীরব সচেতনতা',
    },
    'aumJapaChanting': {
      AppLanguage.english: 'Aum Japa Chanting',
      AppLanguage.tamil: 'ஓம் ஜப மந்திரம்',
      AppLanguage.hindi: 'ॐ जप संकीर्तन',
      AppLanguage.bengali: 'ওঁ জপ কীর্তন',
    },
    'currentlyLabel': {
      AppLanguage.english: 'Currently',
      AppLanguage.tamil: 'தற்போது',
      AppLanguage.hindi: 'वर्तमान में',
      AppLanguage.bengali: 'বর্তমানে',
    },
    'roundsLabel': {
      AppLanguage.english: 'rounds',
      AppLanguage.tamil: 'சுற்றுகள்',
      AppLanguage.hindi: 'माला',
      AppLanguage.bengali: 'माला',
    },
    'completedBtn': {
      AppLanguage.english: 'COMPLETED',
      AppLanguage.tamil: 'முடிந்தது',
      AppLanguage.hindi: 'पूर्ण',
      AppLanguage.bengali: 'সম্পন্ন',
    },
    'beginBtn': {
      AppLanguage.english: 'BEGIN',
      AppLanguage.tamil: 'தொடங்கு',
      AppLanguage.hindi: 'शुरू करें',
      AppLanguage.bengali: 'শুরু করুন',
    },
    'sadhanaDashboard': {
      AppLanguage.english: 'Sadhana Dashboard',
      AppLanguage.tamil: 'சாதனா கட்டுப்பாட்டு பலகை',
      AppLanguage.hindi: 'साधना डैशबोर्ड',
      AppLanguage.bengali: 'সাধনা ড্যাশবোর্ড',
    },
    'dayStreakLabel': {
      AppLanguage.english: 'DAY STREAK',
      AppLanguage.tamil: 'நாட்கள் தொடர்ச்சி',
      AppLanguage.hindi: 'दिन की निरंतरता',
      AppLanguage.bengali: 'দিনের ধারাবাহিকতা',
    },
    'completeLabel': {
      AppLanguage.english: 'Complete',
      AppLanguage.tamil: 'நிறைவு',
      AppLanguage.hindi: 'पूर्ण',
      AppLanguage.bengali: 'সম্পন্ন',
    },
    'goalsFulfilled': {
      AppLanguage.english: 'Daily goals fulfilled! Your mind is aligned.',
      AppLanguage.tamil: 'தினசரி இலக்குகள் நிறைவேற்றப்பட்டன! உங்கள் மனம் சீரமைக்கப்பட்டது.',
      AppLanguage.hindi: 'दैनिक लक्ष्य पूरे हुए! आपका मन संरेखित है।',
      AppLanguage.bengali: 'দৈনিক লক্ষ্য অর্জিত হয়েছে! আপনার মন সামঞ্জস্যপূর্ণ।',
    },
    'goalsProgress': {
      AppLanguage.english: 'A path of a thousand miles begins with a single aligned action.',
      AppLanguage.tamil: 'ஆயிரம் மைல் பயணம் ஒரு சிறிய அடியுடன் தொடங்குகிறது.',
      AppLanguage.hindi: 'हजारों मील की यात्रा एक अकेले संरेखित कदम से शुरू होती है।',
      AppLanguage.bengali: 'হাজার মাইলের যাত্রা একটিমাত্র সঠিক পদক্ষেপ দিয়ে শুরু হয়।',
    },
    'todaysGoals': {
      AppLanguage.english: 'TODAYS GOALS',
      AppLanguage.tamil: 'இன்றைய இலக்குகள்',
      AppLanguage.hindi: 'आज के लक्ष्य',
      AppLanguage.bengali: 'আজকের লক্ষ্যসমূহ',
    },
    'minsLabel': {
      AppLanguage.english: 'mins',
      AppLanguage.tamil: 'நிமிடங்கள்',
      AppLanguage.hindi: 'मिनट',
      AppLanguage.bengali: 'মিনিট',
    },
    'add5Mins': {
      AppLanguage.english: '+5 MINS',
      AppLanguage.tamil: '+5 நிமிடங்கள்',
      AppLanguage.hindi: '+5 मिनट',
      AppLanguage.bengali: '+৫ মিনিট',
    },
    'versesReadGoal': {
      AppLanguage.english: 'Scriptural Verses Read',
      AppLanguage.tamil: 'வாசித்த வேத வசனங்கள்',
      AppLanguage.hindi: 'पढ़े गए श्लोक',
      AppLanguage.bengali: 'পঠিত শ্লোক সংখ্যা',
    },
    'versesLabel': {
      AppLanguage.english: 'verses',
      AppLanguage.tamil: 'வசனங்கள்',
      AppLanguage.hindi: 'श्लोक',
      AppLanguage.bengali: 'শ্লোক',
    },
    'add1Verse': {
      AppLanguage.english: '+1 VERSE',
      AppLanguage.tamil: '+1 வசனம்',
      AppLanguage.hindi: '+1 श्लोक',
      AppLanguage.bengali: '+১ শ্লোক',
    },
    'chantingGoal': {
      AppLanguage.english: 'Aum Japa Rounds',
      AppLanguage.tamil: 'ஓம் ஜப சுற்றுகள்',
      AppLanguage.hindi: 'ॐ जप माला',
      AppLanguage.bengali: 'ওঁ জপ সংখ্যা',
    },
    'beadsLabel': {
      AppLanguage.english: 'beads',
      AppLanguage.tamil: 'மணிகள்',
      AppLanguage.hindi: 'मनके',
      AppLanguage.bengali: 'জপ',
    },
    'add10Beads': {
      AppLanguage.english: '+10 BEADS',
      AppLanguage.tamil: '+10 மணிகள்',
      AppLanguage.hindi: '+10 मनके',
      AppLanguage.bengali: '+১০ ஜপ',
    },
    'resetTodayProgress': {
      AppLanguage.english: "Reset Today's Progress",
      AppLanguage.tamil: 'இன்றைய முன்னேற்றத்தை மீட்டமைக்கவும்',
      AppLanguage.hindi: 'आज की प्रगति को रीसेट करें',
      AppLanguage.bengali: 'আজকের অগ্রগতি রিসেট করুন',
    },
    'resetConfirmBody': {
      AppLanguage.english: "This will set today's meditation, verses and chanting back to zero. Your streak is not affected. Continue?",
      AppLanguage.tamil: 'இது இன்றைய தியானம், வசனங்கள் மற்றும் ஜபத்தை பூஜ்ஜியமாக்கும். உங்கள் தொடர் பாதிக்கப்படாது. தொடரவா?',
      AppLanguage.hindi: 'इससे आज का ध्यान, श्लोक और जप शून्य हो जाएगा। आपकी निरंतरता (स्ट्रीक) प्रभावित नहीं होगी। जारी रखें?',
      AppLanguage.bengali: 'এটি আজকের ধ্যান, শ্লোক ও জপ শূন্যে ফিরিয়ে দেবে। আপনার স্ট্রিক প্রভাবিত হবে না। চালিয়ে যাবেন?',
    },
    'resetConfirmBtn': {
      AppLanguage.english: 'Reset',
      AppLanguage.tamil: 'மீட்டமை',
      AppLanguage.hindi: 'रीसेट करें',
      AppLanguage.bengali: 'রিসেট',
    },
    'readingOptions': {
      AppLanguage.english: 'Reading Options',
      AppLanguage.tamil: 'வாசிப்பு விருப்பங்கள்',
      AppLanguage.hindi: 'पठन विकल्प',
      AppLanguage.bengali: 'পঠন விருப்பসমূহ',
    },
    'fontSize': {
      AppLanguage.english: 'Font Size',
      AppLanguage.tamil: 'எழுத்து அளவு',
      AppLanguage.hindi: 'अक्षर का आकार',
      AppLanguage.bengali: 'অক্ষরের সাইজ',
    },
    'showSanskritDevanagari': {
      AppLanguage.english: 'Show Sanskrit (Devanagari)',
      AppLanguage.tamil: 'சமஸ்கிருதம் காட்டு (தேவநாகரி)',
      AppLanguage.hindi: 'संस्कृत दिखाएं (देवनागरी)',
      AppLanguage.bengali: 'সংস্কৃত দেখান (দেবনাগরী)',
    },
    'showSanskritTransliteration': {
      AppLanguage.english: 'Show Sanskrit (Transliteration)',
      AppLanguage.tamil: 'சமஸ்கிருதம் காட்டு (ஒலிப்பெயர்ப்பு)',
      AppLanguage.hindi: 'संस्कृत दिखाएं (लिप्यंतरण)',
      AppLanguage.bengali: 'সংস্কৃত দেখান (প্রতিলিপি)',
    },
    'showTranslationToggle': {
      AppLanguage.english: 'Show English Translation',
      AppLanguage.tamil: 'ஆங்கில மொழிபெயர்ப்பு காட்டு',
      AppLanguage.hindi: 'अनुवाद दिखाएं',
      AppLanguage.bengali: 'অনুবাদ দেখান',
    },
    'showCommentaryToggle': {
      AppLanguage.english: 'Show Commentary',
      AppLanguage.tamil: 'விளக்கவுரை காட்டு',
      AppLanguage.hindi: 'टीका दिखाएं',
      AppLanguage.bengali: 'ভাষ্য দেখান',
    },
    'showWordMeanings': {
      AppLanguage.english: 'Show Word Meanings',
      AppLanguage.tamil: 'சொல் அர்த்தங்கள் காட்டு',
      AppLanguage.hindi: 'शब्द अर्थ दिखाएं',
      AppLanguage.bengali: 'শব্দার্থ দেখান',
    },
    'chapterLabel': {
      AppLanguage.english: 'Chapter',
      AppLanguage.tamil: 'அத்தியாயம்',
      AppLanguage.hindi: 'अध्याय',
      AppLanguage.bengali: 'অধ্যায়',
    },
    'verseLabel': {
      AppLanguage.english: 'Verse',
      AppLanguage.tamil: 'ஸ்லோகம்',
      AppLanguage.hindi: 'श्लोक',
      AppLanguage.bengali: 'শ্লোক',
    },
    'scriptureSearch': {
      AppLanguage.english: 'Scripture Search',
      AppLanguage.tamil: 'வேத தேடல்',
      AppLanguage.hindi: 'शास्त्र खोज',
      AppLanguage.bengali: 'শাস্ত্র অনুসন্ধান',
    },
    'searchPlaceholder': {
      AppLanguage.english: 'Search verses (e.g. Karma, Gita 2.47, Soul)...',
      AppLanguage.tamil: 'ஸ்லோகங்களைத் தேடுங்கள் (எ.கா. கர்மா, கீதை 2.47)...',
      AppLanguage.hindi: 'श्लोक खोजें (जैसे कर्म, गीता 2.47, आत्मा)...',
      AppLanguage.bengali: 'শ্লোক খুঁজুন (উদাঃ কর্ম, গীতা ২.৪৭, আত্মা)...',
    },
    'searchNoResults': {
      AppLanguage.english: 'No matching verses found. Try keywords like "duty", "body", "devotion", or chapter indices.',
      AppLanguage.tamil: 'பொருந்தும் ஸ்லோகங்கள் இல்லை. "கடமை", "ஆத்மா" போன்ற வார்த்தைகளை முயற்சிக்கவும்.',
      AppLanguage.hindi: 'कोई श्लोक नहीं मिला। "कर्तव्य", "आत्मा", "भक्ति" जैसे शब्दों का प्रयोग करें।',
      AppLanguage.bengali: 'কোনো শ্লোক পাওয়া যায়নি। "কর্তব্য", "আত্মা", "ভক্তি" ইত্যাদি শব্দ ব্যবহার করুন।',
    },
    'searchError': {
      AppLanguage.english: 'Search error occurred',
      AppLanguage.tamil: 'தேடல் பிழை ஏற்பட்டது',
      AppLanguage.hindi: 'खोज में त्रुटि हुई',
      AppLanguage.bengali: 'অনুসন্ধানে ত্রুটি ঘটেছে',
    },
    'searchEmptyTitle': {
      AppLanguage.english: 'Search the Scriptures',
      AppLanguage.tamil: 'வேதங்களில் தேடுங்கள்',
      AppLanguage.hindi: 'शास्त्रों में खोजें',
      AppLanguage.bengali: 'শাস্ত্রসমূহে অনুসন্ধান করুন',
    },
    'searchEmptyDesc': {
      AppLanguage.english: 'Perform a semantic word search or lookup a verse code like "BG 2.47" to receive immediate translation and spiritual context.',
      AppLanguage.tamil: 'உடனடி மொழிபெயர்ப்பு மற்றும் ஆன்மீக பின்னணியைப் பெற "BG 2.47" போன்ற குறியீடுகளைத் தேடுங்கள்.',
      AppLanguage.hindi: 'तत्काल अनुवाद और आध्यात्मिक संदर्भ प्राप्त करने के लिए "BG 2.47" जैसा श्लोक कोड खोजें।',
      AppLanguage.bengali: 'তাত্ক্ষণিক অনুবাদ ও আধ্যাত্মিক প্রসঙ্গ পেতে "BG 2.47" এর মতো শ্লোক কোড অনুসন্ধান করুন।',
    },
    'giftWisdomPassTitle': {
      AppLanguage.english: 'Gift a Wisdom Pass',
      AppLanguage.tamil: 'ஞான பாஸை பரிசளிக்கவும்',
      AppLanguage.hindi: 'ज्ञान पास उपहार में दें',
      AppLanguage.bengali: 'জ্ঞান পাস উপহার দিন',
    },
    'giftWisdomPassDesc': {
      AppLanguage.english: 'Buy a Sadhaka (Premium) monthly pass for a friend. A digital pass code will be generated, and your gift will be announced to the Sangha community.',
      AppLanguage.tamil: 'ஒரு நண்பருக்கு சாதகா (பிரீமியம்) மாதாந்திர பாஸ் வாங்கவும். உங்கள் பரிசு சங்கம் சமூகத்திற்கு அறிவிக்கப்படும்.',
      AppLanguage.hindi: 'किसी मित्र के लिए साधक (प्रीमियम) मासिक पास खरीदें। आपका उपहार संघ समुदाय को घोषित किया जाएगा।',
      AppLanguage.bengali: 'বন্ধুর জন্য সাধক (প্রিমিয়াম) মাসিক পাস কিনুন। আপনার উপহার সংঘের সদস্যদের জানানো হবে।',
    },
    'friendNameLabel': {
      AppLanguage.english: "Friend's Name",
      AppLanguage.tamil: 'நண்பரின் பெயர்',
      AppLanguage.hindi: 'मित्र का नाम',
      AppLanguage.bengali: 'বন্ধুর নাম',
    },
    'cancelBtn': {
      AppLanguage.english: 'CANCEL',
      AppLanguage.tamil: 'ரத்துசெய்',
      AppLanguage.hindi: 'रद्द करें',
      AppLanguage.bengali: 'বাতিল',
    },
    'giftPassBtn': {
      AppLanguage.english: 'GIFT PASS',
      AppLanguage.tamil: 'பாஸ் பரிசளி',
      AppLanguage.hindi: 'पास उपहार दें',
      AppLanguage.bengali: 'পাস উপহার দিন',
    },
    'giftSuccessPrefix': {
      AppLanguage.english: 'Sadhaka pass gifted to',
      AppLanguage.tamil: 'சாதகா பாஸ் இவருக்கு பரிசளிக்கப்பட்டது:',
      AppLanguage.hindi: 'साधक पास सफलतापूर्वक उपहार दिया गया:',
      AppLanguage.bengali: 'সাধক পাস উপহার দেওয়া হয়েছে:',
    },
    'giftSuccessSuffix': {
      AppLanguage.english: '!',
      AppLanguage.tamil: '!',
      AppLanguage.hindi: 'को!',
      AppLanguage.bengali: '-কে!',
    },
    'tabSanghaTitle': {
      AppLanguage.english: 'Sangha',
      AppLanguage.tamil: 'சங்கம்',
      AppLanguage.hindi: 'संघ',
      AppLanguage.bengali: 'সংঘ',
    },
    'shareReflectionPlaceholder': {
      AppLanguage.english: 'Share an inspiring scriptural reflection...',
      AppLanguage.tamil: 'ஒரு ஆன்மீக சிந்தனையை பகிர்ந்து கொள்ளுங்கள்...',
      AppLanguage.hindi: 'एक प्रेरणादायक आध्यात्मिक विचार साझा करें...',
      AppLanguage.bengali: 'একটি অনুপ্রেরণামূলক আধ্যাত্মিক ভাবনা শেয়ার করুন...',
    },
    'replyBtn': {
      AppLanguage.english: 'Reply',
      AppLanguage.tamil: 'பதில் அளி',
      AppLanguage.hindi: 'उत्तर दें',
      AppLanguage.bengali: 'উত্তর দিন',
    },
    'commentSyncMsg': {
      AppLanguage.english: 'Sangha comment threads are syncing with the servers.',
      AppLanguage.tamil: 'சங்க கருத்துக்கள் சர்வர்களுடன் ஒத்திசைக்கப்படுகின்றன.',
      AppLanguage.hindi: 'संघ की टिप्पणियां सर्वर के साथ सिंक हो रही हैं।',
      AppLanguage.bengali: 'সংঘের মন্তব্যসমূহ সার্ভারের সাথে সিঙ্ক হচ্ছে।',
    },
    'post_1': {
      AppLanguage.english: 'Just finished studying Gita Chapter 2 Verse 47. It is such a deep reminder to focus entirely on the quality of our actions and surrender the expectations of success or failure. Completely transformed my work mindset this morning.',
      AppLanguage.tamil: 'பகவத் கீதை அத்தியாயம் 2 ஸ்லோகம் 47 ஐ படித்து முடித்தேன். செயல்களின் தரத்தில் மட்டுமே கவனம் செலுத்தி, வெற்றி தோல்விகளை இறைவனிடம் ஒப்படைக்க வேண்டும் என்பதை இது நினைவூட்டுகிறது.',
      AppLanguage.hindi: 'अभी गीता अध्याय 2 श्लोक 47 का अध्ययन पूरा किया। यह हमें याद दिलाता है कि हम केवल कर्म की गुणवत्ता पर ध्यान दें और फल की चिंता छोड़ दें। आज सुबह मेरे काम करने के नजरिए को इसने पूरी तरह बदल दिया।',
      AppLanguage.bengali: 'এইমাত্র গীতার ২য় অধ্যায়ের ৪৭ নম্বর শ্লোক পাঠ সম্পন্ন করলাম। ফলের আশা ত্যাগ করে কেবল কর্মে মনোনিবেশ করার এক গভীর শিক্ষা এটি। আজ সকালে আমার কাজের মানসিকতা এটি সম্পূর্ণ বদলে দিয়েছে।',
    },
    'post_2': {
      AppLanguage.english: 'Gifted a Sadhaka (Premium) annual subscription pass to seeker Anand.',
      AppLanguage.tamil: 'ஆனந்த் என்ற தேடுபவருக்கு சாதகா (பிரீமியம்) வருடாந்திர சந்தா பரிசளிக்கப்பட்டது.',
      AppLanguage.hindi: 'साधक आनंद को साधक (प्रीमियम) वार्षिक सदस्यता पास उपहार में दिया।',
      AppLanguage.bengali: 'সাধক আনন্দকে সাধক (প্রিমিয়াম) বার্ষিক সদস্যপদ উপহার দেওয়া হয়েছে।',
    },
    'post_3': {
      AppLanguage.english: 'Had a beautiful introspective session in AI Guru Mode today. Discussing the analogy of the waves on the ocean surface vs. the peaceful silence underneath really helped dissolve my anxiety. Daily sadhana streak is now 12 days!',
      AppLanguage.tamil: 'இன்று AI குருவிடம் ஒரு சிறந்த உரையாடல் நிகழ்ந்தது. கடல் அலைகளின் ஒப்பீடு என் கவலையை போக்க உதவியது. தினசரி சாதனா 12 நாட்களை எட்டியுள்ளது!',
      AppLanguage.hindi: 'आज एआई गुरु मोड में एक सुंदर अंतर्मुखी सत्र रहा। समुद्र की सतह की लहरों बनाम नीचे की शांत मौन की उपमा पर चर्चा करने से मेरी चिंता दूर हो गई। दैनिक साधना का सिलसिला अब 12 दिनों का हो गया है!',
      AppLanguage.bengali: 'আজ এআই গুরু মোডে একটি সুন্দর আত্মদর্শনমূলক সেশন ছিল। সমুদ্রের উত্তাল ঢেউ বনাম গভীর শান্ত জলের রূপকটি আমার উদ্বেগ দূর করতে সাহায্য করেছে। দৈনিক সাধনার ধারাবাহিকতা এখন ১২ দিন!',
    },
    'youSeeker': {
      AppLanguage.english: 'You (Seeker)',
      AppLanguage.tamil: 'நீங்கள் (தேடுபவர்)',
      AppLanguage.hindi: 'आप (साधक)',
      AppLanguage.bengali: 'আপনি (অন্বেষক)',
    },
    'sanghaBot': {
      AppLanguage.english: 'Sangha Bot',
      AppLanguage.tamil: 'சங்க போட்',
      AppLanguage.hindi: 'संघ बोट',
      AppLanguage.bengali: 'সংঘ বট',
    },
    'aSeeker': {
      AppLanguage.english: 'A Seeker',
      AppLanguage.tamil: 'ஒரு தேடுபவர்',
      AppLanguage.hindi: 'एक साधक',
      AppLanguage.bengali: 'একজন অন্বেষক',
    },
    'giftPostContentPrefix': {
      AppLanguage.english: 'Gifted a Sadhaka (Premium) monthly pass to seeker',
      AppLanguage.tamil: 'தேடுபவருக்கு சாதகா (பிரீமியம்) மாதாந்திர பாஸ் பரிசளிக்கப்பட்டது:',
      AppLanguage.hindi: 'साधक को साधक (प्रीमियम) मासिक पास उपहार में दिया:',
      AppLanguage.bengali: 'অন্বেষককে সাধক (প্রিমিয়াম) মাসিক পাস উপহার দেওয়া হয়েছে:',
    },
    'audioWisdomTitle': {
      AppLanguage.english: 'Audio Wisdom',
      AppLanguage.tamil: 'ஒலி ஞானம்',
      AppLanguage.hindi: 'ऑडियो ज्ञान',
      AppLanguage.bengali: 'অডিও জ্ঞান',
    },
    'wisdomChannels': {
      AppLanguage.english: 'WISDOM CHANNELS',
      AppLanguage.tamil: 'ஞான அலைவரிசைகள்',
      AppLanguage.hindi: 'ज्ञान चैनल',
      AppLanguage.bengali: 'ज्ञान चैनलসমূহ',
    },
    'track1_title': {
      AppLanguage.english: 'The Path of Selfless Service',
      AppLanguage.tamil: 'சுயநலமற்ற சேவையின் பாதை',
      AppLanguage.hindi: 'निष्काम सेवा का मार्ग',
      AppLanguage.bengali: 'নিষ্কাম সেবার পথ',
    },
    'track1_chapter': {
      AppLanguage.english: 'Gita Chapter 2 Wisdom Summary',
      AppLanguage.tamil: 'கீதை அத்தியாயம் 2 ஞானச் சுருக்கம்',
      AppLanguage.hindi: 'गीता अध्याय 2 ज्ञान सारांश',
      AppLanguage.bengali: 'গীতা অধ্যায় ২ জ্ঞান সারসংক্ষেপ',
    },
    'track2_title': {
      AppLanguage.english: 'Meditation on the Eternal Self',
      AppLanguage.tamil: 'நித்திய ஆத்மாவின் மீதான தியானம்',
      AppLanguage.hindi: 'शाश्वत आत्मा पर ध्यान',
      AppLanguage.bengali: 'সনাতন আত্মার ধ্যান',
    },
    'track2_chapter': {
      AppLanguage.english: 'Gita Chapter 6 Dhyana Yoga',
      AppLanguage.tamil: 'கீதை அத்தியாயம் 6 தியான யோகம்',
      AppLanguage.hindi: 'गीता अध्याय 6 ध्यान योग',
      AppLanguage.bengali: 'গীতা অধ্যায় ৬ ধ্যান যোগ',
    },
    'track3_title': {
      AppLanguage.english: 'Absolute Surrender & Liberation',
      AppLanguage.tamil: 'முழுமையான சரணாகதி & விடுதலை',
      AppLanguage.hindi: 'पूर्ण समर्पण और मोक्ष',
      AppLanguage.bengali: 'পূর্ণ শরণাগতি ও মুক্তি',
    },
    'track3_chapter': {
      AppLanguage.english: 'Gita Chapter 18 Moksha Yoga',
      AppLanguage.tamil: 'கீதை அத்தியாயம் 18 மோட்ச யோகம்',
      AppLanguage.hindi: 'गीता अध्याय 18 मोक्ष योग',
      AppLanguage.bengali: 'গীতা অধ্যায় ১৮ মোক্ষ योग',
    },
    'track_narrator_bodhi': {
      AppLanguage.english: 'Narrated by Swami Bodhi',
      AppLanguage.tamil: 'சுவாமி போதி விவரித்தார்',
      AppLanguage.hindi: 'स्वामी बोधि द्वारा वर्णित',
      AppLanguage.bengali: 'স্বামী বোধি কর্তৃক বর্ণিত',
    },
    'track_narrator_devi': {
      AppLanguage.english: 'Narrated by Ma Devi',
      AppLanguage.tamil: 'மா தேவி விவரித்தார்',
      AppLanguage.hindi: 'मां देवी द्वारा वर्णित',
      AppLanguage.bengali: 'মা দেবী কর্তৃক বর্ণিত',
    },
    'consultingScriptures': {
      AppLanguage.english: 'Consulting the scriptures...',
      AppLanguage.tamil: 'வேதங்களை கலந்தாலோசிக்கிறது...',
      AppLanguage.hindi: 'शास्त्रों से परामर्श कर रहे हैं...',
      AppLanguage.bengali: 'শাস্ত্র পর্যালোচনা করা হচ্ছে...',
    },
    'chatScripturePlaceholder': {
      AppLanguage.english: 'Ask about duties, soul, karma...',
      AppLanguage.tamil: 'கடமை, ஆத்மா, கர்மா பற்றி கேளுங்கள்...',
      AppLanguage.hindi: 'कर्तव्य, आत्मा, कर्म के बारे में पूछें...',
      AppLanguage.bengali: 'কর্তব্য, আত্মা, কর্ম সম্পর্কে জিজ্ঞাসা করুন...',
    },
    'listeningDeeply': {
      AppLanguage.english: 'Listening deeply...',
      AppLanguage.tamil: 'ஆழமாக கவனிக்கிறது...',
      AppLanguage.hindi: 'गहनता से सुन रहे हैं...',
      AppLanguage.bengali: 'মনোযোগ দিয়ে শোনা হচ্ছে...',
    },
    'resetMindTooltip': {
      AppLanguage.english: 'Reset mind',
      AppLanguage.tamil: 'மனதை மீட்டமைக்கவும்',
      AppLanguage.hindi: 'मन को रीसेट करें',
      AppLanguage.bengali: 'মন শান্ত/রিসেট করুন',
    },
    'chatGuruPlaceholder': {
      AppLanguage.english: 'Share what is in your heart...',
      AppLanguage.tamil: 'உங்கள் இதயத்தில் உள்ளதை பகிர்ந்து கொள்ளுங்கள்...',
      AppLanguage.hindi: 'अपने दिल की बात साझा करें...',
      AppLanguage.bengali: 'আপনার মনের কথা বলুন...',
    },
    'mySanctuary': {
      AppLanguage.english: 'My Sanctuary',
      AppLanguage.tamil: 'என் புகலிடம்',
      AppLanguage.hindi: 'मेरी शरणस्थली',
      AppLanguage.bengali: 'আমার সাধনা কক্ষ',
    },
    'levelPractitioner': {
      AppLanguage.english: 'Level: Practitioner',
      AppLanguage.tamil: 'நிலை: பயிற்சியாளர்',
      AppLanguage.hindi: 'स्तर: अभ्यासी',
      AppLanguage.bengali: 'স্তর: সাধক',
    },
    'savedWisdom': {
      AppLanguage.english: 'SAVED WISDOM',
      AppLanguage.tamil: 'சேமித்த ஞானம்',
      AppLanguage.hindi: 'सहेजा गया ज्ञान',
      AppLanguage.bengali: 'সংরক্ষিত জ্ঞান',
    },
    'myJournal': {
      AppLanguage.english: 'MY JOURNAL',
      AppLanguage.tamil: 'என் நாட்குறிப்பு',
      AppLanguage.hindi: 'मेरी डायरी',
      AppLanguage.bengali: 'আমার ডায়েরি',
    },
    'noSavedVersesYet': {
      AppLanguage.english: 'No saved verses yet. Tap the bookmark icon on scripture cards to preserve them in your sanctuary.',
      AppLanguage.tamil: 'இன்னும் சேமித்த வசனங்கள் இல்லை. அவற்றை உங்கள் புகலிடத்தில் சேமிக்க புக்மார்க் ஐகானைத் தட்டவும்.',
      AppLanguage.hindi: 'अभी तक कोई श्लोक सहेजा नहीं गया है। उन्हें अपनी शरणस्थली में सुरक्षित करने के लिए श्लोक कार्ड पर बुकमार्क आइकन दबाएं।',
      AppLanguage.bengali: 'এখনও কোনো শ্লোক সংরক্ষিত হয়নি। আপনার সাধনা কক্ষে সংরক্ষণ করতে বুকমার্ক আইকনটি ট্যাপ করুন।',
    },
    'spiritualContemplations': {
      AppLanguage.english: 'SPIRITUAL CONTEMPLATIONS',
      AppLanguage.tamil: 'ஆன்மீக சிந்தனைகள்',
      AppLanguage.hindi: 'आध्यात्मिक चिंतन',
      AppLanguage.bengali: 'আধ্যাত্মিক চিন্তাভাবনা',
    },
    'journalDesc': {
      AppLanguage.english: 'Write down your reflections, realizations, and personal goals on your path of study.',
      AppLanguage.tamil: 'உங்கள் படிப்பின் பாதையில் உங்கள் பிரதிபலிப்புகள் மற்றும் தனிப்பட்ட இலக்குகளை எழுதுங்கள்.',
      AppLanguage.hindi: 'अध्ययन के अपने मार्ग पर अपने विचारों और व्यक्तिगत लक्ष्यों को लिखें।',
      AppLanguage.bengali: 'আপনার অধ্যয়ন পথের ভাবনা ও ব্যক্তিগত লক্ষ্যসমূহ লিখে রাখুন।',
    },
    'journalPlaceholder': {
      AppLanguage.english: 'Enter your thoughts here...',
      AppLanguage.tamil: 'உங்கள் எண்ணங்களை இங்கே உள்ளிடவும்...',
      AppLanguage.hindi: 'अपने विचार यहाँ लिखें...',
      AppLanguage.bengali: 'আপনার চিন্তা এখানে লিখুন...',
    },
    'saveReflections': {
      AppLanguage.english: 'SAVE REFLECTIONS',
      AppLanguage.tamil: 'சிந்தனைகளைச் சேமிக்கவும்',
      AppLanguage.hindi: 'चिंतन सहेजें',
      AppLanguage.bengali: 'ভাবনা সংরক্ষণ করুন',
    },
    'journalSavedMsg': {
      AppLanguage.english: 'Journal note saved to offline vessel.',
      AppLanguage.tamil: 'நாட்குறிப்பு உள்ளூர் சாதனத்தில் சேமிக்கப்பட்டது.',
      AppLanguage.hindi: 'डायरी नोट ऑफलाइन सुरक्षित कर लिया गया है।',
      AppLanguage.bengali: 'ডায়েরি নোট অফলাইনে সংরক্ষিত হয়েছে।',
    },
    'sanctuarySettings': {
      AppLanguage.english: 'Settings',
      AppLanguage.tamil: 'அமைப்புகள்',
      AppLanguage.hindi: 'सेटिंग्स',
      AppLanguage.bengali: 'সেটিংস',
    },
    'upgradeBtn': {
      AppLanguage.english: 'Upgrade',
      AppLanguage.hindi: 'अपग्रेड करें',
      AppLanguage.tamil: 'மேம்படுத்து',
      AppLanguage.bengali: 'আপগ্রেড',
    },
    'freePromptsLeft': {
      AppLanguage.english: '{n} free prompt left today',
      AppLanguage.hindi: 'आज {n} मुफ्त प्रश्न बचे हैं',
      AppLanguage.tamil: 'இன்று {n} இலவச கேள்வி உள்ளது',
      AppLanguage.bengali: 'আজ {n}টি বিনামূল্যে প্রম্পট বাকি',
    },
    'deepMemoryActive': {
      AppLanguage.english: '✦ Deep memory active — your Guru is recalling more of this conversation',
      AppLanguage.hindi: '✦ गहन स्मृति सक्रिय — आपके गुरु इस वार्तालाप का अधिक भाग स्मरण रख रहे हैं',
      AppLanguage.tamil: '✦ ஆழ்ந்த நினைவு செயலில் — உங்கள் குரு இந்த உரையாடலை அதிகம் நினைவில் வைத்துள்ளார்',
      AppLanguage.bengali: '✦ গভীর স্মৃতি সক্রিয় — আপনার গুরু এই কথোপকথনের আরও বেশি মনে রাখছেন',
    },
    'dailyLimitHint': {
      AppLanguage.english: 'Daily limit reached — upgrade to continue',
      AppLanguage.hindi: 'दैनिक सीमा समाप्त — जारी रखने के लिए अपग्रेड करें',
      AppLanguage.tamil: 'தினசரி வரம்பு முடிந்தது — தொடர மேம்படுத்துங்கள்',
      AppLanguage.bengali: 'দৈনিক সীমা শেষ — চালিয়ে যেতে আপগ্রেড করুন',
    },
    'dailyLimitBanner': {
      AppLanguage.english: 'Daily limit of {n} prompts reached. Upgrade for unlimited access.',
      AppLanguage.hindi: '{n} प्रश्नों की दैनिक सीमा समाप्त। असीमित उपयोग के लिए अपग्रेड करें।',
      AppLanguage.tamil: '{n} கேள்விகளின் தினசரி வரம்பு முடிந்தது. வரம்பற்ற அணுகலுக்கு மேம்படுத்துங்கள்.',
      AppLanguage.bengali: '{n}টি প্রম্পটের দৈনিক সীমা শেষ। সীমাহীন অ্যাক্সেসের জন্য আপগ্রেড করুন।',
    },
    'upgradeAccount': {
      AppLanguage.english: 'Upgrade Account',
      AppLanguage.tamil: 'கணக்கை மேம்படுத்தவும்',
      AppLanguage.hindi: 'खाता अपग्रेड करें',
      AppLanguage.bengali: 'অ্যাকাউন্ট আপগ্রেড করুন',
    },
    'aiSpiritualGuide': {
      AppLanguage.english: 'AI Spiritual Guide',
      AppLanguage.tamil: 'AI ஆன்மீக வழிகாட்டி',
      AppLanguage.hindi: 'एआई आध्यात्मिक मार्गदर्शक',
      AppLanguage.bengali: 'এআই আধ্যাত্মিক নির্দেশক',
    },
    'tabScriptureScholar': {
      AppLanguage.english: 'SCRIPTURE SCHOLAR',
      AppLanguage.tamil: 'வேத அறிஞர்',
      AppLanguage.hindi: 'शास्त्र विद्वान',
      AppLanguage.bengali: 'শাস্ত্র পণ্ডিত',
    },
    'tabAiGuruMode': {
      AppLanguage.english: 'AI GURU MODE',
      AppLanguage.tamil: 'AI குரு பயன்முறை',
      AppLanguage.hindi: 'एआई गुरु मोड',
      AppLanguage.bengali: 'এআই গুরু মোড',
    },
    'offlineLibrary': {
      AppLanguage.english: 'Offline Download Library',
      AppLanguage.tamil: 'ஆஃப்லைன் பதிவிறக்க நூலகம்',
      AppLanguage.hindi: 'ऑफलाइन डाउनलोड लाइब्रेरी',
      AppLanguage.bengali: 'অফলাইন লাইব্রেরি',
    },
    'simulateOfflineReader': {
      AppLanguage.english: 'Simulate Offline Reader (Gita 2.47)',
      AppLanguage.tamil: 'ஆஃப்லைன் வாசகரை உருவகப்படுத்து (கீதை 2.47)',
      AppLanguage.hindi: 'ऑफलाइन पठन का अनुकरण (गीता 2.47)',
      AppLanguage.bengali: 'অফলাইন পঠন সিমুলেশন (গীতা ২.৪৭)',
    },
    'offlineReaderTitle': {
      AppLanguage.english: 'Offline Reader',
      AppLanguage.tamil: 'ஆஃப்லைன் வாசகர்',
      AppLanguage.hindi: 'ऑफलाइन पाठक',
      AppLanguage.bengali: 'অফলাইন রিডার',
    },
    'offlineModeActive': {
      AppLanguage.english: 'Offline Mode Active. Displaying local vessel cache.',
      AppLanguage.tamil: 'ஆஃப்லைன் பயன்முறை செயலில் உள்ளது. உள்ளூர் தற்காலிக சேமிப்பைக் காட்டுகிறது.',
      AppLanguage.hindi: 'ऑफलाइन मोड सक्रिय है। स्थानीय कैश प्रदर्शित कर रहा है।',
      AppLanguage.bengali: 'অফলাইন মোড সক্রিয়। লোকাল ক্যাশ প্রদর্শিত হচ্ছে।',
    },
    'offlineVaultDesc': {
      AppLanguage.english: 'Pre-cached in your spiritual vault.',
      AppLanguage.tamil: 'உங்கள் ஆன்மீக களஞ்சியத்தில் முன்கூட்டியே சேமிக்கப்பட்டுள்ளது.',
      AppLanguage.hindi: 'आपकी आध्यात्मिक तिजोरी में पहले से सुरक्षित।',
      AppLanguage.bengali: 'আপনার আধ্যাত্মিক ভল্টে সংরক্ষিত।',
    },
    'offlineLibraryTitle': {
      AppLanguage.english: 'Offline Library',
      AppLanguage.tamil: 'ஆஃப்லைன் நூலகம்',
      AppLanguage.hindi: 'ऑफलाइन लाइब्रेरी',
      AppLanguage.bengali: 'অফলাইন লাইব্রেরি',
    },
    'offlineLibraryDesc': {
      AppLanguage.english: 'Download scriptures, translations, and audio summaries directly to your device storage to seek wisdom even without a network vessel.',
      AppLanguage.tamil: 'இணையம் இல்லாவிட்டாலும் ஞானத்தைப் பெற வேதங்களையும் ஆடியோக்களையும் உங்கள் சாதனத்தில் பதிவிறக்கவும்.',
      AppLanguage.hindi: 'नेटवर्क के बिना भी ज्ञान प्राप्त करने के लिए शास्त्रों और ऑडियो सारांशों को सीधे अपने डिवाइस पर डाउनलोड करें।',
      AppLanguage.bengali: 'ইন্টারনেট কানেকশন ছাড়াই জ্ঞান অর্জনের জন্য শাস্ত্র ও অডিও সারসংক্ষেপ আপনার ডিভাইসে ডাউনলোড করুন।',
    },
    'gitaTitle': {
      AppLanguage.english: 'Bhagavad Gita (Complete)',
      AppLanguage.tamil: 'பகவத் கீதை (முழுமையானது)',
      AppLanguage.hindi: 'भगवद्गीता (पूर्ण)',
      AppLanguage.bengali: 'ভগবদ্গীতা (সম্পূর্ণ)',
    },
    'upanishadsTitle': {
      AppLanguage.english: 'Principal Upanishads (Vol 1)',
      AppLanguage.tamil: 'முக்கிய உபநிடதங்கள் (தொகுதி 1)',
      AppLanguage.hindi: 'प्रमुख उपनिषद (भाग 1)',
      AppLanguage.bengali: 'প্রধান উপনিষদ (খণ্ড ১)',
    },
    'vedasTitle': {
      AppLanguage.english: 'Vedas Selections (Rig & Yajur)',
      AppLanguage.tamil: 'வேதங்களின் தேர்வுகள் (ரிக் & யஜுர்)',
      AppLanguage.hindi: 'वेद चयन (ऋग और यजुर्वेद)',
      AppLanguage.bengali: 'বেদ সংকলন (ঋগ ও যজুর্বেদ)',
    },
    'audioPackTitle': {
      AppLanguage.english: 'Daily Audio Summaries Pack',
      AppLanguage.tamil: 'தினசரி ஆடியோ சுருக்கங்களின் தொகுப்பு',
      AppLanguage.hindi: 'दैनिक ऑडियो सारांश पैक',
      AppLanguage.bengali: 'দৈনিক অডিও সারসংক্ষেপ প্যাক',
    },
    'sizeLabel': {
      AppLanguage.english: 'Size',
      AppLanguage.tamil: 'அளவு',
      AppLanguage.hindi: 'आकार',
      AppLanguage.bengali: 'সাইজ',
    },
    'premiumBtn': {
      AppLanguage.english: 'PREMIUM',
      AppLanguage.tamil: 'பிரீமியம்',
      AppLanguage.hindi: 'प्रीमियम',
      AppLanguage.bengali: 'প্রিমিয়াম',
    },
    'cachedBtn': {
      AppLanguage.english: 'CACHED',
      AppLanguage.tamil: 'சேமிக்கப்பட்டது',
      AppLanguage.hindi: 'सहेजा गया',
      AppLanguage.bengali: 'সংরক্ষিত',
    },
    'downloadBtn': {
      AppLanguage.english: 'DOWNLOAD',
      AppLanguage.tamil: 'பதிவிறக்கு',
      AppLanguage.hindi: 'डाउनलोड',
      AppLanguage.bengali: 'ডাউনলোড',
    },
    'downloadingMsg': {
      AppLanguage.english: 'downloaded to local storage vessel.',
      AppLanguage.tamil: 'சாதனத்தில் பதிவிறக்கம் செய்யப்பட்டது.',
      AppLanguage.hindi: 'स्थानीय संग्रहण में डाउनलोड हो गया।',
      AppLanguage.bengali: 'লোকাল স্টোরেজে ডাউনলোড হয়েছে।',
    },
    'premiumFeatureTitle': {
      AppLanguage.english: 'Premium Feature',
      AppLanguage.tamil: 'பிரீமியம் அம்சம்',
      AppLanguage.hindi: 'प्रीमियम सुविधा',
      AppLanguage.bengali: 'প্রিমিয়াম ফিচার',
    },
    'premiumFeatureDesc': {
      AppLanguage.english: 'Downloading advanced books and audio volumes for offline reading requires a Sadhaka Premium Membership path.',
      AppLanguage.tamil: 'ஆஃப்லைனில் படிக்க புத்தகங்கள் மற்றும் ஆடியோக்களைப் பதிவிறக்க சாதகா பிரீமியம் உறுப்பினர் தேவை.',
      AppLanguage.hindi: 'ऑफलाइन पठन के लिए उन्नत पुस्तकें और ऑडियो डाउनलोड करने के लिए साधक प्रीमियम सदस्यता की आवश्यकता है।',
      AppLanguage.bengali: 'অফলাইনে পড়ার জন্য উন্নত বই ও অডিও ডাউনলোড করতে সাধক প্রিমিয়াম মেম্বারশিপ প্রয়োজন।',
    },
    'viewPathsBtn': {
      AppLanguage.english: 'VIEW PATHS',
      AppLanguage.tamil: 'வழிகளைப் பார்',
      AppLanguage.hindi: 'विकल्प देखें',
      AppLanguage.bengali: 'প্যাকসমূহ দেখুন',
    },
    'aiScriptureWorkResponse': {
      AppLanguage.english: 'According to the scripture context provided (Gita 2.47), the concept of selfless action is crucial. Krishna advises Arjuna: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन" which transliterates to "karmaṇy-evādhikāras te mā phaleṣu kadācana". This means your right is to perform your duty, but never to claim its fruits. Anxiety arises when we obsess over outcomes; focusing single-mindedly on the action itself dissolves that anxiety and turns work into worship.',
      AppLanguage.tamil: 'வழங்கப்பட்ட வேதத்தின்படி (கீதை 2.47), சுயநலமற்ற செயல் மிகவும் முக்கியமானது. கிருஷ்ணர் அர்ஜுனனிடம் கூறுகிறார்: கடமையைச் செய்ய மட்டுமே உனக்கு அதிகாரம் உண்டு, அதன் பலன்களில் எப்போதும் இல்லை. பலன்களைப் பற்றி கவலைப்படுவது அமைதியின்மையை ஏற்படுத்தும்; செயலில் மட்டுமே கவனம் செலுத்துவது கவலையை போக்கி, வேலையை வழிபாடாக மாற்றும்.',
      AppLanguage.hindi: 'प्रदान किए गए शास्त्र संदर्भ (गीता 2.47) के अनुसार, निष्काम कर्म की अवधारणा अत्यंत महत्वपूर्ण है। कृष्ण अर्जुन को सलाह देते हैं: "कर्मण्येवाधिकारस्ते मा फलेषु कदाचन"। इसका अर्थ है कि आपका अधिकार केवल अपना कर्तव्य करने में है, उसके फलों पर कभी नहीं। जब हम परिणामों को लेकर चिंतित होते हैं, तब तनाव उत्पन्न होता है; केवल कर्म पर ध्यान केंद्रित करने से वह चिंता मिट जाती है और कार्य ही पूजा बन जाता है।',
      AppLanguage.bengali: 'প্রদত্ত শাস্ত্রীয় প্রসঙ্গ (গীতা ২.৪৭) অনুযায়ী, নিষ্কাম কর্মের ধারণাটি অত্যন্ত গুরুত্বপূর্ণ। কৃষ্ণ অর্জুনকে উপদেশ দিচ্ছেন: "কর্মণ্যেবাধিকারস্তে মা ফলেষু কদাচন"। এর অর্থ হলো আপনার অধিকার কেবল কর্তব্য পালনে, ফলের ওপর নয়। ফলাফল নিয়ে অতিরিক্ত চিন্তা করলে উদ্বেগ তৈরি হয়; কেবল কর্মের প্রক্রিয়ায় সম্পূর্ণ মনোযোগ দিলে সেই উদ্বেগ দূর হয় এবং কর্মই উপাসনায় পরিণত হয়।',
    },
    'aiScriptureSoulResponse': {
      AppLanguage.english: 'The scriptures teach us in Chapter 2, Verse 20 that the soul (Atman) is birthless, deathless, and eternal ("न जायते म्रियते वा कदाचिन्"). Sri Krishna explains that the body is merely a vessel. Just as we discard worn-out clothing, the soul discards a physical body. Realizing this core eternal nature frees a seeker from grief and the fear of mortality.',
      AppLanguage.tamil: 'வேதங்கள் அத்தியாயம் 2, ஸ்லோகம் 20 இல் ஆத்மாவிற்கு பிறப்பும் இல்லை, இறப்பும் இல்லை, அது நித்தியமானது என்று கற்பிக்கிறது. உடல் என்பது வெறும் பாத்திரம் மட்டுமே என்று கிருஷ்ணர் விளக்குகிறார். பழைய ஆடைகளை நாம் மாற்றுவது போல, ஆத்மா உடலை மாற்றுகிறது. இதை உணர்வது பயத்தை நீக்குகிறது.',
      AppLanguage.hindi: 'शास्त्र हमें अध्याय 2, श्लोक 20 में सिखाते हैं कि आत्मा (आत्मन) जन्मरहित, मृत्युरहित और शाश्वत है ("न जायते म्रियते वा कदाचिन्")। श्री कृष्ण बताते हैं कि शरीर केवल एक पात्र है। जैसे हम पुराने वस्त्र त्याग देते हैं, वैसे ही आत्मा शरीर को त्याग देती है। इस शाश्वत प्रकृति को महसूस करने से साधक को मृत्यु के भय और शोक से मुक्ति मिलती है।',
      AppLanguage.bengali: 'শাস্ত্র আমাদের ২য় অধ্যায়ের ২০ নম্বর শ্লোকে শিক্ষা দেয় যে, আত্মা জন্মহীন, মৃত্যুহীন ও চিরন্তন ("ন জায়তে ম্রিয়তে বা কদাচিন্")। শ্রীকৃষ্ণ ব্যাখ্যা করেছেন যে শরীর কেবলই একটি বাহন। আমরা যেমন জীর্ণ বস্ত্র ত্যাগ করি, আত্মা তেমনই শরীর ত্যাগ করে। এই পরম সত্য উপলব্ধি করলে সাধক শোক এবং মৃত্যুর ভয় থেকে মুক্তি পান।',
    },
    'aiScriptureDefaultResponse': {
      AppLanguage.english: 'Based on Dharmic teachings, all actions should be aligned with your core truth (Dharma). When faced with doubt, practice silent introspection, perform your duties without selfish attachments, and seek refuge in the Divine consciousness. This balances karmic cycles and leads to spiritual liberation.',
      AppLanguage.tamil: 'தர்ம போதனைகளின்படி, அனைத்து செயல்களும் உங்கள் தர்மத்துடன் ஒத்துப்போக வேண்டும். சந்தேகம் ஏற்படும் போது, அமைதியான சுயபரிசோதனை செய்யுங்கள், பற்று இல்லாமல் கடமைகளைச் செய்யுங்கள், இறைவனிடம் சரணடையுங்கள். இது ஆன்மீக விடுதலைக்கு வழிவகுக்கும்.',
      AppLanguage.hindi: 'धर्म की शिक्षाओं के आधार पर, सभी कार्य आपके सत्य (धर्म) के अनुरूप होने चाहिए। जब संदेह हो, तब मौन आत्मनिरीक्षण करें, स्वार्थ रहित होकर अपने कर्तव्यों का पालन करें और दिव्य चेतना की शरण लें। यह कर्म चक्र को संतुलित करता है और आध्यात्मिक मुक्ति की ओर ले जाता. है।',
      AppLanguage.bengali: 'ধর্মীয় শিক্ষা অনুযায়ী, সমস্ত কর্ম আপনার পরম সত্যের (ধর্ম) সাথে সামঞ্জস্যপূর্ণ হওয়া উচিত। সংশয় দেখা দিলে নীরব আত্মদর্শন করুন, আসক্তিহীন হয়ে নিজের কর্তব্য পালন করুন এবং পরম চেতনার শরণাপন্ন হোন। এটি কর্মের চক্রকে শান্ত করে এবং আধ্যাত্মিক মুক্তির পথ প্রশস্ত করে।',
    },
    'aiGuruAnxietyResponse': {
      AppLanguage.english: 'Radhey Radhey, dear seeker. Peace is already within you, but it is currently clouded by the restless waves of the mind. Think of your mind as a lake. When the wind of desires blows, it creates ripples, and you cannot see the bottom. But when the wind stops, the water becomes still, reflecting the beautiful sky. Let go of what you cannot control. Take a slow, deep breath, and offer your worries to the Divine. You are safe. Shanti, Shanti, Shanti.',
      AppLanguage.tamil: 'ராதே ராதே, அன்பான தேடுபவரே. அமைதி ஏற்கனவே உங்களுக்குள் இருக்கிறது, ஆனால் அது தற்போது மனதின் அலைகளால் மறைக்கப்பட்டுள்ளது. உங்கள் மனதை ஒரு குளம் போல் நினைத்துக் கொள்ளுங்கள். ஆசைகளின் காற்று வீசும்போது அலைகள் உருவாகும். ஆனால் காற்று நிறுத்தும்போது நீர் அமைதியாகி, வானத்தை பிரதிபலிக்கும். கட்டுப்படுத்த முடியாதவற்றை விட்டுவிடுங்கள். ஆழமாக மூச்சு விடுங்கள், கவலைகளை இறைவனிடம் ஒப்படையுங்கள். நீங்கள் பாதுகாப்பாக இருக்கிறீர்கள். சாந்தி, சாந்தி, சாந்தி.',
      AppLanguage.hindi: 'राधे राधे, प्रिय साधक। शांति पहले से ही आपके भीतर है, लेकिन वह अभी मन की अशांत तरंगों से ढकी हुई है। अपने मन को एक झील की तरह समझें। जब इच्छाओं की हवा चलती है, तो उसमें लहरें उठती हैं, और आप सतह के नीचे नहीं देख पाते। परंतु जब हवा थम जाती है, तो पानी स्थिर हो जाता है और सुंदर आकाश को प्रतिबिंबित करता है। उसे छोड़ दें जिसे आप नियंत्रित नहीं कर सकते। एक गहरी सांस लें, और अपनी चिंताओं को परमात्मा को सौंप दें। आप सुरक्षित हैं। शांति, शांति, शांति।',
      AppLanguage.bengali: 'রাধে রাধে, প্রিয় অন্বেষক। শান্তি আপনার অন্তরেই রয়েছে, কিন্তু মন ও চিন্তা ও উত্তাল ঢেউয়ে তা এখন মেঘাচ্ছন্ন। মনকে একটি শান্ত সরোবরের মতো ভাবুন। যখন বাসনার বাতাস বয়, তখন তাতে ঢেউ ওঠে এবং তলদেশ দেখা যায় না। কিন্তু বাতাস যখন থেমে যায়, জল তখন স্থির হয়ে সুন্দর আকাশকে প্রতিফলিত করে। যা আপনার নিয়ন্ত্রণে নেই, তা ত্যাগ করুন। একটি দীর্ঘ গভীর শ্বাস নিন এবং আপনার সমস্ত উদ্বেগ পরমেশ্বরের চরণে অর্পণ করুন। আপনি সুরক্ষিত। শান্তি, শান্তি, শান্তি।',
    },
    'aiGuruDutyResponse': {
      AppLanguage.english: "Blessings to you. The question of action (Karma) and duty (Dharma) is ancient. Sri Krishna teaches us that it is better to perform one's own duty, even if imperfectly, than to attempt another's duty. Perform your work as an act of devotion, with a clean heart. Do not look to the left or right to see what rewards others are getting. Simply align your action with your conscience. That is the highest sadhana.",
      AppLanguage.tamil: 'உங்களுக்கு என் ஆசிகள். செயல் மற்றும் கடமை பற்றிய கேள்வி பழமையானது. மற்றவர்களின் கடமையைச் செய்வதை விட, நமது சொந்த கடமையை குறைபாடுகளுடன் செய்தாலும் அதுவே சிறந்தது என்று கிருஷ்ணர் கற்பிக்கிறார். தூய மனதுடன் உங்கள் பணியை இறைவனுக்கு அர்ப்பணித்து செய்யுங்கள். மற்றவர்களின் பலனைப் பார்த்து பொறாமை கொள்ளாதீர்கள். உங்கள் மனசாட்சியின்படி செயல்படுங்கள். அதுவே மிக உயர்ந்த சாதனா.',
      AppLanguage.hindi: 'आपको आशीर्वाद। कर्म और कर्तव्य का प्रश्न अत्यंत प्राचीन है। श्री कृष्ण हमें सिखाते हैं कि दूसरे के कर्तव्य को करने से बेहतर है कि हम अपने स्वयं के कर्तव्य का पालन करें, भले ही उसमें कमियां हों। अपने कार्य को शुद्ध हृदय से भक्ति भाव के साथ करें। दूसरों के पुरस्कारों को न देखें। बस अपने कर्म को अपनी अंतरात्मा के साथ संरेखित करें। यही सर्वोच्च साधना है।',
      AppLanguage.bengali: 'আপনার প্রতি আশীর্বাদ রইল। কর্ম এবং কর্তব্যের প্রশ্নটি ও প্রাচীন। শ্রীকৃষ্ণ আমাদের শিখিয়েছেন যে অন্যের कर्तव्य নিখুঁতভাবে করার চেয়ে নিজের কর্তব্য কিছুটা ত্রুটিপূর্ণ হলেও তা পালন করা শ্রেয়। নির্মল হৃদয়ে ভক্তি সহকারে নিজের কাজ করুন। কে কী ফল পাচ্ছে তা নিয়ে এদিক-ওদিক তাকাবেন না। কেবল নিজের বিবেক অনুযায়ী কাজ করুন। এটিই পরম সাধনা।',
    },
    'aiGuruSadnessResponse': {
      AppLanguage.english: 'Radhey Radhey, my child. It is natural for the heart to feel heavy at times. The world is full of transitions, and change often brings pain. But remember, you are never truly alone. The Divine presence resides in the quiet cave of your heart, breathing with you, feeling with you. Do not identify with this passing cloud of sadness. You are the infinite sky behind it. Sit in silence for a few moments, feel My presence, and let peace return.',
      AppLanguage.tamil: 'ராதே ராதே என் குழந்தையே. மனம் சில நேரங்களில் பாரமாக இருப்பது இயல்பானதே. உலகம் மாற்றங்கள் நிறைந்தது, மாற்றங்கள் வலியைத் தரும். ஆனால் நீங்கள் தனியாக இல்லை என்பதை நினைவில் கொள்ளுங்கள். இறைவனின் இருப்பு உங்கள் இதயத்தின் குகையில் உள்ளது. இந்த சோக மேகங்களை உங்களாக நினைக்காதீர்கள். நீங்கள் அதற்குப் பின்னால் இருக்கும் எல்லையற்ற வானம். சிறிது நேரம் அமைதியாக அமர்ந்து, என் இருப்பை உணருங்கள், அமைதி திரும்பும்.',
      AppLanguage.hindi: 'राधे राधे, मेरे बच्चे। कभी-कभी मन का भारी होना स्वाभाविक है। संसार परिवर्तनों से भरा है, और बदलाव अक्सर पीड़ा लाता है। लेकिन याद रखें, आप कभी अकेले नहीं हैं। दिव्य उपस्थिति आपके हृदय की शांत गुफा में निवास करती है, आपके साथ सांस लेती है, आपके साथ महसूस करती है। उदासी के इस गुजरते हुए बादल से अपनी पहचान न जोड़ें। आप इसके पीछे के अनंत आकाश हैं। कुछ पल मौन बैठें, मेरी उपस्थिति को महसूस करें, और शांति को वापस आने दें।',
      AppLanguage.bengali: 'রাধে রাধে, আমার সন্তান। মাঝে মাঝে মন ভারাক্রান্ত হওয়া স্বাভাবিক। জগৎ পরিবর্তনশীল এবং পরিবর্তন প্রায়শই বেদনা নিয়ে আসে। কিন্তু মনে রাখবেন, আপনি কখনোই একা নন। পরমেশ্বরের উপস্থিতি আপনার হৃদয়ের শান্ত গুহায় বিদ্যমান, তিনি আপনার সাথে শ্বাস নিচ্ছেন, আপনার ব্যথা অনুভব করছেন। দুঃখের এই ক্ষণস্থায়ী মেঘের সাথে নিজেকে জড়াবেন না। আপনি এর পেছনের অনন্ত আকাশ। কিছুক্ষণ নীরব হয়ে বসুন, পরম কৃপা অনুভব করুন এবং শান্তি ফিরে আসতে দিন।',
    },
    'aiGuruDefaultResponse': {
      AppLanguage.english: 'Radhey Radhey. I hear the sincere seeking in your heart. In this journey of life, seek to align your thoughts, words, and actions with truth. Practice daily silence, read the scriptures, and remember that everything is a manifestation of the Divine. Rest in this faith, and let your heart be at peace. Blessings upon your path.',
      AppLanguage.tamil: 'ராதே ராதே. உங்கள் இதயத்தின் உண்மையான தேடலைக் காண்கிறேன். இந்த வாழ்க்கைப் பயணத்தில், உங்கள் எண்ணங்கள், வார்த்தைகள் மற்றும் செயல்களை உண்மையுடன் சீரமைக்க முயலுங்கள். தினமும் தியானம் செய்யுங்கள், வேதங்களைப் படியுங்கள், அனைத்தும் இறைவனின் வடிவம் என்பதை நினைவில் கொள்ளுங்கள். இந்த நம்பிக்கையில் ஓய்வெடுங்கள், உங்கள் இதயம் அமைதியாக இருக்கட்டும். உங்கள் பாதையில் ஆசிகள்.',
      AppLanguage.hindi: 'राधे राधे। मैं आपके हृदय की सच्ची खोज को सुन रहा हूँ। जीवन की इस यात्रा में, अपने विचारों, शब्दों और कार्यों को सत्य के साथ संरेखित करने का प्रयास करें। दैनिक मौन का अभ्यास करें, शास्त्रों को पढ़ें और याद रखें कि सब कुछ परमात्मा का ही रूप है। इस विश्वास में विश्राम करें, और अपने हृदय को शांत होने दें। आपकी यात्रा मंगलमय हो।',
      AppLanguage.bengali: 'রাধে রাধে। আমি আপনার হৃদয়ের আন্তরিক অন্বেষণ অনুভব করছি। জীবনের এই যাত্রাপথে আপনার চিন্তা, কথা ও কাজকে সত্যের অভিমুখে চালিত করুন। প্রতিদিন নীরবতা অভ্যাস করুন, শাস্ত্র পাঠ করুন এবং মনে রাখুন যে যা কিছু ঘটছে তা সবই ঈশ্বরের প্রকাশ। এই বিশ্বাসে স্থির থাকুন এবং হৃদয় শান্ত হতে দিন। আপনার যাত্রাপথ শুভ হোক।',
    },
  };

  static String get(String key, AppLanguage lang) {
    if (_dict.containsKey(key)) {
      return _dict[key]?[lang] ?? _dict[key]?[AppLanguage.english] ?? key;
    }
    return key;
  }
}

class LocalizedScripture {
  static final Map<String, Map<AppLanguage, String>> translations = {
    'BG_2_47': {
      AppLanguage.english: 'But you have only the right to work, but none to the fruit of it. Let not the fruit of your action be your motive; nor be you enamored of inaction.',
      AppLanguage.tamil: 'உனக்கு கடமையைச் செய்ய மட்டுமே அதிகாரம் உண்டு, அதன் பலன்களில் எப்போதும் இல்லை. செயலின் பலனுக்கு உன்னை காரணியாக்கிக் கொள்ளாதே, அதே சமயம் செயலின்மையில் பற்று கொள்ளாதே.',
      AppLanguage.hindi: 'कर्म करने में ही तुम्हारा अधिकार है, उसके फलों में कभी नहीं। तुम कर्मों के फल की इच्छा वाले मत बनो और तुम्हारी अकर्मण्यता में भी आसक्ति न हो।',
      AppLanguage.bengali: 'কর্মে তোমার অধিকার আছে, কিন্তু ফলে কখনো অধিকার নেই। ফলের আশা করো না, আবার নিষ্ক্রিয়তায়ও আসক্ত হয়ো না।',
    },
    'BG_2_20': {
      AppLanguage.english: 'It was not born; it will never die, nor, once having been, can it cease to exist. Unborn, eternal, ever-enduring, yet most ancient, the spirit does not die when the body is dead.',
      AppLanguage.tamil: 'ஆத்மாவிற்கு எப்போதும் பிறப்பும் இல்லை, இறப்பும் இல்லை. அது உருவாகவில்லை, உருவாகப்போவதும் இல்லை. அது பிறப்பற்றது, நித்தியமானது, என்றும் நிலைத்திருப்பது, பழமையானது. உடல் கொல்லப்படும் போது அது கொல்லப்படுவதில்லை.',
      AppLanguage.hindi: 'आत्मा के लिए किसी भी समय न तो जन्म है और न ही मृत्यु। वह न तो कभी अस्तित्व में आया है, न आता है, और न ही कभी आएगा। वह अजन्मा, नित्य, शाश्वत और पुरातन है। शरीर के मारे जाने पर भी वह नहीं मारा जाता।',
      AppLanguage.bengali: 'আত্মার কখনও জন্ম বা মৃত্যু হয় না। তিনি পূর্বে ছিলেন না, এখন আছেন, ভবিষ্যতে থাকবেন না—এমন নয়। তিনি জন্মহীন, নিত্য, সনাতন এবং আদিম। শরীর ধ্বংস হলেও তিনি ধ্বংস হন না।',
    },
    'BG_9_22': {
      AppLanguage.english: 'But if a person meditates on Me and Me alone, worships Me always and everywhere, I will take upon Myself the fulfillment of their aspiration, and I will safeguard whatever they attain.',
      AppLanguage.tamil: 'எவன் பிற சிந்தனைகள் இன்றி என்னை மட்டுமே தியானித்து வழிபடுகிறானோ, அந்த நித்திய பக்தர்களின் தேவைகளை நான் சுமக்கிறேன் மற்றும் அவர்கள் பெற்றதை நான் பாதுகாக்கிறேன்.',
      AppLanguage.hindi: 'परन्तु जो अनन्य भक्त मेरा चिन्तन करते हुए मेरी उपासना करते हैं, उन नित्य-युक्त पुरुषों का योगक्षेम (आवश्यकताओं की पूर्ति और सुरक्षा) मैं स्वयं वहन करता हूँ।',
      AppLanguage.bengali: 'কিন্তু যারা অন্য কিছু চিন্তা না করে কেবল আমার ধ্যান করে আমার আরাধনা করে, সেই নিত্য-যুক্ত ভক্তদের প্রয়োজনীয় বস্তু আমি বহন করি এবং তাদের প্রাপ্ত জিনিস আমি রক্ষা করি।',
    },
    'BG_18_66': {
      AppLanguage.english: 'Give up your earthly duties, surrender yourself to Me alone. Do not be anxious; I will absolve you from all your sins.',
      AppLanguage.tamil: 'அனைத்து தர்மங்களையும் துறந்து என்னை மட்டுமே சரணடைவாய். நான் உன்னை அனைத்து பாவ விளைவுகளிலிருந்தும் விடுவிப்பேன். பயப்படாதே.',
      AppLanguage.hindi: 'सभी धर्मों (कर्तव्यों) को छोड़कर केवल मेरी शरण में आओ। मैं तुम्हें सभी पापों के बंधनों से मुक्त कर दूँगा। तुम शोक मत करो।',
      AppLanguage.bengali: 'সব ধর্ম পরিত্যাগ করে কেবল আমারই শরণাপন্ন হও। আমি তোমাকে সমস্ত পাপ থেকে মুক্তি দেব। ভয় পেয়ো না।',
    },
  };

  static final Map<String, Map<AppLanguage, String>> commentaries = {
    'BG_2_47': {
      AppLanguage.english: 'This famous verse outlines the philosophy of Karma Yoga—selfless service. Sri Krishna teaches Arjuna that holding onto expectations of reward brings anxiety, disappointment, and binding attachment. True freedom lies in performing actions as an offering to the Divine, without self-seeking motives. By centering our focus on the process rather than the outcome, we enter a state of peaceful flow and spiritual elevation.',
      AppLanguage.tamil: 'இந்த ஸ்லோகம் நிஷ்காம கர்மயோகத்தின் அடித்தளமாகும். பலனை எதிர்பார்ப்பது கவலை, ஏமாற்றம் மற்றும் பந்தத்தை ஏற்படுத்துகிறது என்று கிருஷ்ணர் அர்ஜுனனுக்குக் கற்பிக்கிறார். உண்மையான விடுதலை என்பது செயல்களை இறைவனுக்கு அர்ப்பணிப்பதே ஆகும்.',
      AppLanguage.hindi: 'यह श्लोक निष्काम कर्मयोग का आधार है। श्री कृष्ण अर्जुन को सिखाते हैं कि फल की चिंता करने से चिंता, निराशा और बंधन पैदा होते हैं। सच्ची मुक्ति ईश्वर को समर्पित भाव से कर्म करने में है। कर्म की प्रक्रिया पर ध्यान केंद्रित करने से मन शांत होता है और आध्यात्मिक प्रगति होती है।',
      AppLanguage.bengali: 'এই শ্লোকটি নিষ্কাম কর্মযোগের মূল ভিত্তি। শ্রীকৃষ্ণ অর্জুনকে শিখিয়েছেন যে ফলের আশা রাখলে মনের অস্থিরতা, হতাশা এবং বন্ধন তৈরি হয়। প্রকৃত মুক্তি নিহিত রয়েছে পরমেশ্বরের উদ্দেশে কর্ম উৎসর্গ করার মধ্যে। ফলাফলের চেয়ে কর্মের প্রক্রিয়ায় মনোযোগ দিলে আধ্যাত্মিক উত্তরণ ঘটে।',
    },
    'BG_2_20': {
      AppLanguage.english: 'Sri Krishna describes the eternal, indestructible nature of the soul (Atman) to alleviate Arjuna’s grief over bodily death. The body goes through birth, growth, change, decay, and death, but the consciousness inside remains unaffected. Realizing this core truth establishes us in deep equanimity, allowing us to face life’s changes without fear.',
      AppLanguage.tamil: 'உடல் அழிவு குறித்து அர்ஜுனனின் துயரத்தைப் போக்க கிருஷ்ணர் ஆத்மாவின் அழிவற்ற தன்மையை விவரிக்கிறார். உடல் மாற்றங்களுக்கு உள்ளாகிறது, ஆனால் உள்ளே இருக்கும் ஆத்மா பாதிக்கப்படுவதில்லை. இதை உணர்வது பயத்தை நீக்குகிறது.',
      AppLanguage.hindi: 'श्री कृष्ण आत्मा की अमरता और अविनाशी प्रकृति का वर्णन करते हैं ताकि अर्जुन का शारीरिक मृत्यु के प्रति शोक दूर हो सके। शरीर जन्म, वृद्धि, क्षय और मृत्यु से गुजरता है, लेकिन भीतर की चेतना अप्रभावित रहती है। इस सत्य को जानने से परम शांति प्राप्त होती है।',
      AppLanguage.bengali: 'শ্রীকৃষ্ণ আত্মার অমরতা এবং অবিনাশী রূপ বর্ণনা করে অর্জুনের শোক দূর করতে চেয়েছেন। দেহের জন্ম, বৃদ্ধি, রূপান্তর ও বিনাশ ঘটে, কিন্তু অন্তরের আত্মা চির অপরিবর্তিত থাকে। এই সত্য উপলব্ধি করলে মানুষ ভয়হীন ও অবিচল হতে পারে।',
    },
    'BG_9_22': {
      AppLanguage.english: 'This verse represents a divine promise of absolute protection and grace. For a seeker who is single-mindedly aligned with their higher consciousness (Krishna), the universe provides all material and spiritual necessities (yoga) and guards their existing progress (kshema). It releases the seeker from the burden of anxious struggle, cultivating deep trust.',
      AppLanguage.tamil: 'இந்த ஸ்லோகம் முழுமையான பாதுகாப்பு மற்றும் அருளின் தெய்வீக வாக்குறுதியாகும். தன்னை முழுமையாக இறைவனிடம் ஒப்படைக்கும் பக்தனின் தேவைகளை இறைவனே கவனித்துக் கொள்கிறார். இது பக்தனை கவலைகளிலிருந்து விடுவிக்கிறது.',
      AppLanguage.hindi: 'यह श्लोक पूर्ण सुरक्षा और अनुग्रह के दैवीय आश्वासन को दर्शाता है। जो साधक अनन्य भाव से ईश्वर में लीन रहता है, उसके योग (अप्राप्त की प्राप्ति) और क्षेम (प्राप्त की सुरक्षा) की जिम्मेदारी स्वयं परमात्मा उठाते हैं। यह साधक को चिंताओं से मुक्त कर समर्पण भाव जगाता है।',
      AppLanguage.bengali: 'এই শ্লোকটি পরমেশ্বরের পরম সুরক্ষা ও করুণার এক দিব্য প্রতিশ্রুতি। যে সাধক একাগ্র চিত্তে ঈশ্বরের আরাধনা করেন, তাঁর প্রয়োজনীয় বস্তু প্রাপ্তি এবং রক্ষণের ভার স্বয়ং ভগবান বহন করেন। এটি সাধককে উৎকণ্ঠামুক্ত করে গভীর বিশ্বাসের পথে নিয়ে যায়।',
    },
    'BG_18_66': {
      AppLanguage.english: 'Often considered the final essence of the Bhagavad Gita (the Charama Shloka). Krishna asks Arjuna to let go of external rites, duties, and intellectual calculations of right/wrong, and simply seek refuge in the Supreme Consciousness. Surrender is not defeat; it is the ultimate act of alignment, which instantly dissolves karmic baggage and replaces fear with divine assurance.',
      AppLanguage.tamil: 'அனைத்து கடமைகளையும் துறந்து தன்னிடம் சரணடையுமாறு கிருஷ்ணர் அர்ஜுனனிடம் கூறுகிறார். இது அனைத்து பாவ விளைவுகளிலிருந்தும் விடுதலை அளிக்கிறது.',
      AppLanguage.hindi: 'यह गीता का अंतिम और परम संदेश (चरम श्लोक) माना जाता है। कृष्ण अर्जुन से कहते हैं कि सभी बाहरी नियमों और कर्तव्यों की चिंताओं को छोड़कर केवल उनकी शरण में आ जाएं। पूर्ण समर्पण से सभी संचित पाप नष्ट हो जाते हैं और भय की जगह दिव्य अभय ले लेता है।',
      AppLanguage.bengali: 'এটি গীতার শেষ এবং পরম বার্তা (চরম শ্লোক) বলে গণ্য করা হয়। কৃষ্ণ অর্জুনকে সমস্ত বাহ্যিক নিয়ম ও কর্তব্যের চিন্তা পরিত্যাগ করে কেবল তাঁর শরণাপন্ন হতে বলেছেন। এই শরণাগতি মানুষের সমস্ত পাপ দূর করে গভীর অভয় প্রদান করে।',
    },
  };
}