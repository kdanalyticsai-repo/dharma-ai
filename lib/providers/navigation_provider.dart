import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected tab index for the HomeShell bottom navigation.
/// Lets other screens (e.g. the Feed) jump to a tab — Feed = 0,
/// Wisdom = 1, AI Guru = 2, Sadhana = 3, Sangha = 4.
final homeTabProvider = StateProvider<int>((ref) => 0);
