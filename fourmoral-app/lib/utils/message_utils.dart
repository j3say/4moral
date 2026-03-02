import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:encrypt/encrypt.dart' as basic show RSAKeyParser;
import 'package:pointycastle/pointycastle.dart' as crypto;

class MessageUtils {
  /// Decrypts a Base64 RSA-encrypted message using a PEM private key
  static Future<String> decryptMessage(
    String encryptedText,
    String privateKeyStr,
  ) async {
    final parser = basic.RSAKeyParser();
    final privateKey = parser.parse(privateKeyStr) as crypto.RSAPrivateKey;
    final encrypter = encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
    return encrypter.decrypt64(encryptedText);
  }

  /// Encrypts plain text using the recipient's RSA public key (PEM format)
  static Future<String> encryptMessage(String text, String publicKeyStr) async {
    final parser = basic.RSAKeyParser();
    final publicKey = parser.parse(publicKeyStr) as crypto.RSAPublicKey;
    final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));
    return encrypter.encrypt(text).base64;
  }

  /// Checks if a string is valid Base64
  static bool isBase64(String str) {
    if (str.isEmpty || str.length % 4 != 0) return false;
    final base64RegExp = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    return base64RegExp.hasMatch(str);
  }

  /// Safely converts an untyped dynamic map to Map<String, dynamic>
  static Map<String, dynamic> convertToTypedMap(dynamic untypedMap) {
    if (untypedMap is! Map) return {};
    return Map<String, dynamic>.from(untypedMap);
  }

  /// Extracts a filename from a Firebase Storage URL
  static String getFileName(String url) {
    RegExp regExp = RegExp(r'.+(\/|%2F)(.+)\?.+');
    var matches = regExp.allMatches(url);
    if (matches.isEmpty) return url;
    var match = matches.first;
    return Uri.decodeFull(match.group(2)!);
  }
}
