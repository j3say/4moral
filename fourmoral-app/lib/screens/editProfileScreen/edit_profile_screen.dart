import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/screens/editProfileScreen/edit_profile_controller.dart';
import 'package:fourmoral/screens/editProfileScreen/show_account_type.dart';
import 'package:fourmoral/services/random_key_generator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../../constants/colors.dart';
import '../../models/user_profile_model.dart';
import '../../widgets/circular_progress_indicator.dart';
import '../../widgets/flutter_toast.dart';
import '../navigationBar/navigation_bar.dart';

class EditProfileScreen extends StatefulWidget {
  final String? userPhoneNumber;
  final ProfileModel? profileObject;

  const EditProfileScreen({
    super.key,
    this.userPhoneNumber,
    this.profileObject,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final editProfileCnt = Get.put(EditProfileCnt());
  final _formKeyUsername = GlobalKey<FormState>();
  GoogleMapController? mapController;
  LatLng? selectedLocation;
  final TextEditingController _dateController = TextEditingController();

  String? selectedCommunity;

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

  @override
  void initState() {
    super.initState();
    // Add communityFocusNode to EditProfileCnt
    // editProfileCnt.communityFocusNode = FocusNode().obs;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      editProfileCnt.editProfileDataGet(widget.profileObject);
      if (widget.profileObject?.age != null) {
        _dateController.text = widget.profileObject!.age;
      }
      if (widget.profileObject?.religion != null &&
          widget.profileObject!.religion.isNotEmpty) {
        selectedCommunity = widget.profileObject!.religion;
        // If the stored community is not in our list, add it to the list
        if (!communities.contains(selectedCommunity)) {
          communities.add(selectedCommunity!);
        }
      } else {
        selectedCommunity = communities.first;
      }

      editProfileCnt.religionController.text = selectedCommunity ?? '';
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: blue,
              onPrimary: white,
              onSurface: black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final age = calculateAge(picked);
      setState(() {
        _dateController.text = "$age";
        editProfileCnt.ageController.text = "$age";
      });
    }
  }

  int calculateAge(DateTime birthDate) {
    final currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    final monthDiff = currentDate.month - birthDate.month;
    if (monthDiff < 0 || (monthDiff == 0 && currentDate.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool _isChecking = false;
  String? _status;
  Timer? _debounce;

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

  bool _isValid(String username) {
    final validRegex = RegExp(r'^[a-z0-9._]+$');
    return validRegex.hasMatch(username);
  }

  void _onUsernameInputChanged() {
    final username =
        editProfileCnt.usernameController.text.trim().toLowerCase();

    _debounce?.cancel();

    if (username.isEmpty) {
      setState(() {
        _status = null;
        _isChecking = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Validate username (no spaces, only a-z, 0-9, . _ )
      if (!_isValid(username)) {
        setState(() {
          _status = 'invalid';
          _isChecking = false;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: black),
        ),
        backgroundColor: blue,
      ),
      body: Obx(
        () =>
            editProfileCnt.loading.value
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                  height: height,
                  width: width,
                  child: Form(
                    key: _formKeyUsername,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: FocusScope(
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: height * 0.18,
                              decoration: BoxDecoration(
                                color: blue,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(30),
                                  bottomRight: Radius.circular(30),
                                ),
                              ),
                              child: Center(child: profileImageWidget(height)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 10),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed:
                                          () =>
                                              showAccountTypeSelector(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: blue,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        elevation: 3,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.account_circle,
                                            color: black,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "Change Account Type",
                                            style: TextStyle(
                                              color: black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (editProfileCnt
                                      .selectedType
                                      .value
                                      .isNotEmpty)
                                    Center(
                                      child: Text(
                                        "Select Account Type:- ${editProfileCnt.selectedType.value}",
                                        style: TextStyle(
                                          color: black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  buildInputField(
                                    label: "Username",
                                    icon: Icons.person,
                                    controller:
                                        editProfileCnt.usernameController,
                                    currentFocus:
                                        editProfileCnt.usernameFocusNode,
                                    nextFocus: editProfileCnt.nameFocusNode,
                                    hintText: "Enter your username",
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-z0-9._]'),
                                      ),
                                    ],
                                    suffixIcon: _buildStatusIcon(),
                                    validator: (String? value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Username is required';
                                      }
                                      return null;
                                    },
                                    onChanged: (p0) {
                                      _onUsernameInputChanged();
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  buildInputField(
                                    label: "Name",
                                    icon: Icons.badge,
                                    controller: editProfileCnt.nameController,
                                    currentFocus: editProfileCnt.nameFocusNode,
                                    nextFocus:
                                        editProfileCnt.communityFocusNode,
                                    hintText: "Enter your full name",
                                    validator: (String? value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Name is required';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 16),
                                  buildCommunityDropdown(),
                                  const SizedBox(height: 16),
                                  buildDateField(context),
                                  const SizedBox(height: 16),
                                  buildBioField(),
                                  const SizedBox(height: 16),
                                  buildLocationField(context),
                                  const SizedBox(height: 16),
                                  buildInputField(
                                    label: "Email Address",
                                    icon: Icons.email,
                                    controller: editProfileCnt.emailController,
                                    currentFocus: editProfileCnt.emailFocusNode,
                                    nextFocus: null,
                                    hintText: "Enter your email (optional)",
                                    validator: (String? value) {
                                      if (value != null &&
                                          value.isNotEmpty &&
                                          !value.isEmail) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 30),
                                  Center(
                                    child: buildUpdateButton(
                                      context,
                                      width,
                                      height,
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
                ),
      ),
    );
  }

  Widget profileImageWidget(double height) {
    return Stack(
      children: [
        editProfileCnt.file == null
            ? editProfileCnt.isPhotoUpload.value
                ? const Center(child: CircularProgressIndicator())
                : CircleAvatar(
                  radius: height * 0.07,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: FadeInImage.assetNetwork(
                      imageErrorBuilder:
                          (i, j, k) => const Image(
                            image: AssetImage("assets/profilePlaceholder.png"),
                          ),
                      placeholder: "assets/profilePlaceholder.png",
                      image: widget.profileObject?.profilePicture ?? "",
                      fit: BoxFit.cover,
                      width: height * 0.14,
                      height: height * 0.14,
                    ),
                  ),
                )
            : editProfileCnt.isPhotoUpload.value
            ? const Center(child: CircularProgressIndicator())
            : CircleAvatar(
              radius: height * 0.07,
              backgroundColor: Colors.white,
              child: ClipOval(
                child:
                    (editProfileCnt.file != null &&
                            editProfileCnt.file!.path.isNotEmpty)
                        ? Image.file(
                          File(editProfileCnt.file!.path),
                          fit: BoxFit.cover,
                          width: height * 0.14,
                          height: height * 0.14,
                        )
                        : Icon(
                          Icons.person,
                          size: height * 0.14,
                          color: Colors.grey,
                        ),
              ),
            ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: () {
              editProfileCnt.showChoiceDialog(context);
            },
            child: Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: blue.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: white, width: 2),
              ),
              child: Icon(Icons.camera_alt, color: white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode currentFocus,
    FocusNode? nextFocus,
    required String hintText,
    FormFieldValidator<String>? validator,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters = const [],
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: black.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              // When losing focus, ensure address field is unfocused
              if (currentFocus != editProfileCnt.addressFocusNode) {
                editProfileCnt.addressFocusNode.unfocus();
              }
            }
          },
          child: Container(
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
            child: TextFormField(
              controller: controller,
              focusNode: currentFocus,
              validator: validator,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              onTap: () {
                // Explicitly unfocus address field when tapping other fields
                if (currentFocus != editProfileCnt.addressFocusNode) {
                  editProfileCnt.addressFocusNode.unfocus();
                }
                currentFocus.requestFocus();
              },
              onFieldSubmitted: (value) {
                if (nextFocus != null) {
                  nextFocus.requestFocus();
                } else {
                  currentFocus.unfocus();
                }
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                suffixIcon: suffixIcon,
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(icon, color: blue),
                border: InputBorder.none,
                errorStyle: const TextStyle(height: 0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDateField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Age",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: black.withOpacity(0.7),
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
          child: TextFormField(
            controller: _dateController,
            focusNode: editProfileCnt.ageFocusNode,
            readOnly: true,
            onTap: () => _selectDate(context),
            onFieldSubmitted: (value) {
              FocusScope.of(context).requestFocus(editProfileCnt.bioFocusNode);
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              hintText: "Select your age",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.calendar_today, color: blue),
              suffixIcon: Icon(Icons.arrow_drop_down, color: blue),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bio",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: black.withOpacity(0.7),
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
          child: GestureDetector(
            onTap: () {
              // Request focus when the container is tapped
              FocusScope.of(context).requestFocus(editProfileCnt.bioFocusNode);
            },
            child: TextFormField(
              controller: editProfileCnt.bioController,
              focusNode: editProfileCnt.bioFocusNode,
              maxLines: 5,
              maxLength: 100,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(20),
                hintText: "Write something about yourself",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                counterStyle: TextStyle(color: blue),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLocationField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Address (Optional)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: black.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              // Clear focus when the field loses focus
              editProfileCnt.addressFocusNode.unfocus();
            }
          },
          child: Container(
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
            child: GooglePlaceAutoCompleteTextField(
              textEditingController: editProfileCnt.addressController,
              focusNode: editProfileCnt.addressFocusNode, // Add this line
              googleAPIKey: "AIzaSyCjirUlgby1lfV8BxagtICEBWxlsk1RZlY",
              inputDecoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                hintText: "Enter your address",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.location_on, color: blue),
                border: InputBorder.none,
              ),
              debounceTime: 800,
              countries: ["us", "in"],
              isLatLngRequired: true,
              getPlaceDetailWithLatLng: (Prediction prediction) {
                setState(() {
                  selectedLocation = LatLng(
                    double.parse(prediction.lat!),
                    double.parse(prediction.lng!),
                  );
                });
                _showMapDialog(context);
                editProfileCnt.addressFocusNode.unfocus(); // Add this line
              },
              itemClick: (Prediction prediction) {
                editProfileCnt.addressController.text = prediction.description!;
                editProfileCnt
                    .addressController
                    .selection = TextSelection.fromPosition(
                  TextPosition(offset: prediction.description!.length),
                );
                editProfileCnt.addressFocusNode.unfocus(); // Add this line
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showMapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Confirm Location",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: blue,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      onMapCreated: (controller) {
                        mapController = controller;
                      },
                      initialCameraPosition: CameraPosition(
                        target:
                            selectedLocation ??
                            const LatLng(37.42796133580664, -122.085749655962),
                        zoom: 14,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId("selected"),
                          position:
                              selectedLocation ??
                              const LatLng(
                                37.42796133580664,
                                -122.085749655962,
                              ),
                          draggable: true,
                          onDragEnd: (newPosition) {
                            setState(() {
                              selectedLocation = newPosition;
                            });
                          },
                        ),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text("Confirm", style: TextStyle(color: white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildUpdateButton(BuildContext context, double width, double height) {
    return ElevatedButton(
      onPressed: () async {
        if (_formKeyUsername.currentState!.validate()) {
          if (editProfileCnt.selectedType.value != "") {
            if (editProfileCnt.selectedType.value != "Standard" &&
                editProfileCnt.categoryController.text.isEmpty) {
              flutterShowToast('Please select a category');
              return;
            }
          }

          if (editProfileCnt.usernameController.value.text !=
                  widget.profileObject?.username ||
              editProfileCnt.bioController.value.text !=
                  widget.profileObject?.bio ||
              editProfileCnt.nameController.value.text !=
                  widget.profileObject?.name ||
              editProfileCnt.ageController.value.text !=
                  widget.profileObject?.age ||
              editProfileCnt.addressController.value.text !=
                  widget.profileObject?.address ||
              editProfileCnt.emailController.value.text !=
                  widget.profileObject?.emailAddress ||
              editProfileCnt.religionController.value.text !=
                  widget.profileObject?.religion ||
              editProfileCnt.file != null ||
              editProfileCnt.selectedType.value != "" ||
              editProfileCnt.categoryController.text.isNotEmpty) {
            buildCPI(context);
            try {
              String url = widget.profileObject?.profilePicture ?? "";

              if (editProfileCnt.file != null) {
                Reference firebaseStorageRef = FirebaseStorage.instance
                    .ref()
                    .child('Users')
                    .child(widget.userPhoneNumber ?? "");
                await firebaseStorageRef.putFile(editProfileCnt.file!);
                url = (await firebaseStorageRef.getDownloadURL()).toString();
              }

              editProfileCnt.collectionUserReference
                  .where('mobileNumber', isEqualTo: widget.userPhoneNumber)
                  .get()
                  .then((value) {
                    value.docs[0].reference.update({
                      'infoGathered': true,
                      'type':
                          editProfileCnt.selectedType.value == ""
                              ? widget.profileObject?.type
                              : editProfileCnt.selectedType.value,
                      'uniqueId':
                          editProfileCnt.selectedType.value == "Standard"
                              ? ""
                              : editProfileCnt.usernameController.text
                                      .toLowerCase()
                                      .replaceAll(" ", "") +
                                  getRandomInt(3),
                      'category': editProfileCnt.categoryController.text,
                      'username': editProfileCnt.usernameController.value.text,
                      'profilePicture': url,
                      'name': editProfileCnt.nameController.value.text,
                      'bio': editProfileCnt.bioController.value.text,
                      'age': editProfileCnt.ageController.value.text,
                      'address': editProfileCnt.addressController.value.text,
                      'emailAddress': editProfileCnt.emailController.value.text,
                      'verified':
                          editProfileCnt.selectedType.value == "Standard"
                              ? true
                              : false,
                      'religion': editProfileCnt.religionController.value.text,
                    });
                    editProfileCnt.homeCnt.profileDataFetched.value = false;
                    Get.offAll(
                      () => NavigationBarCustom(
                        userPhoneNumber: widget.userPhoneNumber ?? "",
                        indexSent: 0,
                      ),
                    );

                    flutterShowToast("Profile Updated Successfully");
                  });
            } catch (e) {
              flutterShowToast(e.toString());
              Navigator.pop(context);
            }
          } else {
            flutterShowToast("No changes to update");
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: blue,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: black),
          const SizedBox(width: 8),
          Text(
            "UPDATE PROFILE",
            style: TextStyle(
              color: black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCommunityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Community",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: black.withOpacity(0.7),
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
                editProfileCnt.religionController.text = newValue ?? '';
              });
            },
            items:
                communities.map<DropdownMenuItem<String>>((String value) {
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
      ],
    );
  }

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
}
