// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';

Future<String> getData(DocumentReference docRef) async {
  DocumentSnapshot docSnap = await docRef.get();
  var docId2 = docSnap.reference.id;
  return docId2;
}
