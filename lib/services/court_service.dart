import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/court.dart';

class CourtService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _courts =>
      _db.collection('courts');

  Future<List<Court>> getAll() async {
    // Try server first to get fresh imageUrl data; fall back to cache if offline.
    try {
      final snap = await _courts
          .orderBy('name')
          .get(const GetOptions(source: Source.server));
      return snap.docs.map((d) => Court.fromMap(d.data())).toList();
    } catch (_) {
      try {
        final snap = await _courts.orderBy('name').get();
        return snap.docs.map((d) => Court.fromMap(d.data())).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<String> uploadImage(File imageFile, String courtId) async {
    try {
      final bytes = await imageFile.readAsBytes();
      debugPrint('uploadImage: ${bytes.length} bytes, courtId=$courtId');
      final ref = _storage.ref('courts/$courtId.jpg');
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      debugPrint('putData done: transferred=${snapshot.bytesTransferred}');
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('getDownloadURL: $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException [${e.code}]: ${e.message}');
      throw Exception('[${e.code}] ${e.message ?? e.toString()}');
    } catch (e) {
      debugPrint('uploadImage error: $e');
      rethrow;
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
    String city = '',
    File? imageFile,
  }) async {
    final id = const Uuid().v4();

    String? imageUrl;
    String? uploadError;
    if (imageFile != null) {
      try {
        imageUrl = await uploadImage(imageFile, id);
      } catch (e) {
        uploadError = e.toString();
        debugPrint('add uploadImage error: $e');
      }
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
      city: city,
      imageUrl: imageUrl,
    );
    await _courts.doc(court.id).set(court.toMap());
    if (uploadError != null) throw Exception(uploadError);
    return court;
  }

  Future<Court> update(Court court, {File? imageFile}) async {
    String? imageUrl = court.imageUrl;
    String? uploadError;

    if (imageFile != null) {
      try {
        imageUrl = await uploadImage(imageFile, court.id);
      } catch (e) {
        uploadError = e.toString();
        debugPrint('update uploadImage error: $e');
      }
    }

    final updated = court.copyWith(imageUrl: imageUrl);
    await _courts.doc(updated.id).set(updated.toMap());
    if (uploadError != null) throw Exception(uploadError);
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
