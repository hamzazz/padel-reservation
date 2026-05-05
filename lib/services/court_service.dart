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

  Future<void> toggleActive(String courtId, bool isActive) async {
    await _courts.doc(courtId).update({'isActive': isActive});
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

  /// Seeds Rabat clubs. Skips any court whose ID already exists.
  Future<void> seedRabat() async {
    for (final c in _rabatCourts()) {
      final doc = await _courts.doc(c.id).get();
      if (!doc.exists) await _courts.doc(c.id).set(c.toMap());
    }
  }

  static List<Court> _rabatCourts() => [
        const Court(
          id: 'rabat-padel-agdal',
          name: 'Padel Club Agdal',
          description: '4 terrains couverts et éclairés dans le quartier Agdal',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Avenue de France, Agdal, Rabat',
          latitude: 34.0055,
          longitude: -6.8560,
          maxReservationsPerSlot: 4,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-olm-souissi',
          name: 'OLM Padel Souissi',
          description: '6 terrains de padel dans le complexe OLM de Souissi',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Avenue Imam Malik, Souissi, Rabat',
          latitude: 33.9980,
          longitude: -6.8390,
          maxReservationsPerSlot: 6,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-tennis-royal',
          name: 'Tennis Club Royal Padel',
          description: '2 terrains de padel au Tennis Club Royal Hassan',
          pricePerHour: 450,
          isIndoor: false,
          address: 'Avenue Mohamed V, Hassan, Rabat',
          latitude: 34.0120,
          longitude: -6.8300,
          maxReservationsPerSlot: 2,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-hay-riad',
          name: 'Padel Hay Riad',
          description: '4 terrains de padel dans le quartier résidentiel Hay Riad',
          pricePerHour: 400,
          isIndoor: false,
          address: 'Hay Riad, Rabat',
          latitude: 33.9640,
          longitude: -6.8820,
          maxReservationsPerSlot: 4,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-temara-sport',
          name: 'Témara Sport Padel',
          description: '3 terrains extérieurs à Témara',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Boulevard Hassan II, Témara',
          latitude: 33.9270,
          longitude: -6.9040,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-aviation',
          name: 'Club Aviation Padel',
          description: '3 terrains de padel dans le quartier Aviation de Rabat',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Quartier Aviation, Rabat',
          latitude: 34.0080,
          longitude: -6.8700,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-ocean-padel',
          name: 'Ocean Padel Rabat',
          description: '3 terrains avec vue sur l\'océan, près de la plage de Rabat',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Avenue de l\'Océan, Rabat',
          latitude: 34.0230,
          longitude: -6.8500,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-akkari',
          name: 'Padel Akkari',
          description: '2 terrains de padel dans le quartier Akkari',
          pricePerHour: 360,
          isIndoor: false,
          address: 'Rue de l\'Akkari, Rabat',
          latitude: 33.9950,
          longitude: -6.8590,
          maxReservationsPerSlot: 2,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-yacoub',
          name: 'Padel Yacoub El Mansour',
          description: '3 terrains de padel dans le quartier Yacoub El Mansour',
          pricePerHour: 370,
          isIndoor: false,
          address: 'Yacoub El Mansour, Rabat',
          latitude: 33.9900,
          longitude: -6.8540,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-arena-padel',
          name: 'Arena Padel Rabat',
          description: '4 terrains dans le complexe sportif Arena de Rabat',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Route de Casablanca, Rabat',
          latitude: 33.9850,
          longitude: -6.8600,
          maxReservationsPerSlot: 4,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-diour',
          name: 'Padel Diour Jamaa',
          description: '3 terrains de padel, accès facile depuis le centre-ville',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Diour Jamaa, Rabat',
          latitude: 34.0000,
          longitude: -6.8460,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'sale-padel-salam',
          name: 'Sport Center Salé Padel',
          description: '3 terrains de padel à Hay Salam, Salé',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Hay Salam, Salé',
          latitude: 34.0380,
          longitude: -6.7800,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'sale-padel-tabriquet',
          name: 'Padel Club Tabriquet',
          description: '3 terrains extérieurs dans le quartier Tabriquet, Salé',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Tabriquet, Salé',
          latitude: 34.0490,
          longitude: -6.7960,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
        const Court(
          id: 'sale-padel-andalous',
          name: 'Padel Hay Andalous Salé',
          description: '2 terrains de padel à Hay Andalous, Salé',
          pricePerHour: 340,
          isIndoor: false,
          address: 'Hay Andalous, Salé',
          latitude: 34.0340,
          longitude: -6.7750,
          maxReservationsPerSlot: 2,
          city: 'Rabat',
        ),
        const Court(
          id: 'rabat-padel-al-fath',
          name: 'Padel Al Fath Rabat',
          description: '3 terrains couverts au complexe Al Fath, centre de Rabat',
          pricePerHour: 390,
          isIndoor: true,
          address: 'Rue Al Mansour Ad Dahbi, Rabat',
          latitude: 34.0100,
          longitude: -6.8450,
          maxReservationsPerSlot: 3,
          city: 'Rabat',
        ),
      ];

  /// Seeds Casablanca and Marrakech clubs. Skips any court whose ID already exists.
  Future<int> seedCasablancaMarrakech() async {
    final toSeed = _casablancaMarrakechCourts();
    int added = 0;
    for (final c in toSeed) {
      final doc = await _courts.doc(c.id).get();
      if (!doc.exists) {
        await _courts.doc(c.id).set(c.toMap());
        added++;
      }
    }
    return added;
  }

  static List<Court> _casablancaMarrakechCourts() => [
        // ── Casablanca ──────────────────────────────────────────────────────
        const Court(
          id: 'casa-padel4-bouskoura',
          name: 'Padel 4 Bouskoura',
          description: 'Grand complexe avec 10 terrains couverts et éclairés',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Route de Bouskoura, Casablanca',
          latitude: 33.4992311,
          longitude: -7.6247312,
          maxReservationsPerSlot: 10,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padel-pro',
          name: 'PADEL PRO Casablanca',
          description: 'Club indoor avec 4 terrains professionnels',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Hay Hassani, Casablanca',
          latitude: 33.5303223,
          longitude: -7.6665838,
          maxReservationsPerSlot: 4,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padelmania-tamaris',
          name: 'PADELMANIA Tamaris',
          description: '5 terrains dans le quartier Tamaris',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Tamaris, Casablanca',
          latitude: 33.4807628,
          longitude: -7.8235990,
          maxReservationsPerSlot: 5,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-b-padel-californie',
          name: 'B Padel Californie',
          description: '3 terrains dans le quartier Californie',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Californie, Casablanca',
          latitude: 33.5425125,
          longitude: -7.6182031,
          maxReservationsPerSlot: 3,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-depot4-indoor',
          name: 'DEPOT 4 Indoor Padel',
          description: '4 terrains indoor à Sidi Maarouf',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Sidi Maarouf, Casablanca',
          latitude: 33.5120665,
          longitude: -7.6605552,
          maxReservationsPerSlot: 4,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padel-house',
          name: 'Padel House Ain Sebaa',
          description: 'Terrains de padel à Ain Sebaa',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Ain Sebaa, Casablanca',
          latitude: 33.6021320,
          longitude: -7.5478834,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padel-park-sindibad',
          name: 'Padel Park by Sindibad',
          description: '3 terrains extérieurs à côté du parc Sindibad',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Parc Sindibad, Casablanca',
          latitude: 33.5815961,
          longitude: -7.6931606,
          maxReservationsPerSlot: 3,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-anfa-padel-corniche',
          name: 'ANFA PADEL Corniche',
          description: 'Terrains de padel sur la Corniche d\'Ain Diab',
          pricePerHour: 450,
          isIndoor: false,
          address: 'Corniche Ain Diab, Casablanca',
          latitude: 33.6066212,
          longitude: -7.6545706,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padel-social-club',
          name: 'Padel Social Club Maârif',
          description: '3 terrains au cœur du quartier Maârif',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Maârif, Casablanca',
          latitude: 33.5750742,
          longitude: -7.6630494,
          maxReservationsPerSlot: 3,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-plein-ciel-paradise',
          name: 'Plein Ciel Paradise',
          description: '3 terrains avec vue panoramique à Ain Diab',
          pricePerHour: 450,
          isIndoor: false,
          address: 'Ain Diab, Casablanca',
          latitude: 33.5970781,
          longitude: -7.6676292,
          maxReservationsPerSlot: 3,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-club-paradise',
          name: 'Club Paradise Ain Diab',
          description: '5 terrains dans le complexe sportif Paradise',
          pricePerHour: 450,
          isIndoor: false,
          address: 'Ain Diab, Casablanca',
          latitude: 33.5975745,
          longitude: -7.6680365,
          maxReservationsPerSlot: 5,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-occ-oceanic-club',
          name: 'OCC Oceanic Club',
          description: '4 terrains dans le club Oceanic d\'Anfa',
          pricePerHour: 400,
          isIndoor: false,
          address: 'Anfa, Casablanca',
          latitude: 33.5775239,
          longitude: -7.6889679,
          maxReservationsPerSlot: 4,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-ccc-sun-beach',
          name: 'C.C.C. Sun-Beach Club',
          description: 'Terrains de padel au bord de la mer à Ain Diab',
          pricePerHour: 430,
          isIndoor: false,
          address: 'Ain Diab, Casablanca',
          latitude: 33.5952787,
          longitude: -7.6789901,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-miami-fitness',
          name: 'Miami Fitness Club Padel',
          description: 'Terrains de padel intégrés au club fitness Miami',
          pricePerHour: 400,
          isIndoor: false,
          address: 'Ain Diab, Casablanca',
          latitude: 33.5963662,
          longitude: -7.6781223,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-juande-morillo-padel',
          name: 'Juande Morillo Padel',
          description: 'Centre de padel avec coaching professionnel',
          pricePerHour: 400,
          isIndoor: false,
          address: 'Oulfa, Casablanca',
          latitude: 33.5486619,
          longitude: -7.6373744,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-green-sports-park',
          name: 'Green Sports Park Bouskoura',
          description: '3 terrains dans le Green Sports Park',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Bouskoura, Casablanca',
          latitude: 33.4800223,
          longitude: -7.6359558,
          maxReservationsPerSlot: 3,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-arena-ville-verte',
          name: 'Arena Ville Verte Bouskoura',
          description: '6 terrains dans le complexe Arena de Ville Verte',
          pricePerHour: 400,
          isIndoor: true,
          address: 'Ville Verte, Bouskoura, Casablanca',
          latitude: 33.4870476,
          longitude: -7.5779506,
          maxReservationsPerSlot: 6,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-padel-country-club',
          name: 'Padel Country Club (PCC)',
          description: '4 terrains dans un cadre verdoyant à Bouskoura',
          pricePerHour: 400,
          isIndoor: false,
          address: 'Bouskoura, Casablanca',
          latitude: 33.4818699,
          longitude: -7.5939439,
          maxReservationsPerSlot: 4,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-wi-padel-bouskoura',
          name: 'Wi Padel Bouskoura',
          description: '2 terrains de padel à Bouskoura',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Bouskoura, Casablanca',
          latitude: 33.4915362,
          longitude: -7.5995172,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-tennis-club-bouskoura',
          name: 'Tennis Club Bouskoura Padel',
          description: 'Terrain de padel au Tennis Club de Bouskoura',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Route de Bouskoura, Casablanca',
          latitude: 33.4517308,
          longitude: -7.7091729,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        const Court(
          id: 'casa-elite-padel',
          name: 'Elite Padel Projects',
          description: '2 terrains de padel à Ain Diab',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Ain Diab, Casablanca',
          latitude: 33.5889916,
          longitude: -7.6738485,
          maxReservationsPerSlot: 2,
          city: 'Casablanca',
        ),
        // ── Marrakech ────────────────────────────────────────────────────────
        const Court(
          id: 'mkesh-padel-square',
          name: 'Padel Square Marrakech',
          description: 'Grand complexe avec 6 terrains sur la route de l\'Ourika',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Route de l\'Ourika, Marrakech',
          latitude: 31.5873512,
          longitude: -8.0117467,
          maxReservationsPerSlot: 6,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-urban-padel-royal',
          name: 'Urban Padel Royal',
          description: '3 terrains de padel à Guéliz',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Guéliz, Marrakech',
          latitude: 31.6281115,
          longitude: -8.0108839,
          maxReservationsPerSlot: 3,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-urban-padel-pharmaciens',
          name: 'Urban Padel Pharmaciens',
          description: '4 terrains dans le quartier des Pharmaciens, Guéliz',
          pricePerHour: 380,
          isIndoor: false,
          address: 'Guéliz, Marrakech',
          latitude: 31.6258430,
          longitude: -8.0179479,
          maxReservationsPerSlot: 4,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-atlas-tennis-padel',
          name: 'Atlas Tennis Padel Académie',
          description: '5 terrains de padel avec académie et coaching',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Route de Fès, Marrakech',
          latitude: 31.5298302,
          longitude: -7.9410773,
          maxReservationsPerSlot: 5,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-palm-tennis-padel',
          name: 'Palm Tennis Club & Padel',
          description: '2 terrains de padel dans la Palmeraie de Marrakech',
          pricePerHour: 420,
          isIndoor: false,
          address: 'Palmeraie, Marrakech',
          latitude: 31.6892415,
          longitude: -7.9995784,
          maxReservationsPerSlot: 2,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-kickoff-academy',
          name: 'KICK OFF Academy Padel',
          description: '4 terrains de padel dans l\'académie KICK OFF',
          pricePerHour: 370,
          isIndoor: false,
          address: 'Route de Fès, Marrakech',
          latitude: 31.6589800,
          longitude: -8.0552795,
          maxReservationsPerSlot: 4,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-padel-kickoff-targa',
          name: 'PADEL KICK OFF Targa',
          description: '3 terrains de padel à Targa',
          pricePerHour: 370,
          isIndoor: false,
          address: 'Targa, Marrakech',
          latitude: 31.6599508,
          longitude: -8.0555484,
          maxReservationsPerSlot: 3,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-tennis-academy',
          name: 'Tennis Academy Marrakech Padel',
          description: '2 terrains de padel à la Tennis Academy Marrakech',
          pricePerHour: 350,
          isIndoor: false,
          address: 'Route de Fès, Marrakech',
          latitude: 31.6491204,
          longitude: -8.0539112,
          maxReservationsPerSlot: 2,
          city: 'Marrakech',
        ),
        const Court(
          id: 'mkesh-padel-m-amizmiz',
          name: 'Padel M Marrakech',
          description: 'Club de padel sur la route d\'Amizmiz',
          pricePerHour: 360,
          isIndoor: false,
          address: 'Route d\'Amizmiz, Marrakech',
          latitude: 31.5875252,
          longitude: -8.0112997,
          maxReservationsPerSlot: 2,
          city: 'Marrakech',
        ),
      ];
}
