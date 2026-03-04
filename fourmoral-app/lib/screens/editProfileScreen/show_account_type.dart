import 'package:dropdown_search/dropdown_search.dart';
// import 'package:firebase_database/firebase_database.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/screens/editProfileScreen/edit_profile_controller.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:get/get.dart';

void showAccountTypeSelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (context) {
      return AccountTypeSelector();
    },
  );
}

class AccountTypeSelector extends StatefulWidget {
  const AccountTypeSelector({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AccountTypeSelectorState createState() => _AccountTypeSelectorState();
}

class _AccountTypeSelectorState extends State<AccountTypeSelector> {
  final cnt = Get.put(EditProfileCnt());

  Future<void> fetchCategories(String accountType) async {
    setState(() => cnt.isLoadingCategories.value = true);
    if (accountType == 'Standard') {
      setState(() {
        cnt.categories.value = [];
        cnt.isLoadingCategories.value = false;
      });
      return;
    }

    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref(
        'Categories/$accountType',
      );
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        if (snapshot.value is Map) {
          Map<dynamic, dynamic> values = snapshot.value as Map;
          setState(() {
            cnt.categories.value =
                values.values.map((e) => e.toString()).toList();
            cnt.isLoadingCategories.value = false;
          });
        } else if (snapshot.value is List) {
          List<dynamic> values = snapshot.value as List;
          setState(() {
            cnt.categories.value = values.map((e) => e.toString()).toList();
            cnt.isLoadingCategories.value = false;
          });
        }
      } else {
        setState(() {
          cnt.categories.value = [];
          cnt.isLoadingCategories.value = false;
        });
        flutterShowToast('No categories found for $accountType');
      }
    } catch (e) {
      setState(() {
        cnt.categories.value = [];
        cnt.isLoadingCategories.value = false;
      });
      flutterShowToast('Failed to load categories: ${e.toString()}');
      debugPrint('Error fetching categories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min, // Important for bottom sheet
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(
              "Select Account Type",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(height: 1, color: black),
          radioType(),
          const SizedBox(height: 10),
          if (cnt.isLoadingCategories.value)
            CircularProgressIndicator(color: white)
          else if (cnt.categories.isNotEmpty)
            DropdownSearch<String>(
              selectedItem:
                  cnt.categoryController.text.isEmpty
                      ? null
                      : cnt.categoryController.text,
              items: (filter, infiniteScrollProps) => cnt.categories,
              decoratorProps: DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: TextStyle(
                    color: Colors.black,
                  ), // Changed to black for visibility
                  hintText: 'Select your category',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                    ), // Changed to black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black,
                    ), // Changed to black
                  ),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: "Search category",
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.black,
                    ), // Changed to black
                    filled: true,
                    fillColor: Colors.white, // Set background color to white
                  ),
                ),
                menuProps: MenuProps(backgroundColor: Colors.white),
              ),
              onChanged: (value) {
                setState(() {
                  cnt.categoryController.text = value ?? '';
                });
              },
            ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
              onPressed: () {
                Navigator.pop(context, cnt.selectedType.value);
              },
              child: Text(
                "Confirm",
                style: TextStyle(
                  color: black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  // String getAccountTypeKey(int typeSelected) {
  //   switch (typeSelected) {
  //     case 0:
  //       return 'Standard';
  //     case 1:
  //       return 'Mentor';
  //     case 2:
  //       return 'Ngo';
  //     case 3:
  //       return 'Holy peaces';
  //     case 4:
  //       return 'Media';
  //     case 5:
  //       return 'Businesses';
  //     default:
  //       return 'Standard';
  //   }
  // }

  Widget radioType() {
    return Obx(
      () => Column(
        children: [
          ...accountTypes.map(
            (type) => RadioListTile<String>(
              title: Text(type),
              value: type,
              groupValue: cnt.selectedType.value,
              activeColor: blue,
              onChanged: (value) {
                cnt.selectedType.value = value ?? "";
                cnt.categoryController.clear();
                cnt.categories.value = [];
                fetchCategories(cnt.selectedType.value);
              },
            ),
          ),

          // Add the note display here
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              getAccountTypeNote(cnt.selectedType.value),
              style: TextStyle(
                color: black,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  final List<String> accountTypes = [
    "Standard",
    "Mentor",
    "Ngo",
    "Holy peaces",
    "Media",
    "Business",
  ];

  String getAccountTypeNote(String typeSelected) {
    switch (typeSelected) {
      case "Standard": // Standard
        return "Standard accounts are for personal use. You can connect with others, share content, and explore the platform.";
      case "Mentor": // Mentor
        return "Mentor accounts are for professionals who want to share knowledge. You'll need to provide credentials to verify your expertise.";
      case "Ngo": // NGO
        return "NGO accounts are for non-profit organizations. You'll be able to post about your causes and connect with supporters.";
      case "Holy peaces": // Holy places
        return "Holy peaces accounts are for religious institutions. You can share information about your services and events.";
      case "Media": // Media
        return "Media accounts are for journalists and media organizations. You'll need to provide credentials to verify your identity.";
      case "Business": // Business
        return "Business accounts are for companies and brands. You'll be able to showcase products, services, and connect with customers.";
      default:
        return "Select an account type to see more information.";
    }
  }
}
