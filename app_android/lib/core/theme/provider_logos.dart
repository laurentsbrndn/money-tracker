import 'package:flutter/material.dart';

/// Banks and e-wallets offered in the account form (APP_FLOWS Flow 1 step 6.2).
class BankProvider {
  const BankProvider(this.key, this.name);

  final String key;
  final String name;
}

abstract final class ProviderLogos {
  static const List<BankProvider> all = [
    BankProvider('bca', 'BCA'),
    BankProvider('mandiri', 'Mandiri'),
    BankProvider('bri', 'BRI'),
    BankProvider('bni', 'BNI'),
    BankProvider('jago', 'Jago'),
    BankProvider('seabank', 'SeaBank'),
    BankProvider('gopay', 'GoPay'),
    BankProvider('ovo', 'OVO'),
    BankProvider('dana', 'DANA'),
    BankProvider('shopeepay', 'ShopeePay'),
    BankProvider('other', 'Lainnya'),
  ];

  static String assetOf(String key) => 'assets/logos/$key.png';

  static String? nameOf(String? key) {
    for (final provider in all) {
      if (provider.key == key) {
        return provider.name;
      }
    }
    return null;
  }
}

/// A provider logo from `assets/logos/<key>.png`; while that file is absent it
/// shows the provider's initials so the screens work before logos are added.
class ProviderLogo extends StatelessWidget {
  const ProviderLogo({required this.providerKey, this.size = 40, super.key});

  final String? providerKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = ProviderLogos.nameOf(providerKey) ?? '?';
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.secondaryContainer,
      child: Text(
        name.characters.take(2).toString().toUpperCase(),
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final key = providerKey;
    if (key == null) {
      return fallback;
    }
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        ProviderLogos.assetOf(key),
        cacheWidth: 96,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
