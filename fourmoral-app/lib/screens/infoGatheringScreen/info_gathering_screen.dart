import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/homePageScreen/home_page_screen_services.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:fourmoral/services/random_key_generator.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/log_in_services.dart';
import '../../widgets/box_decoration_widget.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../../widgets/confirm_dialogue_box.dart';
import '../../widgets/flutter_toast.dart';
import '../navigationBar/navigation_bar.dart';

class InfoGatheringScreen extends StatefulWidget {
  const InfoGatheringScreen({super.key, this.userPhoneNumber});
  final String? userPhoneNumber;

  @override
  // ignore: library_private_types_in_public_api
  _InfoGatheringScreenState createState() => _InfoGatheringScreenState();
}

class _InfoGatheringScreenState extends State<InfoGatheringScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categoryController = TextEditingController();

  List<String> categories = [];
  bool isLoadingCategories = false;

  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _ageFocusNode = FocusNode();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final usernameRegex = RegExp(r'^(?=.*[\d_.])[a-zA-Z\d_.]+$');

  CollectionReference collectionUserReference = FirebaseFirestore.instance
      .collection('Users');

  int typeSelected = 0;
  int genderSelected = 0;

  File? file;
  List<String> suggestedUsernames = [];
  String? selectedCommunity;
  bool isGeneratingSuggestions = false;
  final List<String> communities = [
    'Hindu',
    'Muslim',
    'Christian',
    'Sikh',
    'Buddhist',
    'Jain',
    'Jewish',
    'Parsi',
    'Atheist',
    'Other',
  ];

  String getAccountTypeNote(int typeSelected) {
    switch (typeSelected) {
      case 0: // Standard
        return "Standard accounts are for personal use. You can connect with others, share content, and explore the platform.";
      case 1: // Mentor
        return "Mentor accounts are for professionals who want to share knowledge. You'll need to provide credentials to verify your expertise.";
      case 2: // NGO
        return "NGO accounts are for non-profit organizations. You'll be able to post about your causes and connect with supporters.";
      case 3: // Holy places
        return "Holy places accounts are for religious institutions. You can share information about your services and events.";
      case 4: // Media
        return "Media accounts are for journalists and media organizations. You'll need to provide credentials to verify your identity.";
      case 5: // Business
        return "Business accounts are for companies and brands. You'll be able to showcase products, services, and connect with customers.";
      default:
        return "Select an account type to see more information.";
    }
  }

  // Helper function to generate random string
  String getRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  String getAccountTypeKey(int typeSelected) {
    switch (typeSelected) {
      case 0:
        return 'Standard';
      case 1:
        return 'Mentor';
      case 2:
        return 'Ngo';
      case 3:
        return 'Holy peaces';
      case 4:
        return 'Media';
      case 5:
        return 'Business';
      default:
        return 'Standard';
    }
  }

  Future<void> fetchCategories(String accountType) async {
    setState(() => isLoadingCategories = true);
    if (accountType == 'Standard') {
      setState(() {
        categories = [];
        isLoadingCategories = false;
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
            categories = values.values.map((e) => e.toString()).toList();
            isLoadingCategories = false;
          });
        } else if (snapshot.value is List) {
          List<dynamic> values = snapshot.value as List;
          setState(() {
            categories = values.map((e) => e.toString()).toList();
            isLoadingCategories = false;
          });
        }
      } else {
        setState(() {
          categories = [];
          isLoadingCategories = false;
        });
        flutterShowToast('No categories found for $accountType');
      }
    } catch (e) {
      setState(() {
        categories = [];
        isLoadingCategories = false;
      });
      flutterShowToast('Failed to load categories: ${e.toString()}');
      debugPrint('Error fetching categories: $e');
    }
  }

  Timer? _debounce;
  bool _isChecking = false;
  String? _status;

  bool _isValid(String username) {
    final validRegex = RegExp(r'^[a-z0-9._]+$');
    return validRegex.hasMatch(username);
  }

  Icon? _buildStatusIcon() {
    if (_isChecking) {
      return const Icon(Icons.hourglass_top, color: Colors.grey);
    }

    switch (_status) {
      case 'available':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'taken':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'invalid':
        return const Icon(Icons.warning, color: Colors.orange);
      default:
        return null;
    }
  }

  void _onUsernameInputChanged() {
    final username = _usernameController.text.trim().toLowerCase();

    _debounce?.cancel();

    if (username.isEmpty) {
      setState(() {
        _status = null;
        _isChecking = false;
        suggestedUsernames = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Validate username (no spaces, only a-z, 0-9, . _ )
      if (!_isValid(username)) {
        setState(() {
          _status = 'invalid';
          _isChecking = false;
          suggestedUsernames = [];
        });
        return;
      }

      // Start checking availability
      setState(() {
        _isChecking = true;
        _status = null;
      });

      final query =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      final isAvailable = query.docs.isEmpty;

      setState(() {
        _status = isAvailable ? 'available' : 'taken';
        _isChecking = false;
      });

      await _generateSuggestions(username);
    });
  }

  Future<void> _generateSuggestions(String name) async {
    if (name.isEmpty) {
      setState(() => suggestedUsernames = []);
      return;
    }

    setState(() => isGeneratingSuggestions = true);

    final lowercaseName = name.toLowerCase();
    List<String> baseSuggestions = [];

    baseSuggestions.addAll([
      '$lowercaseName${_randomInt(3)}',
      '${lowercaseName}_${_randomString(3)}',
      'the$lowercaseName${_randomInt(2)}',
      '$lowercaseName.official',
      'real$lowercaseName',
    ]);

    if (genderSelected == 0) {
      baseSuggestions.addAll([
        'mr$lowercaseName',
        'mr.$lowercaseName${_randomInt(2)}',
      ]);
    } else if (genderSelected == 1) {
      baseSuggestions.addAll([
        'ms$lowercaseName',
        'ms.$lowercaseName${_randomInt(2)}',
      ]);
    }

    baseSuggestions = baseSuggestions.toSet().toList(); // Remove duplicates

    List<String> uniqueSuggestions = [];

    for (final suggestion in baseSuggestions) {
      final exists = await _usernameExists(suggestion);
      if (!exists) uniqueSuggestions.add(suggestion);
      if (uniqueSuggestions.length >= 4) break;
    }

    // Add fallback random suggestions if less than 4
    while (uniqueSuggestions.length < 4) {
      final fallback = '$lowercaseName${_randomString(4)}';
      final exists = await _usernameExists(fallback);
      if (!exists) uniqueSuggestions.add(fallback);
    }

    setState(() {
      suggestedUsernames = uniqueSuggestions;
      isGeneratingSuggestions = false;
    });
  }

  Future<bool> _usernameExists(String username) async {
    final result =
        await FirebaseFirestore.instance
            .collection('Users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
    return result.docs.isNotEmpty;
  }

  int _randomInt(int length) {
    final rand = Random();
    return int.parse(List.generate(length, (_) => rand.nextInt(10)).join());
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameInputChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      backgroundColor: white,
      resizeToAvoidBottomInset: false,
      body: Container(
        height: height,
        width: width,
        decoration: boxDecorationWidget(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: height * 0.03),
                SizedBox(
                  height: height * 0.1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: GestureDetector(
                      onTap: () {
                        confirmDialogue(
                          context,
                          "Go Back",
                          "Do you really want to go to the Log In Page?",
                          () async {
                            AuthService().signOut(context);

                            await AppPreference().setBool(
                              PreferencesKey.loggedIn,
                              false,
                            );
                            await AppPreference().setBool(
                              PreferencesKey.infoGathered,
                              false,
                            );
                            await AppPreference().setString(
                              PreferencesKey.userPhoneNumber,
                              '',
                            );

                            flutterShowToast('Signed Out Successfully');
                          },
                          () {
                            Navigator.pop(context);
                          },
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 10),
                          Icon(
                            Icons.arrow_back_ios_new_sharp,
                            color: white,
                            size: 25,
                          ),
                          const SizedBox(width: 10),
                          AutoSizeText(
                            "Go back",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(child: profileImageWidget(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Name",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: black,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color:
                              Colors
                                  .lightBlueAccent
                                  .shade100, // background color like your screenshot
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Enter Name',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide
                                      .none, // removes default grey border
                            ),
                          ),
                          onFieldSubmitted: (value) {},
                          onEditingComplete: () {
                            FocusScope.of(context).requestFocus(_ageFocusNode);
                          },
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "User Name",
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              color: black,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color:
                                  Colors
                                      .lightBlueAccent
                                      .shade100, // background color like your screenshot
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextFormField(
                              controller: _usernameController,
                              // onChanged: _onChanged,
                              focusNode: _usernameFocusNode,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-z0-9._]'),
                                ),
                              ],
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              decoration: InputDecoration(
                                hintText: 'Enter username',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixIcon: _buildStatusIcon(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide
                                          .none, // removes default grey border
                                ),
                              ),

                              onFieldSubmitted: (value) {
                                // setState(() {
                                //   buttonFocus = value.isEmpty;
                                //   nameFocus = value.isEmpty;
                                // });
                              },
                              onEditingComplete: () {
                                FocusScope.of(
                                  context,
                                ).requestFocus(_nameFocusNode);
                              },
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          SizedBox(height: 10),
                          if (suggestedUsernames.isNotEmpty ||
                              isGeneratingSuggestions)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Suggested usernames:',
                                      style: TextStyle(
                                        color: black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    if (isGeneratingSuggestions)
                                      SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          color: white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                isGeneratingSuggestions
                                    ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        'Generating unique username suggestions...',
                                        style: TextStyle(
                                          color: white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                    : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          suggestedUsernames.map((username) {
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _usernameController.text =
                                                      username;
                                                  // buttonFocus = false;
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: white,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  username,
                                                  style: TextStyle(
                                                    color: black,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                    ),
                              ],
                            ),
                        ],
                      ),
                      // textFormFieldWidget(
                      //     'Age',
                      //     size,
                      //     context,
                      //     _ageController,
                      //     _ageFocusNode,
                      //     _bioFocusNode,
                      //     'Enter Your Age',
                      //     false,
                      //     true, (value) {
                      //   // if (value.isEmpty) {
                      //   //   return 'Enter Age';
                      //   // } else {
                      //   //   return null;
                      //   // }
                      // }, true),
                      SizedBox(height: 10),
                      // if (!nameFocus)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        width: size.width * 0.9,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              "Gender",
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: black,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // const SizedBox(height: 5),
                      radioGenderType(),
                      // textFormFieldWidget(
                      //     'Bio',
                      //     size,
                      //     context,
                      //     _bioController,
                      //     _bioFocusNode,
                      //     _addressFocusNode,
                      //     'Enter Your Bio',
                      //     false,
                      //     false, (value) {
                      //   if (value.toString().length > 100) {
                      //     return 'Less than 100';
                      //   } else {
                      //     return null;
                      //   }
                      // }, true),
                      // textFormFieldWidget(
                      //     'Address',
                      //     size,
                      //     context,
                      //     _addressController,
                      //     _addressFocusNode,
                      //     _emailFocusNode,
                      //     'Enter Your Address',
                      //     false,
                      //     false, (value) {
                      //   // if (value.isEmpty) {
                      //   //   return 'Enter Address';
                      //   // } else {
                      //   //   return null;
                      //   // }
                      // }, true),
                      // textFormFieldWidget(
                      //     'Email Address',
                      //     size,
                      //     context,
                      //     _emailController,
                      //     _emailFocusNode,
                      //     _religionFocusNode,
                      //     'Enter Your Email Address',
                      //     false,
                      //     false, (value) {
                      //   // if (value.isEmpty) {
                      //   //   return 'Enter Email Address';
                      //   // } else {
                      //   //   return null;
                      //   // }
                      // }, true),
                      // textFormFieldWidget(
                      //     'Religion',
                      //     size,
                      //     context,
                      //     _religionController,
                      //     _religionFocusNode,
                      //     null,
                      //     'Enter Your Religion',
                      //     false,
                      //     false, (value) {
                      //   // if (value.isEmpty) {
                      //   //   return 'Enter Religion';
                      //   // } else {
                      //   //   return null;
                      //   // }
                      // }, true),
                      const SizedBox(height: 10),
                      Text(
                        "Community",
                        style: TextStyle(
                          color: black,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedCommunity,
                          icon: Icon(Icons.arrow_drop_down, color: blue),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(Icons.people, color: blue),
                            border: InputBorder.none,
                            hintText: "Select your community",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                          ),
                          isExpanded: true,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedCommunity = newValue;
                              _religionController.text = newValue ?? '';
                            });
                          },
                          items:
                              communities.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                          validator: (value) {
                            return null;
                          },
                        ),
                      ),
                      // Text(
                      //   "Account Type",
                      //   textAlign: TextAlign.start,
                      //   style: TextStyle(
                      //     color: black,
                      //     fontSize: 16,
                      //     fontWeight: FontWeight.w400,
                      //   ),
                      // ),
                      // const SizedBox(height: 5),
                      // radioType(),
                      // const SizedBox(height: 10),
                      // if (isLoadingCategories)
                      //   CircularProgressIndicator(color: white)
                      // else if (categories.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      //     child: DropdownSearch<String>(
                      //       selectedItem:
                      //           _categoryController.text.isEmpty
                      //               ? null
                      //               : _categoryController.text,
                      //       items: (filter, infiniteScrollProps) => categories,
                      //       decoratorProps: DropDownDecoratorProps(
                      //         decoration: InputDecoration(
                      //           labelText: 'Category',
                      //           labelStyle: TextStyle(
                      //             color: Colors.black,
                      //           ), // Changed to black for visibility
                      //           hintText: 'Select your category',
                      //           enabledBorder: OutlineInputBorder(
                      //             borderSide: BorderSide(
                      //               color: Colors.black,
                      //             ), // Changed to black
                      //           ),
                      //           focusedBorder: OutlineInputBorder(
                      //             borderSide: BorderSide(
                      //               color: Colors.black,
                      //             ), // Changed to black
                      //           ),
                      //         ),
                      //       ),
                      //       popupProps: PopupProps.menu(
                      //         showSearchBox: true,
                      //         searchFieldProps: TextFieldProps(
                      //           decoration: InputDecoration(
                      //             hintText: "Search category",
                      //             prefixIcon: Icon(
                      //               Icons.search,
                      //               color: Colors.black,
                      //             ), // Changed to black
                      //             filled: true,
                      //             fillColor:
                      //                 Colors
                      //                     .white, // Set background color to white
                      //           ),
                      //         ),
                      //         menuProps: MenuProps(
                      //           backgroundColor:
                      //               Colors
                      //                   .white, // Set menu background to white
                      //         ),
                      //       ),
                      //       onChanged: (value) {
                      //         setState(() {
                      //           _categoryController.text = value ?? '';
                      //         });
                      //       },
                      //     ),
                      //   ),

                      // if (!nameFocus) radioAccountType(),
                      SizedBox(height: height * 0.03),
                      Center(
                        child: InkWell(
                          onTap: () async {
                            if (_formKey.currentState!.validate()) {
                              buildCPI(context);
                              // try {
                              await AppPreference().setBool(
                                PreferencesKey.infoGathered,
                                true,
                              );
                              String url = 'null';

                              if (file != null) {
                                Reference firebaseStorageRef = FirebaseStorage
                                    .instance
                                    .ref()
                                    .child('Users')
                                    .child(widget.userPhoneNumber ?? "");
                                await firebaseStorageRef.putFile(file!);
                                url =
                                    (await firebaseStorageRef.getDownloadURL())
                                        .toString();
                              }

                              await collectionUserReference
                                  .where(
                                    'mobileNumber',
                                    isEqualTo: widget.userPhoneNumber,
                                  )
                                  .get()
                                  .then((value) {
                                    value.docs[0].reference.update({
                                      'infoGathered': true,
                                      'username': _usernameController.text,
                                      'profilePicture': url,
                                      'type': "Standard",
                                      'bio': _bioController.text,
                                      'uniqueId':
                                          typeSelected == 0
                                              ? ""
                                              : _usernameController.text
                                                      .toLowerCase()
                                                      .replaceAll(" ", "") +
                                                  getRandomInt(3),
                                      'name': _nameController.text,
                                      'age': _ageController.text,
                                      'gender':
                                          genderSelected == 0
                                              ? "Male"
                                              : genderSelected == 1
                                              ? "Female"
                                              : "Other",
                                      'address': _addressController.text,
                                      'emailAddress': _emailController.text,
                                      'religion': _religionController.text,
                                      'followMentors': "",
                                      'likePosts': "",
                                      'savedPosts': "",
                                      'watchLater': "",
                                      'block': "",
                                      'category': _categoryController.text,
                                      'privateAccount': false,
                                      'contactAccount': false,
                                      'recording': [],
                                      'verified': true,
                                      "walletBalance": 0,
                                    });
                                  });

                              FirebaseDatabase.instance
                                  .ref()
                                  .child("UsersList")
                                  .get()
                                  .then((value) async {
                                    final Map<String, dynamic> messageData =
                                        Map<String, dynamic>.from(
                                          value.value as Map,
                                        );
                                    String temp = messageData['usersList'];

                                    temp = "$temp${widget.userPhoneNumber}//";

                                    FirebaseDatabase.instance
                                        .ref()
                                        .child("UsersList")
                                        .update({'usersList': temp});

                                    await collectionUserReference
                                        .where(
                                          'mobileNumber',
                                          isEqualTo: widget.userPhoneNumber,
                                        )
                                        .get()
                                        .then((snapshots) {
                                          if (snapshots.docs.isNotEmpty) {
                                            profileDataModel =
                                                profileDataServices(
                                                  snapshots.docs.first,
                                                );
                                          }

                                          if (profileDataModel?.type ==
                                              "Standard") {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => NavigationBarCustom(
                                                      userPhoneNumber:
                                                          widget
                                                              .userPhoneNumber ??
                                                          "",
                                                    ),
                                              ),
                                            );
                                          }
                                        });
                                  });
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom +
                                  30.0,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(10),
                              ),
                              child: Container(
                                height: height * 0.06,
                                width: size.width * 0.9,
                                color: white,
                                child: const Center(
                                  child: Text(
                                    "Continue",
                                    style: TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Column profileImageWidget(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            _showChoiceDialog(context);
          },
          child:
              (file == null)
                  ? CircleAvatar(
                    backgroundColor: white.withOpacity(0.8),
                    radius: 47.0,
                    child: CircleAvatar(
                      radius: 45.0,
                      backgroundColor: white,
                      child: ClipOval(
                        child: Icon(Icons.photo, color: black, size: 40),
                      ),
                    ),
                  )
                  : CircleAvatar(
                    backgroundColor: white.withOpacity(0.8),
                    radius: 47.0,
                    child: CircleAvatar(
                      radius: 45.0,
                      backgroundColor: white,
                      child: ClipOval(child: Image.file(File(file!.path))),
                    ),
                  ),
        ),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Neue',
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
            children: <TextSpan>[
              TextSpan(
                text: 'Tap to pick an image',
                style: TextStyle(
                  fontFamily: 'Neue',
                  fontSize: 15,
                  color: black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future _showChoiceDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: white,
          title: Text(
            "Choose option",
            style: TextStyle(fontFamily: 'Neue', color: black),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                ListTile(
                  onTap: () {
                    _selectDeviceImage(context);
                  },
                  title: Text(
                    "Gallery",
                    style: TextStyle(fontFamily: 'Neue', color: black),
                  ),
                  leading: Icon(Icons.account_box, color: black),
                ),
                Divider(height: 1, color: black),
                ListTile(
                  onTap: () {
                    _selectCameraImage(context);
                  },
                  title: Text(
                    "Camera",
                    style: TextStyle(fontFamily: 'Neue', color: black),
                  ),
                  leading: Icon(Icons.camera, color: black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectDeviceImage(BuildContext context) async {
    try {
      // ignore: deprecated_member_use
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 50,
          // aspectRatioPresets: [
          //   CropAspectRatioPreset.square,
          // ],
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop the Image',
              toolbarColor: veryDarkBlue,
              toolbarWidgetColor: Colors.white,
              hideBottomControls: true,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              aspectRatioPresets: [CropAspectRatioPreset.square],
            ),
          ],
        );
        var compressedFile = await FlutterImageCompress.compressAndGetFile(
          croppedFile!.path,
          pickedFile.path,
          quality: 50,
        );
        if (compressedFile != null) {
          setState(() {
            file = File(compressedFile.path);
          });
        } else {
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        }
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      }
    } catch (e) {
      flutterShowToast(e.toString());
    }
  }

  void _selectCameraImage(BuildContext context) async {
    try {
      // ignore: deprecated_member_use
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (pickedFile != null) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 50,
          // aspectRatioPresets: [
          //   CropAspectRatioPreset.square,
          // ],
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop the Image',
              toolbarColor: veryDarkBlue,
              toolbarWidgetColor: Colors.white,
              hideBottomControls: true,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true,
            ),
          ],
        );
        var compressedFile = await FlutterImageCompress.compressAndGetFile(
          croppedFile!.path,
          pickedFile.path,
          quality: 50,
        );
        if (compressedFile != null) {
          setState(() {
            file = File(compressedFile.path);
          });
        } else {
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        }
        // ignore: use_build_context_synchronously
        Navigator.pop(context);
      }
    } catch (e) {
      flutterShowToast(e.toString());
    }
  }

  Widget radioType() {
    return Column(
      children: [
        Row(
          children: [
            Radio(
              value: 0,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('Standard', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        Row(
          children: [
            Radio(
              value: 1,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('Mentor', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        Row(
          children: [
            Radio(
              value: 2,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('NGO', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        Row(
          children: [
            Radio(
              value: 3,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('Holy places', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        Row(
          children: [
            Radio(
              value: 4,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('Media', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        Row(
          children: [
            Radio(
              value: 5,
              groupValue: typeSelected,
              activeColor: black,
              fillColor: WidgetStateColor.resolveWith((states) => black),
              onChanged: (value) {
                setState(() {
                  typeSelected = value as int;
                  _categoryController.clear();
                  categories = [];
                });
                fetchCategories(getAccountTypeKey(value!));
              },
            ),
            Text('Business', style: TextStyle(fontSize: 14.0, color: black)),
          ],
        ),
        // Add the note display here
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            getAccountTypeNote(typeSelected),
            style: TextStyle(
              color: black,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // Padding radioAccountType() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 10.0),
  //     child: Row(
  //       children: [
  //         Radio(
  //           value: 0,
  //           groupValue: typeSelected,
  //           activeColor: white,
  //           fillColor: MaterialStateColor.resolveWith((states) => white),
  //           onChanged: (value) {
  //             setState(() {
  //               typeSelected = 2;
  //             });
  //           },
  //         ),
  //         Text(
  //           'Standard',
  //           style: TextStyle(fontSize: 14.0, color: white),
  //         ),
  //         Radio(
  //           value: 1,
  //           groupValue: typeSelected,
  //           activeColor: white,
  //           fillColor: MaterialStateColor.resolveWith((states) => white),
  //           onChanged: (value) {
  //             setState(() {
  //               typeSelected = 3;
  //             });
  //           },
  //         ),
  //         Text(
  //           'Mentor',
  //           style: TextStyle(fontSize: 14.0, color: white),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget radioGenderType() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Radio(
          value: 0,
          groupValue: genderSelected,
          activeColor: black,
          fillColor: WidgetStateColor.resolveWith((states) => black),
          onChanged: (value) {
            setState(() {
              genderSelected = 0;
            });
          },
        ),
        Text('Male', style: TextStyle(fontSize: 14.0, color: black)),
        Radio(
          value: 1,
          groupValue: genderSelected,
          activeColor: black,
          fillColor: WidgetStateColor.resolveWith((states) => black),
          onChanged: (value) {
            setState(() {
              genderSelected = 1;
            });
          },
        ),
        Text('Female', style: TextStyle(fontSize: 14.0, color: black)),
        Radio(
          value: 2,
          groupValue: genderSelected,
          activeColor: black,
          fillColor: WidgetStateColor.resolveWith((states) => black),
          onChanged: (value) {
            setState(() {
              genderSelected = 2;
            });
          },
        ),
        Text('Other', style: TextStyle(fontSize: 14.0, color: black)),
      ],
    );
  }
}
