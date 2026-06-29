import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { audio, video }

enum CallStatus { ringing, accepted, declined, ended }

CallType callTypeFrom(String? v) =>
    v == 'video' ? CallType.video : CallType.audio;

CallStatus callStatusFrom(String? v) {
  switch (v) {
    case 'accepted':
      return CallStatus.accepted;
    case 'declined':
      return CallStatus.declined;
    case 'ended':
      return CallStatus.ended;
    default:
      return CallStatus.ringing;
  }
}

/// A 1:1 call session. Acts as the WebRTC signaling document: the caller writes
/// the [offer], the callee writes the [answer], and ICE candidates flow through
/// the `callerCandidates` / `calleeCandidates` subcollections.
class CallModel {
  final String id;
  final String callerUid;
  final String callerName;
  final String? callerPhoto;
  final String calleeUid;
  final String calleeName;
  final String? calleePhoto;
  final CallType type;
  final CallStatus status;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final DateTime createdAt;

  const CallModel({
    required this.id,
    required this.callerUid,
    required this.callerName,
    this.callerPhoto,
    required this.calleeUid,
    required this.calleeName,
    this.calleePhoto,
    required this.type,
    required this.status,
    this.offer,
    this.answer,
    required this.createdAt,
  });

  bool get isVideo => type == CallType.video;

  factory CallModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CallModel(
      id: doc.id,
      callerUid: data['callerUid'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'Caller',
      callerPhoto: data['callerPhoto'] as String?,
      calleeUid: data['calleeUid'] as String? ?? '',
      calleeName: data['calleeName'] as String? ?? 'Callee',
      calleePhoto: data['calleePhoto'] as String?,
      type: callTypeFrom(data['type'] as String?),
      status: callStatusFrom(data['status'] as String?),
      offer: (data['offer'] as Map?)?.cast<String, dynamic>(),
      answer: (data['answer'] as Map?)?.cast<String, dynamic>(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'callerUid': callerUid,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'calleeUid': calleeUid,
        'calleeName': calleeName,
        'calleePhoto': calleePhoto,
        'type': type.name,
        'status': status.name,
        'offer': offer,
        'answer': answer,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
