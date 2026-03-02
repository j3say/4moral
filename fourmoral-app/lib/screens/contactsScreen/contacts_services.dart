import 'dart:developer';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:fourmoral/models/contacts_model.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:fourmoral/screens/profileScreen/profile_controller.dart';
import 'package:fourmoral/widgets/flutter_toast.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactsScreenCnt extends GetxController {
  RxBool contactsDataFetched = false.obs;
  RxList<ContactsModel> contactsDataList = <ContactsModel>[].obs;
  RxString errorMessage = ''.obs;
  RxBool hasError = false.obs;
  RxInt progressCount = 0.obs;
  RxInt totalContacts = 0.obs;
  RxInt validContactsCount = 0.obs;
  RxBool isLoadingNewContacts = false.obs;
  final selectedContacts = <ContactsModel>[].obs;
  final int batchSize = 20;
  final _storage = GetStorage();
  final _contactsLastUpdatedKey = 'contacts_last_updated';
  final _cachedContactsKey = 'cached_contacts';
  final _contactsHashKey = 'contacts_hash';
  final CollectionReference selectedContactsCollection = FirebaseFirestore
      .instance
      .collection('SelectedContacts');

  Future<void> getDeviceContacts({bool forceRefresh = false}) async {
    try {
      // Load cached contacts if not forcing refresh
      if (!forceRefresh && _loadCachedContacts()) {
        contactsDataFetched.value = true;
        validContactsCount.value = contactsDataList.length;
        updateProfileCnt();
        return;
      }

      // Reset states
      contactsDataList.clear();
      validContactsCount.value = 0;
      contactsDataFetched.value = false;
      errorMessage.value = '';
      hasError.value = false;
      progressCount.value = 0;
      isLoadingNewContacts.value = true;

      // Check contacts permission
      final permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        errorMessage.value = 'Contacts permission denied';
        contactsDataFetched.value = true;
        hasError.value = true;
        isLoadingNewContacts.value = false;
        return;
      }

      // Get device contacts
      List<Contact> deviceContacts;
      try {
        deviceContacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
      } catch (e) {
        errorMessage.value = 'Failed to read device contacts';
        contactsDataFetched.value = true;
        hasError.value = true;
        isLoadingNewContacts.value = false;
        return;
      }

      totalContacts.value = deviceContacts.length;

      // Check if contacts have changed
      final lastUpdate = _storage.read(_contactsLastUpdatedKey) ?? 0;
      final currentUpdate = DateTime.now().millisecondsSinceEpoch;
      final contactsChanged = await _checkContactsChanged(
        deviceContacts,
        lastUpdate,
      );

      if (!forceRefresh && !contactsChanged) {
        contactsDataFetched.value = true;
        isLoadingNewContacts.value = false;
        return;
      }

      // Process valid contacts
      final validContacts = _preProcessContacts(deviceContacts);
      if (validContacts.isEmpty) {
        contactsDataFetched.value = true;
        isLoadingNewContacts.value = false;
        validContactsCount.value = 0;
        updateProfileCnt();
        return;
      }

      await _processContactsInBatches(validContacts);

      // Save to cache
      _saveContactsToCache();
      _storage.write(_contactsLastUpdatedKey, currentUpdate);

      contactsDataFetched.value = true;
      isLoadingNewContacts.value = false;
      updateProfileCnt();
    } catch (e) {
      log("Error in getDeviceContacts: $e");
      errorMessage.value = 'Failed to load contacts';
      hasError.value = true;
      contactsDataFetched.value = true;
      isLoadingNewContacts.value = false;
    }
  }

  Future<void> initializeSelection(
    List<ContactsModel> selectedContacts,
    ProfileModel? profileDataObject,
  ) async {
    // Fetch previously selected contacts from Firestore
    final selectedContactsFromFirestore = await getSelectedContacts(
      profileDataObject,
    );
    final selectedMobileNumbers =
        selectedContactsFromFirestore
            .map((contact) => contact['receiverPhoneNumber'] as String)
            .toList();

    final allSelectedMobileNumbers =
        {
          ...selectedMobileNumbers,
          ...selectedContacts.map((e) => e.mobileNumber),
        }.toList();

    for (var i = 0; i < contactsDataList.length; i++) {
      final contact = contactsDataList[i];
      contactsDataList[i] = contact.copyWith(
        isSelected: allSelectedMobileNumbers.contains(contact.mobileNumber),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSelectedContacts(
    ProfileModel? profileDataObject,
  ) async {
    try {
      final userPhoneNumber = profileDataObject?.mobileNumber ?? '';
      if (userPhoneNumber.isEmpty) {
        flutterShowToast("User phone number not found");
        return [];
      }

      final snapshot =
          await selectedContactsCollection
              .doc(userPhoneNumber)
              .collection('Data')
              .orderBy('timestamp', descending: true)
              .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      developer.log('Error fetching selected contacts: $e');
      flutterShowToast("Error fetching selected contacts");
      return [];
    }
  }

  bool _loadCachedContacts() {
    try {
      final cachedContacts = _storage.read<List>(_cachedContactsKey);
      if (cachedContacts != null) {
        contactsDataList.assignAll(
          cachedContacts.map((e) => ContactsModel.fromJson(e)).toList(),
        );
        validContactsCount.value = contactsDataList.length;
        return true;
      }
      return false;
    } catch (e) {
      log("Error loading cached contacts: $e");
      return false;
    }
  }

  void _saveContactsToCache() {
    try {
      _storage.remove(_cachedContactsKey); // Clear old cache
      _storage.write(
        _cachedContactsKey,
        contactsDataList.map((e) => e.toJson()).toList(),
      );
    } catch (e) {
      log("Error saving contacts to cache: $e");
    }
  }

  Future<bool> _checkContactsChanged(
    List<Contact> currentContacts,
    int lastUpdateTime,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastUpdateTime > Duration(hours: 24).inMilliseconds) {
        return true;
      }

      // Compute hash of current contacts
      final currentHash =
          currentContacts
              .map(
                (c) =>
                    '${c.displayName}:${c.phones.map((p) => p.number).join(",")}',
              )
              .join('|')
              .hashCode;

      final cachedHash = _storage.read<int>(_contactsHashKey) ?? 0;
      if (currentHash != cachedHash) {
        _storage.write(_contactsHashKey, currentHash);
        return true;
      }

      return false;
    } catch (e) {
      log("Error checking contact changes: $e");
      return true;
    }
  }

  List<Map<String, dynamic>> _preProcessContacts(List<Contact> contacts) {
    final validContacts = <Map<String, dynamic>>[];
    final processedPhones = <String>{};

    for (final contact in contacts) {
      try {
        if (contact.displayName.isEmpty || contact.phones.isEmpty) continue;
        final phoneNumbers =
            contact.phones
                .where((p) => p.number.isNotEmpty)
                .map((p) => _normalizePhoneForFirebase(p.number))
                .where((p) => p.isNotEmpty && !processedPhones.contains(p))
                .toList();

        if (phoneNumbers.isEmpty) continue;

        processedPhones.addAll(phoneNumbers);
        validContacts.add({
          'name': contact.displayName,
          'phones': phoneNumbers,
        });
      } catch (e) {
        log("Error preprocessing contact: $e");
      }
    }
    return validContacts;
  }

  Future<void> _processContactsInBatches(
    List<Map<String, dynamic>> contacts,
  ) async {
    final totalBatches = (contacts.length / batchSize).ceil();
    for (var i = 0; i < totalBatches; i++) {
      final start = i * batchSize;
      final end = (i + 1) * batchSize;
      final batch = contacts.sublist(
        start,
        end > contacts.length ? contacts.length : end,
      );
      await _processBatch(batch);
      progressCount.value = end > contacts.length ? contacts.length : end;
      await Future.delayed(Duration(milliseconds: 10));
    }
  }

  Future<void> _processBatch(List<Map<String, dynamic>> batch) async {
    final firestore = FirebaseFirestore.instance;
    final processedPhones = <String>{};
    final validResults = <ContactsModel>[];

    final batchResults = await Future.wait(
      batch.map((contact) async {
        try {
          for (final phone in contact['phones']) {
            if (processedPhones.contains(phone)) continue;
            processedPhones.add(phone);

            final querySnapshot =
                await firestore
                    .collection('Users')
                    .where('mobileNumber', isEqualTo: phone)
                    .limit(1)
                    .get();
            if (querySnapshot.docs.isNotEmpty) {
              final userDoc = querySnapshot.docs.first;
              final userData = userDoc.data();
              return ContactsModel(
                userData['name']?.toString() ?? contact['name'],
                contact['name'],
                userData['profilePicture']?.toString() ?? "",
                phone,
                userDoc.id,
              );
            }
          }
          return null;
        } catch (e) {
          log("Error processing contact: $e");
          return null;
        }
      }),
    );

    validResults.addAll(batchResults.whereType<ContactsModel>());

    // Add only unique contacts
    for (var result in validResults) {
      if (!contactsDataList.any(
        (existing) => existing.uniqueId == result.uniqueId,
      )) {
        contactsDataList.add(result);
      }
    }
    validContactsCount.value = contactsDataList.length;
  }

  void updateProfileCnt() {
    try {
      final profileCnt = Get.find<ProfileController>();
      profileCnt.contactsCount.value = validContactsCount.value;
    } catch (e) {
      log("Error updating profile controller: $e");
    }
  }

  Future<void> refreshContacts() async {
    await getDeviceContacts(forceRefresh: true);
  }

  String _normalizePhoneForFirebase(String phone) {
    try {
      if (phone.isEmpty) return '';
      phone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (phone.startsWith('91') && phone.length > 10) {
        return '+$phone';
      } else if (phone.length == 10) {
        return '+91$phone';
      } else if (phone.startsWith('0') && phone.length > 10) {
        return '+91${phone.substring(1)}';
      } else if (phone.startsWith('+91') && phone.length > 3) {
        return phone;
      } else {
        if (phone.length >= 10 && !phone.startsWith('+')) {
          return '+$phone';
        }
        return phone.startsWith('+') ? phone : '';
      }
    } catch (e) {
      log("Error normalizing phone number: $e");
      return '';
    }
  }

  @override
  void onInit() {
    super.onInit();
    getDeviceContacts();
  }
}
