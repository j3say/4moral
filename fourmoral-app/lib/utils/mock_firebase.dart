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

class FirebaseDatabase {
  static final instance = FirebaseDatabase();
  DatabaseReference ref([String? path]) => DatabaseReference(); 
}

class DatabaseReference {
  DatabaseReference child(String path) => this;
  
  // 🚀 FIXED: Added the missing properties the compiler is crying about
  String get key => "fake_key_123";
  DatabaseReference get ref => this;
  
  DatabaseReference push() => this;
  DatabaseReference orderByChild(String path) => this;
  DatabaseReference orderByKey() => this;
  DatabaseReference limitToLast(int count) => this;
  DatabaseReference limitToFirst(int count) => this; // 🚀 FIXED: Added limitToFirst
  
  Future<DataSnapshot> get() async => DataSnapshot();
  Future<DatabaseEvent> once() async => DatabaseEvent();
  Future<void> update(Map<String, dynamic> data) async {} 
  Future<void> set(dynamic data) async {} 
  
  Stream<DatabaseEvent> get onValue => const Stream.empty();
}

class DataSnapshot {
  dynamic get value => null;
  bool get exists => false; // Fixed: Added exists check
}

class DatabaseEvent {
  DataSnapshot get snapshot => DataSnapshot();
}

// Fixed: Added ServerValue for EditPostController
class ServerValue {
  static const Map<String, String> timestamp = {'.sv': 'timestamp'};
}


// --- FAKE FIREBASE STORAGE ---
class FirebaseStorage {
  static final instance = FirebaseStorage();
  static FirebaseStorage instanceFor({required String bucket}) => instance; 
  MockStorageReference ref([String? path]) => MockStorageReference();
  MockStorageReference refFromURL(String url) => MockStorageReference();
}

class MockStorageReference {
  MockStorageReference child(String path) => this;
  
  // 🚀 FIXED: Now returns an awaitable UploadTask
  UploadTask putFile(dynamic file, [dynamic metadata]) => UploadTask();
  UploadTask putData(dynamic data, [dynamic metadata]) => UploadTask();
  
  Future<String> getDownloadURL() async => "https://via.placeholder.com/150"; 
  Future<void> delete() async {}
  Future<dynamic> getMetadata() async => null;
  Future<dynamic> getData() async => null; 
  
  UploadTask writeToFile(dynamic file) => UploadTask();
}

class TaskSnapshot {
  MockStorageReference get ref => MockStorageReference();
  TaskState get state => TaskState.success;
  int get bytesTransferred => 100;
  int get totalBytes => 100;
}

enum TaskState { success, error, canceled, running, paused }

typedef Reference = MockStorageReference;

class SettableMetadata {
  final String? contentType;
  final Map<String, String>? customMetadata;
  final String? cacheControl;
  SettableMetadata({this.contentType, this.customMetadata, this.cacheControl});
}

class UploadTask implements Future<TaskSnapshot> {
   final Future<TaskSnapshot> _delegate = Future.value(TaskSnapshot());
   @override
   Stream<TaskSnapshot> asStream() => _delegate.asStream();
   @override
   Future<TaskSnapshot> catchError(Function onError, {bool Function(Object)? test}) => _delegate.catchError(onError, test: test);
   @override
   Future<R> then<R>(FutureOr<R> Function(TaskSnapshot) onValue, {Function? onError}) => _delegate.then(onValue, onError: onError);
   @override
   Future<TaskSnapshot> timeout(Duration timeLimit, {FutureOr<TaskSnapshot> Function()? onTimeout}) => _delegate.timeout(timeLimit, onTimeout: onTimeout);
   @override
   Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) => _delegate.whenComplete(action);

   Stream<TaskSnapshot> get snapshotEvents => const Stream.empty();
   TaskSnapshot get snapshot => TaskSnapshot();
   MockStorageReference get ref => MockStorageReference();

   // 🚀 FIXED: Added the cancel method the upload bar is looking for!
   Future<bool> cancel() async => true; 
}