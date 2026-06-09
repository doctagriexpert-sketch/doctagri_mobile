import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/radius.dart';

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

class LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;
  final bool compact;

  const LanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
    this.compact = false,
  });

  static const languages = [
    LanguageOption(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    LanguageOption(code: 'ee', name: 'Ewe', nativeName: 'Ewe', flag: '🇹🇬'),
    LanguageOption(
      code: 'kab',
      name: 'Kabyè',
      nativeName: 'Kabyè',
      flag: '🇹🇬',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactSelector();
    }
    return _buildFullSelector();
  }

  Widget _buildCompactSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: languages.map((lang) {
          final isSelected = currentLanguage == lang.code;
          return GestureDetector(
            onTap: () => onLanguageChanged(lang.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.pill,
              ),
              child: Text(
                lang.code.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.bark,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFullSelector() {
    return Column(
      children: languages.map((lang) {
        final isSelected = currentLanguage == lang.code;
        return GestureDetector(
          onTap: () => onLanguageChanged(lang.code),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(15)
                  : AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.nativeName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.bark,
                        ),
                      ),
                      Text(
                        lang.name,
                        style: TextStyle(fontSize: 13, color: AppColors.fog),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
