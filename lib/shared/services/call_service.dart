import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/call_model.dart';
import '../models/user_model.dart';

/// Firestore-backed signaling for 1:1 WebRTC calls. No third-party calling
/// service is used — offers/answers/ICE candidates are exchanged through the
/// `calls` collection, and media flows peer-to-peer using free public STUN
/// servers, so there is nothing to pay for.
class CallService {
  CallService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _calls => _db.collection('calls');

  DocumentReference<Map<String, dynamic>> callDoc(String id) => _calls.doc(id);

  /// Creates a ringing call from [me] to [other] and returns its id.
  Future<String> createCall({
    required UserModel me,
    required UserModel other,
    required CallType type,
  }) async {
    final ref = _calls.doc();
    await ref.set(CallModel(
      id: ref.id,
      callerUid: me.uid,
      callerName: me.displayName,
      callerPhoto: me.photoUrl,
      calleeUid: other.uid,
      calleeName: other.displayName,
      calleePhoto: other.photoUrl,
      type: type,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    ).toMap());
    return ref.id;
  }

  Stream<CallModel?> callStream(String id) => callDoc(id)
      .snapshots()
      .map((d) => d.exists ? CallModel.fromDoc(d) : null);

  /// Ringing calls addressed to [uid] (used by the global incoming-call popup).
  Stream<List<CallModel>> incomingCalls(String uid) => _calls
      .where('calleeUid', isEqualTo: uid)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .map((s) => s.docs.map(CallModel.fromDoc).toList());

  Future<void> setOffer(String id, Map<String, dynamic> offer) =>
      callDoc(id).update({'offer': offer});

  Future<void> setAnswer(String id, Map<String, dynamic> answer) =>
      callDoc(id).update({'answer': answer, 'status': CallStatus.accepted.name});

  Future<void> setStatus(String id, CallStatus status) =>
      callDoc(id).update({'status': status.name});

  // ICE candidates ----------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _callerCandidates(String id) =>
      callDoc(id).collection('callerCandidates');
  CollectionReference<Map<String, dynamic>> _calleeCandidates(String id) =>
      callDoc(id).collection('calleeCandidates');

  Future<void> addCandidate(
    String id, {
    required bool fromCaller,
    required Map<String, dynamic> candidate,
  }) =>
      (fromCaller ? _callerCandidates(id) : _calleeCandidates(id)).add(candidate);

  /// Streams newly-added candidates from the *other* peer.
  Stream<List<Map<String, dynamic>>> remoteCandidates(
    String id, {
    required bool iAmCaller,
  }) {
    final col = iAmCaller ? _calleeCandidates(id) : _callerCandidates(id);
    return col.snapshots().map((s) => s
        .docChanges
        .where((c) => c.type == DocumentChangeType.added)
        .map((c) => c.doc.data() ?? <String, dynamic>{})
        .toList());
  }

  /// Marks the call ended and best-effort cleans up the signaling documents.
  Future<void> hangUp(String id) async {
    try {
      await callDoc(id).update({'status': CallStatus.ended.name});
    } catch (_) {/* already gone */}
  }

  Future<void> dispose(String id) async {
    try {
      for (final col in [_callerCandidates(id), _calleeCandidates(id)]) {
        final docs = await col.get();
        for (final d in docs.docs) {
          await d.reference.delete();
        }
      }
      await callDoc(id).delete();
    } catch (_) {/* best effort */}
  }
}
