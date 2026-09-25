import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/settings.dart';
import '../../state/providers.dart';
import '../navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'tutorial_screen.dart';

/// Whether UMP requires a "Privacy options" entry in this region.
final privacyOptionsRequiredProvider = FutureProvider<bool>(
  (ref) => ref.read(adServiceProvider).privacyOptionsRequired(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    void set(Settings Function(Settings) f) => ctrl.update(f);

    return MenuScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SectionLabel('Sound & feel'),
          _Group(
            children: [
              _Toggle('Sound', s.sound, (v) => set((s) => s.copyWith(sound: v))),
              _Toggle('Music', s.music, (v) => set((s) => s.copyWith(music: v))),
              _Toggle('Haptics', s.haptics, (v) => set((s) => s.copyWith(haptics: v))),
            ],
          ),
          const SectionLabel('Theme'),
          ChoiceRow<AppThemeKind>(
            values: AppThemeKind.values,
            selected: s.theme,
            label: (t) => t.label,
            onChanged: (t) => set((s) => s.copyWith(theme: t)),
          ),
          const SectionLabel('Board style'),
          ChoiceRow<BoardStyle>(
            values: BoardStyle.values,
            selected: s.boardStyle,
            label: (b) => b.label,
            onChanged: (b) => set((s) => s.copyWith(boardStyle: b)),
          ),
          const SectionLabel('Display'),
          _Group(
            children: [
              _Toggle('Animations', s.animations, (v) => set((s) => s.copyWith(animations: v))),
              _Toggle(
                'High contrast',
                s.highContrast,
                (v) => set((s) => s.copyWith(highContrast: v)),
                subtitle: 'Stronger cell edges and text',
              ),
            ],
          ),
          const SectionLabel('AI speed'),
          ChoiceRow<AiSpeed>(
            values: AiSpeed.values,
            selected: s.aiSpeed,
            label: (a) => a.label,
            onChanged: (a) => set((s) => s.copyWith(aiSpeed: a)),
          ),
          const SectionLabel('Gameplay'),
          _Group(
            children: [
              _Toggle(
                'Show move hints',
                s.showHints,
                (v) => set((s) => s.copyWith(showHints: v)),
                subtitle: 'Highlight where the selected token can go',
              ),
              _Toggle(
                'Confirm move',
                s.confirmMove,
                (v) => set((s) => s.copyWith(confirmMove: v)),
                subtitle: 'Tap again to confirm each move',
              ),
              _Toggle(
                'Pass-the-device screen',
                s.passDevice,
                (v) => set((s) => s.copyWith(passDevice: v)),
                subtitle: 'Between turns in local 2-player games',
              ),
            ],
          ),
          const SectionLabel('Language'),
          _Group(children: [_Row(title: 'Language', value: 'English', onTap: null)]),
          const SectionLabel('Your data'),
          _Group(
            children: [
              _Row(title: 'Export progress', icon: Icons.upload_file_rounded, onTap: () => _export(context, ref)),
              _Row(title: 'Import progress', icon: Icons.download_rounded, onTap: () => _import(context, ref)),
              _Row(
                title: 'Reset progress',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: () => _reset(context, ref),
              ),
            ],
          ),
          const SectionLabel('About'),
          _Group(
            children: [
              _Row(
                title: 'How to play',
                icon: Icons.school_outlined,
                onTap: () => Navigator.of(context).push(fadeRoute<void>(const TutorialScreen())),
              ),
              _Row(title: 'Privacy', icon: Icons.lock_outline_rounded, onTap: () => _privacy(context)),
              if (ref.watch(privacyOptionsRequiredProvider).valueOrNull ?? false)
                _Row(
                  title: 'Ad privacy options',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => ref.read(adServiceProvider).showPrivacyOptionsForm(),
                ),
              _Row(title: 'About', icon: Icons.info_outline_rounded, onTap: () => _about(context)),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _export(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repositoryProvider);
    final data = repo.exportBackup(ref.read(profileProvider), ref.read(settingsProvider));
    final text = const JsonEncoder.withIndent('  ').convert(data);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}hexadominate_backup.json');
      await file.writeAsString(text, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'HexaDominate backup',
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // No share target: fall back to the clipboard.
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(const SnackBar(content: Text('Backup copied to the clipboard')));
    }
  }

  static Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    String? text;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes != null) {
        text = utf8.decode(bytes);
      } else if (picked?.files.single.path != null) {
        text = await File(picked!.files.single.path!).readAsString();
      }
    } catch (_) {
      text = null;
    }
    if (text == null) {
      // Offer the clipboard for backups that were copied rather than saved.
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text == null || !clip!.text!.contains('hexadominate')) return;
      text = clip.text;
    }
    if (!context.mounted) return;
    try {
      final (profile, settings) = ref.read(repositoryProvider).parseBackup(text!);
      final ok = await confirmDialog(
        context,
        title: 'Restore backup?',
        message:
            'This replaces your current progress with the backup '
            '(${profile.levelsCompleted} levels, ${profile.stats.gamesPlayed} games).',
        confirm: 'Restore',
        destructive: true,
      );
      if (ok != true) return;
      ref.read(profileProvider.notifier).replace(profile);
      ref.read(settingsProvider.notifier).replace(settings.copyWith(tutorialSeen: true));
      messenger.showSnackBar(const SnackBar(content: Text('Progress restored')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Reset progress?',
      message:
          'All levels, stars, statistics and achievements on this device will be erased. '
          'This cannot be undone. Export a backup first if you might want them back.',
      confirm: 'Reset',
      destructive: true,
    );
    if (ok != true) return;
    ref.read(profileProvider.notifier).reset();
    ref.read(savedGameProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progress reset')));
    }
  }

  static void _privacy(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy'),
      content: const SingleChildScrollView(
        child: Text(
          'This game does not require an account.\n\n'
          'Your game progress, settings and statistics are stored locally on your device.\n\n'
          'No game data is uploaded to a server. The game has no ads, no analytics '
          'and no tracking, and works fully offline.\n\n'
          'Exporting a backup creates a file you control; it is only shared where you choose to send it.',
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  static void _about(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HexLogo(size: 72),
            const SizedBox(height: 14),
            Text(
              'HEXADOMINATE',
              style: TextStyle(color: p.text, fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 18),
            ),
            Text('Conquer every hex.', style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 10),
            Text('Version 1.0.0', style: TextStyle(color: p.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            Text(
              'No account. No server. No internet needed.\n'
              '300 levels, 30 challenges and a daily board, all on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => showLicensePage(context: context, applicationName: 'HexaDominate'),
            child: const Text('Licences'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      );
    },
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 18, endIndent: 18, color: p.boardEdge.withValues(alpha: 0.6)),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.title, this.value, this.onChanged, {this.subtitle});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      title: Text(title, style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.value, this.icon, this.onTap, this.destructive = false});
  final String title;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destructive ? Theme.of(context).colorScheme.error : p.text;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      leading: icon == null ? null : Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: value != null
          ? Text(value!, style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600))
          : (onTap != null ? Icon(Icons.chevron_right_rounded, color: p.textSecondary) : null),
    );
  }
}
