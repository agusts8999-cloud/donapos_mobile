import 'package:flutter/material.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';


class PosCategorySidebar extends StatelessWidget {
  final List<Category> categories;
  final int selectedCategoryId;
  final ValueChanged<int> onCategorySelected;

  const PosCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100.sc,
      color: MetroColors.primary,

      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Favorites Category
          _buildCategoryItem(
            Category(id: -1, name: 'Favorit'),
            selectedCategoryId == -1,
            isFavorite: true,
          ),
          ...categories.map((c) {
            return _buildCategoryItem(c, selectedCategoryId == c.id);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Category c, bool isSelected, {bool isFavorite = false}) {
    return Material(
      color: isSelected ? Colors.grey[200] : MetroColors.primary,
      child: InkWell(
        onTap: () => onCategorySelected(c.id),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20.sc, horizontal: 4.sc),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    left: BorderSide(color: MetroColors.primary, width: 4.sc))
                : Border(
                    bottom: BorderSide(color: Colors.white10, width: 1.sc)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFavorite) ...[
                   Icon(Icons.star, color: isSelected ? Colors.orange : Colors.yellow, size: 24.sc),
                   SizedBox(height: 4.sc),
                ],
                Text(
                  c.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? MetroColors.primary : Colors.white,
                    letterSpacing: 0.5.sc,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
