import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../localization/languages.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: AppLanguages.all.length,
    padding: const EdgeInsets.symmetric(vertical: 4),
    separatorBuilder: (_, _) => const SizedBox(height: 7),
    itemBuilder: (context, index) {
      final language = AppLanguages.all[index];
      final active = selected == language.code;
      return BrainCard(
        padding: EdgeInsets.zero,
        accent: active ? energyCyan : null,
        child: ListTile(
          key: Key('language_${language.code}'),
          title: Text(language.nativeName, maxLines: 2),
          trailing: active
              ? const Icon(Icons.check_circle_rounded, color: energyCyan)
              : null,
          onTap: () => onSelected(language.code),
        ),
      );
    },
  );
}

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return RushScaffold(
      title: context.tr('language'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: LanguagePicker(
          selected: store.language,
          onSelected: (code) => store.setLanguage(code),
        ),
      ),
    );
  }
}

class PlayerNameEditor extends StatefulWidget {
  const PlayerNameEditor({
    super.key,
    this.initialName,
    required this.onSave,
    this.onSkip,
    this.onClear,
  });
  final String? initialName;
  final Future<void> Function(String name) onSave;
  final VoidCallback? onSkip;
  final Future<void> Function()? onClear;

  @override
  State<PlayerNameEditor> createState() => _PlayerNameEditorState();
}

class _PlayerNameEditorState extends State<PlayerNameEditor> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initialName,
  );
  String? errorKey;
  bool saving = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    final name = controller.text.trim();
    if (name.isEmpty || name.runes.length > AppStore.maxPlayerNameLength) {
      setState(() => errorKey = name.isEmpty ? 'nameRequired' : 'nameTooLong');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(name);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.person_outline_rounded,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('playerName'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('playerNameHint'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        BrainCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            key: const Key('playerNameField'),
            controller: controller,
            maxLength: AppStore.maxPlayerNameLength,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: context.tr('playerNamePlaceholder'),
              border: InputBorder.none,
              errorText: errorKey == null ? null : context.tr(errorKey!),
            ),
            onChanged: (_) {
              if (errorKey != null) setState(() => errorKey = null);
            },
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 20),
        GamePrimaryButton(
          label: context.tr(widget.onSkip == null ? 'saveName' : 'continue'),
          onPressed: saving ? null : _save,
        ),
        if (widget.onSkip != null)
          TextButton(
            onPressed: saving ? null : widget.onSkip,
            child: Text(context.tr('skip')),
          ),
        if (widget.onClear != null && widget.initialName != null)
          TextButton.icon(
            onPressed: saving ? null : () async => widget.onClear!(),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(context.tr('clearName')),
          ),
      ],
    ),
  );
}

class PlayerNameSettingsScreen extends ConsumerWidget {
  const PlayerNameSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return RushScaffold(
      title: context.tr('playerName'),
      child: PlayerNameEditor(
        initialName: store.playerName,
        onSave: (name) async {
          await store.setPlayerName(name);
          if (context.mounted) Navigator.of(context).pop();
        },
        onClear: () async {
          await store.setPlayerName(null);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  String? selected;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    return RushScaffold(
      child: step == 0
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.bolt_rounded, color: energyCyan, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('welcome'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('chooseLanguage'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    context.tr('chooseLanguageHint'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: LanguagePicker(
                      selected: selected,
                      onSelected: (code) {
                        setState(() => selected = code);
                        store.setLanguage(code);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  GamePrimaryButton(
                    label: context.tr('continue'),
                    onPressed: selected == null
                        ? null
                        : () => setState(() => step = 1),
                  ),
                ],
              ),
            )
          : PlayerNameEditor(
              onSave: (name) async {
                await store.setPlayerName(name);
                await store.completeOnboarding();
              },
              onSkip: () => store.completeOnboarding(),
            ),
    );
  }
}
