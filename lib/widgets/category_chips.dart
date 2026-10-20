import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';

class CategoryChips extends StatelessWidget {
  final Future<void> Function()? onSubtypeDropdownTap;

  const CategoryChips({super.key, this.onSubtypeDropdownTap});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final subcategoryDropdown = switch (state.category) {
      'Budaya' => SubCategoryDropdown(
          selected: state.cultureType,
          options: const [
            ('', 'Semua Budaya'),
            ('Cagar Budaya', 'Cagar Budaya'),
            ('Warisan Budaya Tak Benda', 'Warisan Budaya Tak Benda'),
          ],
          onSelected: context.read<AppState>().setCultureType,
          onBeforeOpen: onSubtypeDropdownTap,
        ),
      'Alam' => SubCategoryDropdown(
          selected: state.natureType,
          options: const [
            ('', 'Semua Alam'),
            ('Gunung', 'Gunung'),
            ('Danau', 'Danau'),
            ('Kawah', 'Kawah'),
            ('Laut', 'Laut'),
            ('Air Terjun', 'Air Terjun'),
            ('Lubuk', 'Lubuk'),
          ],
          onSelected: context.read<AppState>().setNatureType,
          onBeforeOpen: onSubtypeDropdownTap,
        ),
      _ => null,
    };
    final categoryList = _CategoryChipList(
      categories: state.categories,
      selectedCategory: state.category,
      onSelected: context.read<AppState>().setCategory,
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Expanded(child: categoryList),
            if (subcategoryDropdown != null) ...[
              const SizedBox(width: 16),
              SizedBox(width: 290, child: subcategoryDropdown),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: categoryList,
        ),
        if (subcategoryDropdown != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: subcategoryDropdown,
          ),
        ],
      ],
    );
  }
}

class _CategoryChipList extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategoryChipList({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final category = categories[index];
          return _CategoryChip(
            label: category,
            selected: category == selectedCategory,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class SubCategoryDropdown extends StatefulWidget {
  final String? selected;
  final List<(String, String)> options;
  final ValueChanged<String?> onSelected;
  final Future<void> Function()? onBeforeOpen;

  const SubCategoryDropdown({
    super.key,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.onBeforeOpen,
  });

  @override
  State<SubCategoryDropdown> createState() => _SubCategoryDropdownState();
}

class _SubCategoryDropdownState extends State<SubCategoryDropdown> {
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
      color: Colors.white,
      elevation: 8,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - topLeft.dy,
      ),
      constraints: BoxConstraints.tightFor(width: button.size.width),
      items: [
        for (final option in widget.options)
          PopupMenuItem<String>(
            value: option.$1,
            height: 48,
            child: Row(
              children: [
                Icon(_subCategoryIcon(option.$1), color: AppColors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                if (option.$1 == (widget.selected ?? ''))
                  const Icon(Icons.check, color: AppColors.green, size: 20),
              ],
            ),
          ),
      ],
    );
    if (selected != null && mounted) {
      widget.onSelected(selected.isEmpty ? null : selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.options
        .firstWhere((option) => option.$1 == (widget.selected ?? ''))
        .$2;
    return SizedBox(
      key: _buttonKey,
      height: 40,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openMenu,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.green, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(
                  _subCategoryIcon(widget.selected ?? ''),
                  color: AppColors.green,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
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

IconData _subCategoryIcon(String value) => switch (value) {
      'Gunung' => Icons.landscape_outlined,
      'Danau' => Icons.water_outlined,
      'Kawah' => Icons.volcano_outlined,
      'Laut' => Icons.waves_outlined,
      'Air Terjun' => Icons.waterfall_chart_outlined,
      'Lubuk' => Icons.pool_outlined,
      'Cagar Budaya' => Icons.account_balance_outlined,
      'Warisan Budaya Tak Benda' => Icons.theater_comedy_outlined,
      _ => Icons.layers_outlined,
    };

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
            fontSize: 14,
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
