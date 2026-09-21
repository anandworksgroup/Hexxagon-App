import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog.dart';
import '../../state/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/token_painter.dart';

class TokensScreen extends ConsumerWidget {
  const TokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(profileProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final color = p.player(settings.playerColor);
    final unlocked = unlockedTokenCount(profile);

    return MenuScaffold(
      title: 'Tokens',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: TokenIcon(color: color, token: settings.playerToken, symbolColor: p.symbol, size: 104),
          ),
          const SizedBox(height: 12),
          Text(
            '${colorNames[settings.playerColor]} ${tokenCatalog[settings.playerToken].name}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            '$unlocked of ${tokenCatalog.length} tokens unlocked',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary),
          ),
          const SectionLabel('Colour'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < colorNames.length; i++)
                Semantics(
                  button: true,
                  selected: i == settings.playerColor,
                  label: colorNames[i],
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => ctrl.update((s) => s.copyWith(playerColor: i)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: p.player(i),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == settings.playerColor ? p.text : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: i == settings.playerColor ? Icon(Icons.check_rounded, color: p.symbol) : null,
                    ),
                  ),
                ),
            ],
          ),
          const SectionLabel('Symbol'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisExtent: 128,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: tokenCatalog.length,
            itemBuilder: (context, i) {
              final def = tokenCatalog[i];
              final open = isTokenUnlocked(i, profile);
              final selected = settings.playerToken == i;
              return Semantics(
                button: open,
                selected: selected,
                label: open ? '${def.name} token' : '${def.name} token, locked until level ${def.unlockLevel}',
                excludeSemantics: true,
                child: Material(
                  color: selected ? color.withValues(alpha: 0.18) : p.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: open ? () => ctrl.update((s) => s.copyWith(playerToken: i)) : null,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              TokenIcon(
                                color: open ? color : p.boardEdge,
                                token: i,
                                symbolColor: p.symbol,
                                size: 52,
                                dimmed: !open,
                              ),
                              if (!open) Icon(Icons.lock_rounded, color: p.textSecondary, size: 22),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            def.name,
                            style: TextStyle(color: open ? p.text : p.textSecondary, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            open ? (selected ? 'In use' : ' ') : 'Level ${def.unlockLevel}',
                            style: TextStyle(color: p.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
