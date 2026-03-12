import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
  static String hashPassword(String password) {
    var bytes = utf8.encode(password); // data being hashed
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}
