import 'dart:convert';
import 'dart:developer';

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fourmoral/models/message.dart';

class FreebaseEncryptionService {
  static final _iv = encrypt.IV.fromUtf8('1234567890123456');

  static Future<String> processMessageContent({
    required MessageType type,
    required String content,
    required String? keyBase64,
    required bool encrypt,
  }) async {
    if (type != MessageType.text || keyBase64 == null) return content;

    try {
      return encrypt
          ? await _encryptText(content, keyBase64)
          : await _decryptText(content, keyBase64);
    } catch (e) {
      log('Encryption/decryption error: $e');
      return content; // Return original content if encryption fails
    }
  }

  static bool _isBase64(String str) {
    try {
      return RegExp(r'^[a-zA-Z0-9+/]+={0,2}$').hasMatch(str) &&
          str.length % 4 == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _encryptText(String text, String keyBase64) async {
    try {
      final key = encrypt.Key.fromBase64(keyBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      // Ensure text is UTF8 encoded
      final encrypted = encrypter.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Encryption failed: ${e.toString()}');
    }
  }

  static Future<String> _decryptText(String encrypted, String keyBase64) async {
    try {
      // Validate input
      if (encrypted.isEmpty) throw Exception('Empty encrypted message');
      if (keyBase64.isEmpty) throw Exception('Empty encryption key');

      // Check if the message looks like it's encrypted
      if (!_isBase64(encrypted)) {
        log('Message does not appear to be encrypted');
        return encrypted;
      }

      final key = encrypt.Key.fromBase64(keyBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      final encryptedData = encrypt.Encrypted.fromBase64(encrypted);
      return encrypter.decrypt(encryptedData, iv: _iv);
    } on FormatException catch (e) {
      log('FormatException during decryption: $e');
      throw Exception('Invalid message format');
    } on ArgumentError catch (e) {
      log('ArgumentError during decryption: $e');
      throw Exception('Invalid encryption parameters');
    } catch (e) {
      log('Unexpected decryption error: $e');
      throw Exception('Decryption failed: ${e.toString()}');
    }
  }

  static Future<String> getOrCreateGroupKey(String groupId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .get();

    if (doc.exists && doc.data()?['encryptionKey'] != null) {
      return doc.data()!['encryptionKey'] as String;
    }

    // Create new key
    final newKey = encrypt.Key.fromSecureRandom(32).base64;

    await FirebaseFirestore.instance.collection('groups').doc(groupId).set({
      'encryptionKey': newKey,
      'keyCreatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return newKey;
  }

  static Future<Uint8List> encryptFile(
    Uint8List fileBytes,
    String keyBase64,
  ) async {
    try {
      final key = encrypt.Key.fromBase64(keyBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      // Convert file bytes to base64 for encryption
      final fileBase64 = base64Encode(fileBytes);
      final encrypted = encrypter.encrypt(fileBase64, iv: _iv);

      // Return encrypted bytes
      return base64Decode(encrypted.base64);
    } catch (e) {
      throw Exception('File encryption failed: ${e.toString()}');
    }
  }

  static Future<Uint8List> decryptFile(
    Uint8List encryptedBytes,
    String keyBase64,
  ) async {
    try {
      final key = encrypt.Key.fromBase64(keyBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      // Convert encrypted bytes to base64 for decryption
      final encryptedBase64 = base64Encode(encryptedBytes);
      final encrypted = encrypt.Encrypted.fromBase64(encryptedBase64);
      final decryptedBase64 = encrypter.decrypt(encrypted, iv: _iv);

      // Return decrypted bytes
      return base64Decode(decryptedBase64);
    } catch (e) {
      throw Exception('File decryption failed: ${e.toString()}');
    }
  }
}
