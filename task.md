# DharmaAI Flutter App Checklist

## Phase 1: Foundation, Styling & Onboarding
- [x] Initialize the Flutter project in the project folder
- [x] Add dependencies to `pubspec.yaml` (riverpod, supabase_flutter, google_fonts, flutter_svg, just_audio)
- [x] Setup design system theme in Dart (`theme.dart` with Sacred & Serene colors and typography)
- [x] Download/Configure Newsreader, Be Vietnam Pro, and Inter fonts
- [x] Implement Screen 13: Welcome to DharmaAI (onboarding start with animation)
- [x] Implement Screen 12: Personalize Your Path (selection of goals/experience)
- [x] Implement Screen 7: Home - Language Select
- [x] Setup main app shell with custom Bottom Navigation Bar

## Phase 2: Core Scripture Reader & Search
- [x] Establish Supabase connection and local caching (Isar/Hive)
- [x] Preload sample Bhagavad Gita scripture data
- [x] Implement Screen 25: Bhagavad Gita Reader (1.6x line-height, text size, Sanskrit toggle)
- [x] Implement Screen 32: Scripture Search (text and semantic query UI)
- [x] Implement Screen 6: Daily Spiritual Feed (Daily Quote card, sadhana progress widget)
- [x] Implement Screen 5: Audio Wisdom (Background audio streaming using just_audio)

## Phase 3: AI Guidance (Chat & Guru Mode)
- [x] Setup Supabase Edge Functions for LLM integration
- [x] Inject scripture context to Gemini LLM prompts (RAG pipeline)
- [x] Implement Screen 19: AI Scripture Chat (reference-backed conversation UI)
- [x] Implement Screen 21: AI Guru Mode (persona chat with conversational memory)

## Phase 4: Sadhana Dashboard & Community
- [x] Implement Screen 37: Daily Sadhana Dashboard (Habits tracker, custom Lotus progress indicator)
- [x] Implement Screen 17: Profile & Saved Wisdom (Bookmarks, personalized notes)
- [x] Implement Screen 35: Sangha Community (Reflection sharing feed, subscription gifting)

## Phase 5: Monetization & Offline Capability
- [x] Integrate RevenueCat SDK for subscriptions
- [x] Implement Screen 8: Choose Your Path (Subscription Tiers Paywall)
- [x] Implement Screen 15: Gift a Subscription UI
- [x] Implement Screen 14: Offline Wisdom Library (Book downloading settings)
- [x] Implement Screen 3: Offline Reader - Gita 2.47 (Local caching and reading in offline mode)

## Phase 6: Hardening & Deployment
- [x] Run automated widget and unit tests
- [x] Fix performance bottlenecks (virtualized scripture lists, audio buffering)
- [x] Build production APK / App Bundle and iOS IPA for deployment
