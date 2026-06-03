import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _SettingsHero(),
              const SizedBox(height: 18),
              _SettingsSection(
                title: s.theme,
                children: [
                  _ActionRow(
                    icon: Icons.palette_outlined,
                    title: s.theme,
                    subtitle: _getThemeName(settingsProvider.themeMode, s),
                    onTap: () => _showThemeDialog(context, settingsProvider, s),
                  ),
                  _ActionRow(
                    icon: Icons.language,
                    title: s.language,
                    subtitle: SettingsProvider.languageNames[
                            settingsProvider.locale?.languageCode] ??
                        'Shona',
                    onTap: () => _showLanguageDialog(context, settingsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: 'Reading',
                children: [
                  _SliderRow(
                    title: s.fontSize,
                    icon: Icons.format_size,
                    value: settingsProvider.fontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    valueLabel:
                        '${settingsProvider.fontSize.clamp(12.0, 24.0).toStringAsFixed(1)}px',
                    onChanged: settingsProvider.setFontSize,
                  ),
                  _SliderRow(
                    title: s.brightness,
                    icon: Icons.brightness_6_outlined,
                    value: settingsProvider.brightness,
                    min: 0.3,
                    max: 1,
                    divisions: 7,
                    valueLabel:
                        '${(settingsProvider.brightness.clamp(0.3, 1.0) * 100).round()}%',
                    onChanged: settingsProvider.setBrightness,
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    secondary: const Icon(Icons.light_mode_outlined),
                    title: const Text('Keep screen awake'),
                    subtitle: const Text(
                        'Prevent the display from sleeping while reading'),
                    value: settingsProvider.keepScreenOn,
                    onChanged: settingsProvider.setKeepScreenOn,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsSection(
                title: s.about,
                children: [
                  _ActionRow(
                    icon: Icons.language,
                    title: 'Website',
                    subtitle: 'hruhrustudio.site',
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () =>
                        _launchUrl(context, 'https://hruhrustudio.site'),
                  ),
                  _ActionRow(
                    icon: Icons.code,
                    title: 'GitHub',
                    subtitle: 'github.com/krutoychel24/pdf-book-reader',
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(
                      context,
                      'https://github.com/krutoychel24/pdf-book-reader',
                    ),
                  ),
                  const _ActionRow(
                    icon: Icons.person_outline,
                    title: 'Developer',
                    subtitle: 'HruhruStudio',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _getThemeName(ThemeMode themeMode, S s) {
    switch (themeMode) {
      case ThemeMode.system:
        return s.systemTheme;
      case ThemeMode.light:
        return s.lightTheme;
      case ThemeMode.dark:
        return s.darkTheme;
    }
  }

  void _showThemeDialog(BuildContext context, SettingsProvider provider, S s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((themeMode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeName(themeMode, s)),
              value: themeMode,
              groupValue: provider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  provider.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsProvider.supportedLocales.map((locale) {
            final isSelected =
                provider.locale?.languageCode == locale.languageCode;
            return ListTile(
              title: Text(
                SettingsProvider.languageNames[locale.languageCode] ??
                    locale.languageCode,
              ),
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () {
                provider.setLocale(locale);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening link')),
      );
    }
  }
}

class _SettingsHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.42),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.menu_book_outlined, color: colorScheme.onPrimary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JHB Mobile App',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: colorScheme.outlineVariant.withOpacity(0.65)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title)),
                    Text(valueLabel),
                  ],
                ),
                Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
