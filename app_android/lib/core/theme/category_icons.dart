import 'package:flutter/material.dart';

/// Icon keys shared with the server and iOS (BUSINESS_RULES §2.1) → icons.
abstract final class CategoryIcons {
  static const Map<String, IconData> byKey = {
    'food': Icons.restaurant,
    'transport': Icons.directions_bus,
    'home': Icons.home,
    'bill': Icons.receipt_long,
    'health': Icons.medical_services,
    'education': Icons.school,
    'fee': Icons.request_quote,
    'shopping': Icons.shopping_bag,
    'entertainment': Icons.movie,
    'subscription': Icons.subscriptions,
    'snack': Icons.fastfood,
    'gift': Icons.card_giftcard,
    'investment': Icons.trending_up,
    'other': Icons.more_horiz,
    'salary': Icons.work,
    'freelance': Icons.laptop_mac,
    'bonus': Icons.emoji_events,
  };

  /// Keys offered when the user creates or edits a category.
  static List<String> get pickable => byKey.keys.toList();

  static IconData of(String key) => byKey[key] ?? Icons.category;

  /// `#RRGGBB` → [Color]; grey for anything malformed.
  static Color colorOf(String hex) {
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
    if (match == null) {
      return const Color(0xFF9CA3AF);
    }
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  /// Palette offered for custom categories (same hex values the server seeds).
  static const List<String> palette = [
    '#F59E0B',
    '#3B82F6',
    '#8B5CF6',
    '#EF4444',
    '#10B981',
    '#06B6D4',
    '#EC4899',
    '#F97316',
    '#6366F1',
    '#14B8A6',
    '#22C55E',
    '#9CA3AF',
  ];
}
