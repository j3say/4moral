import 'dart:async';

// --- FAKE FIREBASE AUTH ---
class FirebaseAuth {
  static final instance = FirebaseAuth();
  User? get currentUser => User();
  Future<void> verifyPhoneNumber({
    required dynamic verificationCompleted,
    required dynamic verificationFailed,
    required dynamic codeSent,
    required dynamic codeAutoRetrievalTimeout,
  }) async {}
}

// Fixed: Renamed to User to fix "'User' isn't a type" error
class User { 
  String get uid => "65f0a1b2c3d4e5f6a7b8c9d0";
  String get phoneNumber => "+911234567890";
  String get displayName => "Test User"; // Fixed: Added displayName
}

// --- FAKE FIRESTORE CORE ---
class FirebaseFirestore {
  static final instance = FirebaseFirestore();
  CollectionReference collection(String path) => CollectionReference();
  MockBatch batch() => MockBatch();
}

class MockBatch {
  // Fixed: Added optional SetOptions to fix "Too many positional arguments"
  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) {}
  void update(DocumentReference ref, Map<String, dynamic> data) {}
  void delete(DocumentReference ref) {}
  Future<void> commit() async {}
}

class CollectionReference {
  CollectionReference where(dynamic field,
          {dynamic isEqualTo,
          dynamic isGreaterThan,
          dynamic isGreaterThanOrEqualTo,
          dynamic isLessThan,
          dynamic isLessThanOrEqualTo,
          dynamic whereIn}) =>
      this;
  CollectionReference limit(int count) => this;
  CollectionReference orderBy(String field, {bool descending = false}) => this;
  
  // Fixed: Added startAt and endAt
  CollectionReference startAt(List<dynamic> values) => this;
  CollectionReference endAt(List<dynamic> values) => this;
  
  Future<QuerySnapshot> get() async => QuerySnapshot();
  Stream<QuerySnapshot> snapshots() => const Stream.empty();
  DocumentReference doc([String? path]) => DocumentReference();
  Future<DocumentReference> add(Map<String, dynamic> data) async => DocumentReference();
}

class DocumentReference {
  String get id => "fake_id_123";
  Future<void> update(Map<String, dynamic> data) async {}
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
  Future<DocumentSnapshot> get() async => DocumentSnapshot();
  Future<void> delete() async {}
  CollectionReference collection(String path) => CollectionReference();
  CollectionReference child(String path) => CollectionReference();
}

class QuerySnapshot {
  List<QueryDocumentSnapshot> get docs => [];
}

class DocumentSnapshot {
  String get id => "test_doc_id";
  
  // Fixed: Made return type non-nullable Map to fix operator '[]' errors
  Map<String, dynamic> data() => {}; 
  
  // Fixed: Added get() method
  dynamic get(dynamic field) => ""; 
  
  dynamic operator [](String key) => "";
  bool get exists => false;
  DocumentReference get reference => DocumentReference();
}

// Fixed: Added missing class
class QueryDocumentSnapshot extends DocumentSnapshot {
  @override
  Map<String, dynamic> data() => {};
}

// --- FAKE FIELD VALUES & OPTIONS ---
class FieldValue {
  static dynamic serverTimestamp() => DateTime.now().toIso8601String();
  static dynamic arrayUnion(List elements) => elements;
  static dynamic arrayRemove(List elements) => elements;
  static dynamic increment(num value) => value;
  static dynamic delete() => null;
}

class FieldPath {
  static const documentId = "id";
}

class SetOptions {
  final bool merge;
  SetOptions({required this.merge});
}

class Timestamp {
  static Timestamp now() => Timestamp();
  DateTime toDate() => DateTime.now();
  static Timestamp fromDate(DateTime date) => Timestamp();
}