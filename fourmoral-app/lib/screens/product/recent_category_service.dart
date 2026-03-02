import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class RecentCategoryService extends GetxController {
  final RxList<String> recentCategories = <String>[].obs;
  final _box = GetStorage();
  final String _key = 'recent_categories';
  final int _maxRecent = 5;

  static RecentCategoryService get instance => Get.find();

  @override
  void onInit() {
    super.onInit();
    _loadRecentCategories();
  }

  void _loadRecentCategories() {
    final data = _box.read<List<dynamic>>(_key) ?? [];
    final stringCategories = data.whereType<String>().toList();
    recentCategories.assignAll(stringCategories);
  }

  void addRecentCategory(String category) {
    if (category.isEmpty) return;

    recentCategories.removeWhere(
      (c) => c.toLowerCase() == category.toLowerCase(),
    );
    recentCategories.insert(0, category);

    if (recentCategories.length > _maxRecent) {
      recentCategories.removeRange(_maxRecent, recentCategories.length);
    }

    _box.write(_key, recentCategories.toList());
  }
  void removeRecentCategory(String category) {
    recentCategories.remove(category); // Remove the specified category
  }
}