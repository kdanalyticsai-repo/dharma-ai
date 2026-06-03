import 'package:dharma_ai/config/r2_config.dart';

// ─────────────────────────────────────────────────────────────
//  Bhagavad Gita Audio Track Catalogue — All 18 Chapters
//
//  MP3 files to upload to Cloudflare R2 bucket:
//    bg_ch01.mp3  …  bg_ch18.mp3  (already downloaded to gita_audio/)
//
//  Audio courtesy: Sri Radhe-Krishn Mandir, Derveshpur (Uttar Pradesh),
//  used with the temple's kind permission. Public Domain Mark 1.0.
//  Website: https://sriradhekrishnmandir.blogspot.com/
//  Facebook: https://www.facebook.com/Sriradhekrishnmandirderveshpur
// ─────────────────────────────────────────────────────────────

class BgAudioTrack {
  final int chapter;
  final String titleEn;
  final String titleHi;
  final String titleTa;
  final String titleBn;
  final String yogaEn;   // yoga name subtitle
  final String yogaHi;
  final String yogaTa;
  final String yogaBn;
  final String narrator;
  final String duration;
  final int verseCount;
  final String _fileName; // filename in R2 bucket

  const BgAudioTrack({
    required this.chapter,
    required this.titleEn,
    required this.titleHi,
    required this.titleTa,
    required this.titleBn,
    required this.yogaEn,
    required this.yogaHi,
    required this.yogaTa,
    required this.yogaBn,
    required this.narrator,
    required this.duration,
    required this.verseCount,
    required String fileName,
  }) : _fileName = fileName;

  /// R2 CDN URL (primary). Falls back to archive.org if R2 not yet configured.
  String get audioUrl {
    if (R2Config.isConfigured) return R2Config.audioUrl(_fileName);
    return _archiveFallbackUrl;
  }

  // Public-domain source — courtesy Sri Radhe-Krishn Mandir, Derveshpur (UP),
  // used with the temple's permission. archive.org item: 03-chapter-2_202505
  // Filenames: 02Chapter1.mp3 … 19Chapter18.mp3 (track# = chapter+1)
  String get _archiveFallbackUrl {
    final trackNum = (chapter + 1).toString().padLeft(2, '0');
    return 'https://archive.org/download/03-chapter-2_202505/${trackNum}Chapter$chapter.mp3';
  }

  String get chapterLabel => 'Gita Chapter $chapter • $verseCount verses';
}

