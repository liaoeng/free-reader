import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_reader/core/theme/theme_mode_codec.dart';
import 'package:free_reader/features/setting/providers/setting_providers.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(appSettingProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('我的'),
          floating: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Text(
                '设置',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              setting.when(
                data: (value) => _SettingContent(
                  darkModeEnabled: value.theme == ThemeModeCodec.dark,
                  fontSize: value.fontSize,
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('设置读取失败'),
                    subtitle: Text('$error'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingContent extends ConsumerWidget {
  const _SettingContent({
    required this.darkModeEnabled,
    required this.fontSize,
  });

  final bool darkModeEnabled;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            value: darkModeEnabled,
            onChanged: controller.setDarkModeEnabled,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_size),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '字号',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(fontSize.toStringAsFixed(0)),
                  ],
                ),
                Slider(
                  min: 14,
                  max: 28,
                  divisions: 14,
                  value: fontSize.clamp(14, 28).toDouble(),
                  onChanged: controller.setFontSize,
                ),
                Text(
                  '起初，神创造天地。',
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
