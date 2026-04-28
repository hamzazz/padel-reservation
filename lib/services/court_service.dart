import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';

class CourtService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _courts =>
      _db.collection('courts');

  Future<List<Court>> getAll() async {
    try {
      final snap = await _courts.orderBy('name').get();
      return snap.docs.map((d) => Court.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> uploadImage(File imageFile, String courtId) async {
    try {
      final ref = _storage.ref('courts/$courtId.jpg');
      await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteImage(String courtId) async {
    try {
      await _storage.ref('courts/$courtId.jpg').delete();
    } catch (_) {}
  }

  Future<void> save(Court court) async {
    await _courts.doc(court.id).set(court.toMap());
  }

  Future<Court> add({
    required String name,
    required String description,
    required double pricePerHour,
    required bool isIndoor,
    required String address,
    required double latitude,
    required double longitude,
    int maxReservationsPerSlot = 1,
    File? imageFile,
  }) async {
    final id = const Uuid().v4();

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadImage(imageFile, id);
    }

    final court = Court(
      id: id,
      name: name,
      description: description,
      pricePerHour: pricePerHour,
      isIndoor: isIndoor,
      address: address,
      latitude: latitude,
      longitude: longitude,
      maxReservationsPerSlot: maxReservationsPerSlot,
      imageUrl: imageUrl,
    );
    await _courts.doc(court.id).set(court.toMap());
    return court;
  }

  Future<Court> update(Court court, {File? imageFile}) async {
    String? imageUrl = court.imageUrl;

    if (imageFile != null) {
      imageUrl = await uploadImage(imageFile, court.id);
    }

    final updated = court.copyWith(imageUrl: imageUrl);
    await _courts.doc(updated.id).set(updated.toMap());
    return updated;
  }

  Future<void> delete(String courtId) async {
    await _courts.doc(courtId).delete();
    await deleteImage(courtId);
  }

  Future<void> seedIfEmpty(List<Court> defaults) async {
    final snap = await _courts.limit(1).get();
    if (snap.docs.isEmpty) {
      for (final c in defaults) {
        await _courts.doc(c.id).set(c.toMap());
      }
    }
  }
}