// ─────────────────────────────────────────────────────────────
//  Full 18-chapter catalogue
// ─────────────────────────────────────────────────────────────
const List<BgAudioTrack> bgAudioTracks = [
  BgAudioTrack(
    chapter: 1,
    titleEn: 'The Grief of Arjuna',
    titleHi: 'अर्जुन का विषाद',
    titleTa: 'அர்ஜுனனின் துக்கம்',
    titleBn: 'অর্জুনের বিষাদ',
    yogaEn: 'Arjuna Vishada Yoga',
    yogaHi: 'अर्जुन विषाद योग',
    yogaTa: 'அர்ஜுன விஷாத யோகம்',
    yogaBn: 'অর্জুন বিষাদ যোগ',
    narrator: 'Swami Bodhi',
    duration: '18:24',
    verseCount: 47,
    fileName: 'bg_ch01.mp3',
  ),
  BgAudioTrack(
    chapter: 2,
    titleEn: 'The Eternal Reality',
    titleHi: 'सांख्य योग',
    titleTa: 'நித்திய உண்மை',
    titleBn: 'সাংখ্য যোগ',
    yogaEn: 'Sankhya Yoga',
    yogaHi: 'सांख्य योग',
    yogaTa: 'சாங்கிய யோகம்',
    yogaBn: 'সাংখ্য যোগ',
    narrator: 'Swami Bodhi',
    duration: '25:12',
    verseCount: 72,
    fileName: 'bg_ch02.mp3',
  ),
  BgAudioTrack(
    chapter: 3,
    titleEn: 'The Path of Action',
    titleHi: 'कर्म योग',
    titleTa: 'கர்ம யோகம்',
    titleBn: 'কর্ম যোগ',
    yogaEn: 'Karma Yoga',
    yogaHi: 'कर्म योग',
    yogaTa: 'கர்ம யோகம்',
    yogaBn: 'কর্ম যোগ',
    narrator: 'Ma Devi',
    duration: '15:36',
    verseCount: 43,
    fileName: 'bg_ch03.mp3',
  ),
  BgAudioTrack(
    chapter: 4,
    titleEn: 'Wisdom Through Renunciation',
    titleHi: 'ज्ञान कर्म सन्यास योग',
    titleTa: 'ஞான கர்ம சந்நியாச யோகம்',
    titleBn: 'জ্ঞান কর্ম সন্ন্যাস যোগ',
    yogaEn: 'Jnana Karma Sanyasa Yoga',
    yogaHi: 'ज्ञान कर्म सन्यास योग',
    yogaTa: 'ஞான கர்ம சந்நியாச யோகம்',
    yogaBn: 'জ্ঞান কর্ম সন্ন্যাস যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '15:18',
    verseCount: 42,
    fileName: 'bg_ch04.mp3',
  ),
  BgAudioTrack(
    chapter: 5,
    titleEn: 'Action & Renunciation',
    titleHi: 'कर्म सन्यास योग',
    titleTa: 'கர்ம சந்நியாச யோகம்',
    titleBn: 'কর্ম সন্ন্যাস যোগ',
    yogaEn: 'Karma Sanyasa Yoga',
    yogaHi: 'कर्म सन्यास योग',
    yogaTa: 'கர்ம சந்நியாச யோகம்',
    yogaBn: 'কর্ম সন্ন্যাস যোগ',
    narrator: 'Ma Devi',
    duration: '10:48',
    verseCount: 29,
    fileName: 'bg_ch05.mp3',
  ),
  BgAudioTrack(
    chapter: 6,
    titleEn: 'Meditation & Inner Peace',
    titleHi: 'ध्यान योग',
    titleTa: 'தியான யோகம்',
    titleBn: 'ধ্যান যোগ',
    yogaEn: 'Dhyana Yoga',
    yogaHi: 'ध्यान योग',
    yogaTa: 'தியான யோகம்',
    yogaBn: 'ধ্যান যোগ',
    narrator: 'Swami Bodhi',
    duration: '18:00',
    verseCount: 47,
    fileName: 'bg_ch06.mp3',
  ),
  BgAudioTrack(
    chapter: 7,
    titleEn: 'Knowledge & Wisdom',
    titleHi: 'ज्ञान विज्ञान योग',
    titleTa: 'ஞான விஞ்ஞான யோகம்',
    titleBn: 'জ্ঞান বিজ্ঞান যোগ',
    yogaEn: 'Jnana Vijnana Yoga',
    yogaHi: 'ज्ञान विज्ञान योग',
    yogaTa: 'ஞான விஞ்ஞான யோகம்',
    yogaBn: 'জ্ঞান বিজ্ঞান যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '11:24',
    verseCount: 30,
    fileName: 'bg_ch07.mp3',
  ),
  BgAudioTrack(
    chapter: 8,
    titleEn: 'The Eternal Brahman',
    titleHi: 'अक्षर ब्रह्म योग',
    titleTa: 'அக்ஷர பிரம்ம யோகம்',
    titleBn: 'অক্ষর ব্রহ্ম যোগ',
    yogaEn: 'Aksara Brahma Yoga',
    yogaHi: 'अक्षर ब्रह्म योग',
    yogaTa: 'அக்ஷர பிரம்ம யோகம்',
    yogaBn: 'অক্ষর ব্রহ্ম যোগ',
    narrator: 'Swami Bodhi',
    duration: '10:36',
    verseCount: 28,
    fileName: 'bg_ch08.mp3',
  ),
  BgAudioTrack(
    chapter: 9,
    titleEn: 'Royal Science & Secret',
    titleHi: 'राज विद्या गुह्य योग',
    titleTa: 'ராஜ வித்யா குஹ்ய யோகம்',
    titleBn: 'রাজ বিদ্যা গুহ্য যোগ',
    yogaEn: 'Raja Vidya Guhya Yoga',
    yogaHi: 'राज विद्या गुह्य योग',
    yogaTa: 'ராஜ வித்யா குஹ்ய யோகம்',
    yogaBn: 'রাজ বিদ্যা গুহ্য যোগ',
    narrator: 'Ma Devi',
    duration: '12:48',
    verseCount: 34,
    fileName: 'bg_ch09.mp3',
  ),
  BgAudioTrack(
    chapter: 10,
    titleEn: 'Divine Glories of the Lord',
    titleHi: 'विभूति योग',
    titleTa: 'விபூதி யோகம்',
    titleBn: 'বিভূতি যোগ',
    yogaEn: 'Vibhuti Yoga',
    yogaHi: 'विभूति योग',
    yogaTa: 'விபூதி யோகம்',
    yogaBn: 'বিভূতি যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '15:48',
    verseCount: 42,
    fileName: 'bg_ch10.mp3',
  ),
  BgAudioTrack(
    chapter: 11,
    titleEn: 'Vision of the Universal Form',
    titleHi: 'विश्वरूप दर्शन योग',
    titleTa: 'விஸ்வரூப தர்சன யோகம்',
    titleBn: 'বিশ্বরূপ দর্শন যোগ',
    yogaEn: 'Vishwarupa Darshana Yoga',
    yogaHi: 'विश्वरूप दर्शन योग',
    yogaTa: 'விஸ்வரூப தர்சன யோகம்',
    yogaBn: 'বিশ্বরূপ দর্শন যোগ',
    narrator: 'Swami Bodhi',
    duration: '20:24',
    verseCount: 55,
    fileName: 'bg_ch11.mp3',
  ),
  BgAudioTrack(
    chapter: 12,
    titleEn: 'The Path of Devotion',
    titleHi: 'भक्ति योग',
    titleTa: 'பக்தி யோகம்',
    titleBn: 'ভক্তি যোগ',
    yogaEn: 'Bhakti Yoga',
    yogaHi: 'भक्ति योग',
    yogaTa: 'பக்தி யோகம்',
    yogaBn: 'ভক্তি যোগ',
    narrator: 'Ma Devi',
    duration: '7:36',
    verseCount: 20,
    fileName: 'bg_ch12.mp3',
  ),
  BgAudioTrack(
    chapter: 13,
    titleEn: 'The Field & The Knower',
    titleHi: 'क्षेत्र क्षेत्रज्ञ विभाग योग',
    titleTa: 'க்ஷேத்ர க்ஷேத்ரஞ்ஞ விபாக யோகம்',
    titleBn: 'ক্ষেত্র ক্ষেত্রজ্ঞ বিভাগ যোগ',
    yogaEn: 'Kshetra Kshetrajna Vibhaga Yoga',
    yogaHi: 'क्षेत्र क्षेत्रज्ञ विभाग योग',
    yogaTa: 'க்ஷேத்ர யோகம்',
    yogaBn: 'ক্ষেত্র যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '13:12',
    verseCount: 35,
    fileName: 'bg_ch13.mp3',
  ),
  BgAudioTrack(
    chapter: 14,
    titleEn: 'The Three Modes of Nature',
    titleHi: 'गुणत्रय विभाग योग',
    titleTa: 'குணத்ரய விபாக யோகம்',
    titleBn: 'গুণত্রয় বিভাগ যোগ',
    yogaEn: 'Gunatraya Vibhaga Yoga',
    yogaHi: 'गुणत्रय विभाग योग',
    yogaTa: 'குணத்ரய யோகம்',
    yogaBn: 'গুণত্রয় যোগ',
    narrator: 'Swami Bodhi',
    duration: '10:12',
    verseCount: 27,
    fileName: 'bg_ch14.mp3',
  ),
  BgAudioTrack(
    chapter: 15,
    titleEn: 'The Supreme Person',
    titleHi: 'पुरुषोत्तम योग',
    titleTa: 'புருஷோத்தம யோகம்',
    titleBn: 'পুরুষোত্তম যোগ',
    yogaEn: 'Purushottama Yoga',
    yogaHi: 'पुरुषोत्तम योग',
    yogaTa: 'புருஷோத்தம யோகம்',
    yogaBn: 'পুরুষোত্তম যোগ',
    narrator: 'Ma Devi',
    duration: '7:36',
    verseCount: 20,
    fileName: 'bg_ch15.mp3',
  ),
  BgAudioTrack(
    chapter: 16,
    titleEn: 'Divine & Demonic Natures',
    titleHi: 'दैवासुर सम्पद विभाग योग',
    titleTa: 'தைவாசுர சம்பத் விபாக யோகம்',
    titleBn: 'দৈবাসুর সম্পদ বিভাগ যোগ',
    yogaEn: 'Daivasura Vibhaga Yoga',
    yogaHi: 'दैवासुर विभाग योग',
    yogaTa: 'தைவாசுர யோகம்',
    yogaBn: 'দৈবাসুর যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '9:00',
    verseCount: 24,
    fileName: 'bg_ch16.mp3',
  ),
  BgAudioTrack(
    chapter: 17,
    titleEn: 'Three Divisions of Faith',
    titleHi: 'श्रद्धात्रय विभाग योग',
    titleTa: 'ஶ்ரத்தாத்ரய விபாக யோகம்',
    titleBn: 'শ্রদ্ধাত্রয় বিভাগ যোগ',
    yogaEn: 'Shraddhatraya Vibhaga Yoga',
    yogaHi: 'श्रद्धात्रय विभाग योग',
    yogaTa: 'ஶ்ரத்தா யோகம்',
    yogaBn: 'শ্রদ্ধা যোগ',
    narrator: 'Swami Bodhi',
    duration: '10:36',
    verseCount: 28,
    fileName: 'bg_ch17.mp3',
  ),
  BgAudioTrack(
    chapter: 18,
    titleEn: 'Absolute Surrender & Liberation',
    titleHi: 'मोक्ष सन्यास योग',
    titleTa: 'மோட்ச சந்நியாச யோகம்',
    titleBn: 'মোক্ষ সন্ন্যাস যোগ',
    yogaEn: 'Moksha Sanyasa Yoga',
    yogaHi: 'मोक्ष सन्यास योग',
    yogaTa: 'மோட்ச யோகம்',
    yogaBn: 'মোক্ষ যোগ',
    narrator: 'T.S. Ranganathan',
    duration: '28:12',
    verseCount: 78,
    fileName: 'bg_ch18.mp3',
  ),
];

// ─────────────────────────────────────────────────────────────
//  Helper: get localized title/yoga name for current language
// ─────────────────────────────────────────────────────────────
extension BgAudioTrackL10n on BgAudioTrack {
  String localizedTitle(String langCode) {
    switch (langCode) {
      case 'hi': return titleHi;
      case 'ta': return titleTa;
      case 'bn': return titleBn;
      default:   return titleEn;
    }
  }

  String localizedYoga(String langCode) {
    switch (langCode) {
      case 'hi': return yogaHi;
      case 'ta': return yogaTa;
      case 'bn': return yogaBn;
      default:   return yogaEn;
    }
  }
}
