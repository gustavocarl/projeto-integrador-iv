import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../shared/widgets/brand.dart';

/// The product photo ([imageUrl]: an external link or an image uploaded to the API) or, without one (or while/if it fails to load), an icon
/// that suggests what the product is, from words in its name or category (store of
/// electronics), tinted by category so products of the same category match.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({
    super.key,
    required this.name,
    this.category,
    this.imageUrl,
    this.size = 44,
  });

  final String name;
  final String? category;
  final String? imageUrl;
  final double size;

  /// Keywords (lowercase, no accents) → icon. The first match wins; the name is tried before the category.
  static const _icons = <(List<String>, IconData)>[
    (['notebook', 'laptop', 'ideapad', 'macbook'], Icons.laptop_mac_rounded),
    (
      ['celular', 'smartphone', 'iphone', 'galaxy a', 'telefon'],
      Icons.smartphone_rounded,
    ),
    (['tablet', 'ipad', 'tab '], Icons.tablet_mac_rounded),
    (['fone', 'headset', 'audio', 'headphone'], Icons.headphones_rounded),
    (['caixa de som', 'som', 'speaker'], Icons.speaker_rounded),
    (['tv', 'televis'], Icons.tv_rounded),
    (['monitor'], Icons.desktop_windows_rounded),
    (
      ['console', 'playstation', 'xbox', 'controle', 'game'],
      Icons.sports_esports_rounded,
    ),
    (['smartwatch', 'relogio', 'watch'], Icons.watch_rounded),
    (['teclado', 'keyboard'], Icons.keyboard_rounded),
    (['mouse'], Icons.mouse_rounded),
    (
      [
        'ssd',
        'hd ',
        'pen drive',
        'pendrive',
        'armazenamento',
        'memoria',
        'cartao',
      ],
      Icons.sd_storage_rounded,
    ),
    (['webcam', 'camera'], Icons.videocam_rounded),
    (['roteador', 'rede', 'wi-fi', 'wifi'], Icons.router_rounded),
    (['carregador', 'cabo', 'usb', 'acessorio', 'fonte'], Icons.cable_rounded),
    (['periferico', 'informatica', 'pc'], Icons.computer_rounded),
  ];

  static String _plain(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      final i = from.indexOf(char);
      buffer.write(i < 0 ? char : to[i]);
    }
    return '${buffer.toString()} ';
  }

  static IconData iconFor(String name, String? category) {
    for (final text in [name, ?category]) {
      final plain = _plain(text);
      for (final (words, icon) in _icons) {
        if (words.any(plain.contains)) return icon;
      }
    }
    return Icons.devices_other_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final icon = TintedIcon(
      iconFor(name, category),
      color: BrandColors.tintFor(context, category ?? ''),
      size: size,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return icon;

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          Env.resolveUrl(url),
          fit: BoxFit.contain,
          semanticLabel: name,
          // On the web, images from sites without CORS still show (as an <img> element).
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          // The icon until the first frame arrives; then the photo on a light tile
          // (product photos usually have a white background).
          frameBuilder: (context, child, frame, _) => frame == null
              ? icon
              : ColoredBox(color: Colors.white, child: child),
          errorBuilder: (context, error, stackTrace) => icon,
        ),
      ),
    );
  }
}
