# DharmaAI Mobile App & Backend Development Plan (Flutter Edition)

This document outlines the end-to-end implementation plan for building the **DharmaAI** mobile application and backend services, based on the **"Sacred & Serene"** design language and the **16 essential screens** manifest.

---

## Design System Analysis ("Sacred & Serene")

The application's identity balances spiritual depth with modern SaaS utility. Key design tokens from [DESIGN.md](file:///c:/Users/user/kdaa-projects/dharma_ai/stitch_divine_wisdom_ai/DESIGN.md) will be strictly mapped into the Flutter codebase:

- **Colors**:
  - `Parchment Cream` (`#FDF5E6` or surface `#fff8f6`) serves as the base reading canvas to eliminate eye strain.
  - `Deep Saffron` (`#9C3F00` / `#CC5500`) serves as the primary action/accent color (purity, fire, dawn).
  - `Meditative Indigo` (`#2E3A59` / `#0D1A38`) acts as the grounding dark-theme-like contrast container (e.g., chat bubbles, focus cards).
  - `Temple Gold` (`#D4AF37`) is reserved for highlights, bookmarks, and premium badges.
- **Typography**:
  - **Literary Serif**: *Newsreader* (via `google_fonts` package) for scriptures, daily feeds, and quotes, styled with `1.6x` line-height for a relaxed, book-like reading rhythm.
  - **Functional Sans**: *Be Vietnam Pro* for AI conversations, dashboard stats, and search UI.
  - **Utility Sans**: *Inter* for navigation tabs, buttons, settings labels, and small metadata.
- **Visual Rhythm**:
  - 24px side margins on mobile (instead of the standard 16px) to center user focus and provide "ethical airiness".
  - Fading dividers (using custom `LinearGradient` paint/decorations that fade on left/right edges) and soft floating shadows (`BoxShadow` with blur 20, spread 0, and indigo color at 5% opacity).
  - Subtle mandalas (SVG assets rendered at 2-3% opacity using `flutter_svg`) in the background of scriptures and AI Guru responses.

---

## Target Architecture

We propose the following modern, production-grade technology stack:

1. **Frontend (Mobile App)**:
   - **Framework**: **Flutter (Dart)**. Flutter is chosen for its exceptional performance, consistent cross-platform rendering, and native-grade animations.
   - **State Management**: **Flutter Riverpod** or **Bloc/Cubit** for robust, testable state management.
   - **Styling & Assets**: Material 3 configuration using `ThemeData` to define our custom color scheme, typography, and shape decoration styles.
   - **Local Storage / Database**: **Isar** or **Hive** for fast, local object storage, facilitating seamless offline access and state synchronization.
   - **Audio Wisdom**: `just_audio` and `audio_service` for high-quality background audio streaming.

2. **Backend**:
   - **Framework**: **Supabase** via the official `supabase_flutter` package. Supabase is chosen for:
     - Auth: Built-in Email/Password, Social Login, and JWT session handling.
     - Database: PostgreSQL with `pgvector` for scripture embeddings.
     - Storage: Buckets for Audio Wisdom MP3 files and SVG assets.
     - Edge Functions: Serverless functions for processing AI responses and payment webhooks.

3. **AI Pipeline (Spiritual Guidance)**:
   - **Model**: **Gemini 2.5 Flash / Pro** (via Google AI SDK or Supabase Edge Functions).
   - **RAG (Retrieval-Augmented Generation)**: Scripture text split and vectorized using Gemini's text-embedding models and stored in Supabase's `pgvector`.
   - **Guru Persona**: System instructions crafted with specific tone guidelines (compassionate, philosophical, non-judgmental, referencing scriptural verses).

4. **Monetization**:
   - **Purchases & Gifting**: **RevenueCat SDK** (`purchases_flutter`) for cross-platform subscriptions and gifting integration.

---

## User Review Required

> [!IMPORTANT]
> Please review the following key decisions before we initiate development:
>
> 1. **Core Scripture Sources**: For Phase 2, which translations of the Bhagavad Gita or other scriptures should we preload? (We suggest starting with public domain English translations that include Sanskrit transliteration, e.g., Edwin Arnold or Swami Swarupananda, plus modern interpretations if rights are cleared).
> 2. **AI Provider Credentials**: We plan to use the Gemini API. Do you have an active Google AI Studio API Key, or should we set up a mock AI interface first?
> 3. **Hosting & Auth**: Is a Supabase-backed setup acceptable, or do you prefer a custom Express server + MongoDB hosted on Heroku/AWS? (Supabase is strongly recommended for rapid, robust vector search).

