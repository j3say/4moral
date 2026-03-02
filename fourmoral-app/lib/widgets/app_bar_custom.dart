import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/contactsScreen/contacts_services.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/screens/savedPostScreen/saved_post_screen.dart';
import 'package:fourmoral/screens/walletScreen/wallet_screen.dart';
import 'package:fourmoral/services/preferences/preference_manager.dart';
import 'package:fourmoral/services/preferences/preferences_key.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/blockedUsersScreen/blocked_users.dart';
import '../screens/editProfileScreen/edit_profile_screen.dart';
import '../screens/likedPostScreen/liked_post_screen.dart';
import '../screens/watchLaterScreen/watch_later_screen.dart';
import '../services/log_in_services.dart';
import 'confirm_dialogue_box.dart';
import 'flutter_toast.dart';

AppBar appBarCustomProfileScreen(
  text,
  context,
  profileDataObject,
  userPhoneNumber,
  height,
) {
  final String privacyPolicyUrl =
      'https://www.termsfeed.com/live/fe6f98dc-e0f3-4d00-b77a-c380400c5b7e';

  // Initialize controllers
  final profileController = Get.put(ProfileController());
  // profileController.initialize(profileDataObject, userPhoneNumber);

  Future<void> launchPrivacyPolicy() async {
    final Uri url = Uri.parse(privacyPolicyUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      flutterShowToast('Could not launch $privacyPolicyUrl');
    }
  }

  return AppBar(
    title: Text('$text'),
    backgroundColor: blue,
    actions: [
      IconButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            isDismissible: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (BuildContext context) {
              return DraggableScrollableSheet(
                maxChildSize: 0.9,
                initialChildSize: 0.5,
                minChildSize: 0.3,
                expand: false,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: PrivateAndPublicChange(
                            userPhoneNumber: userPhoneNumber,
                            profileDataObject: profileDataObject,
                          ),
                        ),
                        Expanded(
                          child: Obx(() {
                            final isContactPrivate =
                                profileController.contactAccount.value;
                            final options = [
                              {
                                'title': 'Scan to Share',
                                'icon': Icons.qr_code,
                                'onTap': () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.0,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Share Your Profile",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 10),
                                              QrImageView(
                                                data:
                                                    profileDataObject
                                                        .mobileNumber,
                                                version:
                                                    QrVersions.isSupportedVersion(
                                                          5,
                                                        )
                                                        ? 5
                                                        : QrVersions.auto,
                                                size: 300.0,
                                                eyeStyle: QrEyeStyle(
                                                  eyeShape: QrEyeShape.square,
                                                  color: Colors.blue,
                                                ),
                                                dataModuleStyle:
                                                    QrDataModuleStyle(
                                                      dataModuleShape:
                                                          QrDataModuleShape
                                                              .square,
                                                      color: Colors.black,
                                                    ),
                                                embeddedImage: AssetImage(
                                                  'assets/logo.png',
                                                ),
                                                embeddedImageStyle:
                                                    QrEmbeddedImageStyle(
                                                      size: Size(60, 60),
                                                    ),
                                              ),
                                              SizedBox(height: 20),
                                              ElevatedButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: Text("Close"),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              },
                              {
                                'title': 'Edit Profile',
                                'icon': Icons.edit,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => EditProfileScreen(
                                            profileObject: profileDataObject,
                                            userPhoneNumber: userPhoneNumber,
                                          ),
                                    ),
                                  );
                                },
                              },
                              {
                                'title': 'Liked Post',
                                'icon': MdiIcons.heart,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => LikedPostScreen(
                                            profileModel: profileDataObject,
                                          ),
                                    ),
                                  );
                                },
                              },
                              {
                                'title': 'Saved Post',
                                'icon': Icons.book,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => SavedPostScreen(
                                            profileModel: profileDataObject,
                                          ),
                                    ),
                                  );
                                },
                              },
                              {
                                'title': 'Watch Later',
                                'icon': Icons.book,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => WatchLaterScreen(
                                            profileModel: profileDataObject,
                                          ),
                                    ),
                                  );
                                },
                              },
                              {
                                'title': 'Blocked Users',
                                'icon': Icons.block,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const BlockedUsersScreen(),
                                    ),
                                  );
                                },
                              },
                              {
                                'title': 'Wallet',
                                'icon': Icons.wallet,
                                'onTap': () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WalletScreen(),
                                    ),
                                  );
                                },
                              },
                              // if (isContactPrivate)
                              //   {
                              //     'title': 'Select Contacts',
                              //     'icon': Icons.contacts,
                              //     'onTap': () {
                              //       showDialog(
                              //         context: context,
                              //         builder: (BuildContext context) {
                              //           return ContactSelectionDialog(
                              //             userPhoneNumber: userPhoneNumber,
                              //           );
                              //         },
                              //       );
                              //     },
                              //   },
                              {
                                'title': 'Privacy Policy',
                                'icon': Icons.policy_rounded,
                                'onTap': launchPrivacyPolicy,
                              },
                              {
                                'title': 'Contact',
                                'icon': Icons.contact_mail,
                                'onTap': () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return SelectedContactsDialog();
                                    },
                                  );
                                },
                              },
                              {
                                'title': 'Log Out',
                                'icon': Icons.logout,
                                'onTap': () {
                                  confirmDialogue(
                                    context,
                                    "Go Back",
                                    "Do you really want to go to the Log In Page?",
                                    () async {
                                      await AuthService().signOut(context);
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
                                      flutterShowToast(
                                        'Signed Out Successfully',
                                      );
                                    },
                                    () {
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              },
                              {
                                'title': 'Delete Account',
                                'icon': Icons.delete_forever_rounded,
                                'onTap': () {
                                  confirmDialogue(
                                    context,
                                    "Go Back",
                                    "Do you really want to Delete Account?",
                                    () async {
                                      await AuthService().signOut(context);
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
                                      flutterShowToast(
                                        'Delete Account Successfully',
                                      );
                                    },
                                    () {
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              },
                            ];

                            return GridView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio:
                                        MediaQuery.of(context).size.width > 400
                                            ? 3.5
                                            : 2.8,
                                  ),
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                return _buildOptionCard(
                                  context,
                                  options[index]['title'] as String,
                                  options[index]['icon'] as IconData,
                                  options[index]['onTap'] as Function(),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}

Widget _buildOptionCard(
  BuildContext context,
  String title,
  IconData icon,
  Function() onTap,
) {
  return StatefulBuilder(
    builder: (context, setState) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            onTap.call();
            setState;
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PrivateAndPublicChange extends StatelessWidget {
  final String? userPhoneNumber;
  final ProfileModel? profileDataObject;

  const PrivateAndPublicChange({
    super.key,
    this.userPhoneNumber,
    this.profileDataObject,
  });

  @override
  Widget build(BuildContext context) {
    final profileController = Get.find<ProfileController>();

    return Obx(() {
      final isLoadingPrivate = profileController.isLoadingPrivate.value;
      final isLoadingContact = profileController.isLoadingContact.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (profileDataObject?.type.toLowerCase() != 'standard')
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          isLoadingPrivate
                              ? null
                              : () => profileController.togglePrivateAccount(
                                !profileController.privateAccount.value,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            profileController.privateAccount.value
                                ? Colors.redAccent
                                : Colors.green,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoadingPrivate)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          if (!isLoadingPrivate)
                            Text(
                              profileController.privateAccount.value
                                  ? 'Switch to Public'
                                  : 'Switch to Private',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (profileDataObject?.type.toLowerCase() != 'standard')
                  SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        isLoadingContact
                            ? null
                            : () => profileController.toggleContactAccount(
                              !profileController.contactAccount.value,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          profileController.contactAccount.value
                              ? Colors.blue
                              : Colors.lightGreen,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLoadingContact)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        if (!isLoadingContact)
                          Text(
                            profileController.contactAccount.value
                                ? 'Contact Private'
                                : 'Contact Public',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: black, height: 2),
        ],
      );
    });
  }
}

// class ContactSelectionDialog extends StatelessWidget {
//   final String? userPhoneNumber;

//   const ContactSelectionDialog({super.key, this.userPhoneNumber});

//   @override
//   Widget build(BuildContext context) {
//     final contactsController = Get.find<ContactsScreenCnt>();
//     final profileController = Get.find<ProfileController>();

//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
//       child: Obx(
//         () => Container(
//           padding: EdgeInsets.all(16.0),
//           constraints: BoxConstraints(
//             maxHeight: MediaQuery.of(context).size.height * 0.6,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 "Select Contacts",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               SizedBox(height: 10),
//               if (contactsController.isLoadingNewContacts.value)
//                 Center(child: CircularProgressIndicator()),
//               if (contactsController.hasError.value)
//                 Text(contactsController.errorMessage.value),
//               if (contactsController.contactsDataFetched.value &&
//                   !contactsController.isLoadingNewContacts.value &&
//                   !contactsController.hasError.value)
//                 Expanded(
//                   child: ListView.builder(
//                     shrinkWrap: true,
//                     itemCount: contactsController.contactsDataList.length,
//                     itemBuilder: (context, index) {
//                       final contact =
//                           contactsController.contactsDataList[index];
//                       return ListTile(
//                         leading: CircleAvatar(
//                           backgroundImage:
//                               contact.profilePicture.isNotEmpty
//                                   ? NetworkImage(contact.profilePicture)
//                                   : null,
//                           child:
//                               contact.profilePicture.isEmpty
//                                   ? Text(contact.name[0])
//                                   : null,
//                         ),
//                         title: Text(contact.name),
//                         subtitle: Text(contact.mobileNumber),
//                         trailing: Checkbox(
//                           value: contact.isSelected,
//                           onChanged: (value) {
//                             contactsController.contactsDataList[index] = contact
//                                 .copyWith(isSelected: value ?? false);
//                           },
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               SizedBox(height: 20),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.pop(context),
//                     child: Text("Cancel"),
//                   ),
//                   Obx(
//                     () => ElevatedButton(
//                       onPressed:
//                           profileController.isSaving.value
//                               ? null
//                               : () {
//                                 final selectedContacts =
//                                     contactsController.contactsDataList
//                                         .where((contact) => contact.isSelected)
//                                         .toList();
//                                 if (selectedContacts.isEmpty) {
//                                   flutterShowToast(
//                                     "Please select at least one contact",
//                                   );
//                                   return;
//                                 }
//                                 profileController.saveSelectedContacts(
//                                   selectedContacts,
//                                 );
//                                 Navigator.pop(context);
//                               },
//                       child:
//                           profileController.isSaving.value
//                               ? SizedBox(
//                                 width: 20,
//                                 height: 20,
//                                 child: CircularProgressIndicator(
//                                   strokeWidth: 2,
//                                   color: Colors.white,
//                                 ),
//                               )
//                               : Text("Save"),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

class SelectedContactsDialog extends StatelessWidget {
  const SelectedContactsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final contactsScreenCnt = Get.find<ContactsScreenCnt>();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Container(
        padding: EdgeInsets.all(16.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Selected Contacts",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: contactsScreenCnt.getSelectedContacts(profileDataModel),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text("Error loading contacts");
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text("No contacts selected");
                }

                final contacts = snapshot.data!;
                return Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(contact['receiverName'][0]),
                        ),
                        title: Text(contact['receiverName']),
                        subtitle: Text(contact['receiverPhoneNumber']),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

SizedBox sheetOptions(text, last, onTap, icon, height) {
  return SizedBox(
    height: height * 0.063,
    child: Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 10.0,
            ),
            child: Row(
              children: [
                Icon(icon, color: blue),
                const SizedBox(width: 30),
                Text(
                  '$text',
                  textAlign: TextAlign.start,
                  style: TextStyle(color: black, fontSize: 18.0),
                ),
              ],
            ),
          ),
        ),
        last ? const SizedBox() : Divider(color: black, height: 2),
      ],
    ),
  );
}
