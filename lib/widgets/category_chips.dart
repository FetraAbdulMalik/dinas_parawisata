import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';

class CategoryChips extends StatelessWidget {
  final Future<void> Function()? onCultureDropdownTap;

  const CategoryChips({super.key, this.onCultureDropdownTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: state.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final category = state.categories[i];
              return _CategoryChip(
                label: category,
                selected: category == state.category,
                onTap: () => context.read<AppState>().setCategory(category),
              );
            },
          ),
        ),
        if (state.category == 'Budaya') ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _CultureTypeComboBox(
              selected: state.cultureType,
              onBeforeOpen: onCultureDropdownTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _CultureTypeComboBox extends StatefulWidget {
  final String? selected;
  final Future<void> Function()? onBeforeOpen;

  const _CultureTypeComboBox({
    required this.selected,
    this.onBeforeOpen,
  });

  @override
  State<_CultureTypeComboBox> createState() => _CultureTypeComboBoxState();
}

class _CultureTypeComboBoxState extends State<_CultureTypeComboBox> {
  static const _options = [
    ('', 'Semua Budaya'),
    ('Cagar Budaya', 'Cagar Budaya'),
    ('Warisan Budaya Tak Benda', 'Warisan Budaya Tak Benda'),
  ];

  final _buttonKey = GlobalKey();

  Future<void> _openMenu() async {
    await widget.onBeforeOpen?.call();
    if (!mounted) return;

    final button = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = button.localToGlobal(
      Offset(button.size.width, button.size.height),
      ancestor: overlay,
    );
    final selected = await showMenu<String>(
      context: context,
      color: Colors.white.withValues(alpha: 0.50),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - topLeft.dy,
      ),
      constraints: BoxConstraints.tightFor(width: button.size.width),
      items: [
        for (final option in _options)
          PopupMenuItem<String>(
            value: option.$1,
            height: 20,
            child: Text(
              option.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
    if (selected != null && mounted) {
      context
          .read<AppState>()
          .setCultureType(selected.isEmpty ? null : selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _options
        .firstWhere((option) => option.$1 == (widget.selected ?? ''))
        .$2;
    return SizedBox(
      key: _buttonKey,
      height: 30,
      child: Material(
        color: Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _openMenu,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.green),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppColors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.green),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
