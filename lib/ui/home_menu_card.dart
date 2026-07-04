import 'package:flutter/material.dart';

import 'brand.dart';

class HomeMenuCard extends StatelessWidget {
  const HomeMenuCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Brand.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 32, color: color),
                  const Spacer(),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Brand.textPrimary)),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