---

## Open Questions

> [!WARNING]
> - **Sangha Community Model**: Should community posts be public and moderated, or restricted only to connections/friends?
> - **Audio Wisdom**: Do we have pre-recorded audio tracks, or should we implement a text-to-speech engine using a serene AI voice to synthesize scripture readings?

---

## Proposed Changes (Implementation Phases)

We will build the system iteratively across **6 distinct phases**.

### Phase 1: Foundation, Styling & Onboarding
- Initialize the Flutter project (`dharmaai_mobile`).
- Configure dependency management (`pubspec.yaml` with `riverpod`, `supabase_flutter`, `google_fonts`, `flutter_svg`, `just_audio`).
- Set up the theme system using `ThemeData` specifying the "Sacred & Serene" colors, typography, shapes, and layouts.
- **Screen 13: Welcome to DharmaAI** – Splendid logo animation, theme reveal.
- **Screen 12: Personalize Your Path** – Selection of user's current goals (peace, duty/karma, meditation) and familiarity level with scripture.
- **Screen 7: Home - Language Select** – Multi-language configuration UI.
- Establish core navigation routes (Bottom Navigation Bar + GoRouter/Navigator 2.0).

### Phase 2: Core Scripture Reader & Search
- Create database schemas in Supabase for scriptures (Books, Chapters, Verses, Translations).
- **Screen 25: Bhagavad Gita Reader** – E-reader UI. Implements 1.6x line-height, text adjustment controls, verse comparisons, Sanskrit script toggle, and bookmarks.
- **Screen 32: Scripture Search** – Semantic search capabilities leveraging Vector embeddings + keyword search.
- **Screen 6: Daily Spiritual Feed** – Daily verse card, personalized quote matching, and habit check-in triggers.
- **Screen 5: Audio Wisdom** – Audio streaming player integration with a background play task, progress bar, play/pause controls.

### Phase 3: AI Guidance (Chat & Guru Mode)
- **Screen 19: AI Scripture Chat** – Conversational interface where users ask questions about specific verses. Contextual RAG returns precise verse citations.
- **Screen 21: AI Guru Mode** – Persona-driven chat simulating a traditional spiritual guide. Incorporates conversational memory and emotional counseling based on dharmic concepts.
- Implement backend Edge Functions to handle prompts, context stitching, and streaming LLM responses.

### Phase 4: Sadhana Dashboard & Community
- **Screen 37: Daily Sadhana Dashboard** – Track daily practices (meditation minutes, verses read, chanting counter). Includes visual streak charts and serene progress indicators (custom circular Lotus design via custom painter).
- **Screen 17: Profile & Saved Wisdom** – Collection of bookmarks, personalized notes, and user stats.
- **Screen 35: Sangha Community** – Social space to share inspiring reflections, view collective sadhana metrics, and buy/send gift subscriptions directly within the feed.

### Phase 5: Monetization & Offline Capability
- **Screen 8: Choose Your Path (Subscription)** – Tiered access paywall detailing Free vs. Sadhaka (Premium) benefits.
- **Screen 15: Gift a Subscription** – Integration to purchase a pass for a friend, generating a redeemable code.
- **Screen 14: Offline Wisdom Library** – Settings to download specific books (e.g., "Full Gita", "Upanishads Volume 1") for offline use.
- **Screen 3: Offline Reader - Gita 2.47** – Graceful offline state view rendering stored verses with zero network connectivity.

### Phase 6: Hardening, QA & Deployment
- Performance tuning: virtualized lists for reading scripture, local asset caching, audio buffering optimization.
- App store deployment prep: configure iOS (App Store Connect / TestFlight) and Android (Google Play Console) bundles.
- Production deployment of Supabase schema, migrations, and AI cloud functions.

---

## Verification Plan

### Automated Verification
- **Unit Tests**: Widget and integration tests for testing RAG context rendering, user profile streak calculations, and theme rendering.
- **Linter & Types**: `flutter analyze` validation on build commands.

### Manual Verification
- **Visual Regression**: Verification of responsive font scaling, proper margins (24px edge spacing), and gradient fades on various viewport sizes (iOS Simulator and Android Emulator).
- **Offline Flow**: Testing database retrieval when airplane mode is toggled while reading Gita 2.47.
- **Audio Flow**: Validating background audio continuity when the app is minimized.
