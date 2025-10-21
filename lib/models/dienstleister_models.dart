import 'dart:convert';
import 'package:flutter/material.dart';

// Enums
enum DienstleisterKategorie {
  location,
  trauredner,
  catering,
  torte,
  fotografie,
  video,
  musik,
  floristik,
  styling,
  kleidung,
  papeterie,
  transport,
  kinderbetreuung,
  technik,
  fotobox,
  unterkunft,
  planer,
  sonstiges;

  String get label {
    switch (this) {
      case DienstleisterKategorie.location:
        return 'Location';
      case DienstleisterKategorie.trauredner:
        return 'Trauredner';
      case DienstleisterKategorie.catering:
        return 'Catering';
      case DienstleisterKategorie.torte:
        return 'Torte';
      case DienstleisterKategorie.fotografie:
        return 'Fotografie';
      case DienstleisterKategorie.video:
        return 'Video';
      case DienstleisterKategorie.musik:
        return 'Musik/DJ';
      case DienstleisterKategorie.floristik:
        return 'Floristik';
      case DienstleisterKategorie.styling:
        return 'Styling';
      case DienstleisterKategorie.kleidung:
        return 'Kleidung';
      case DienstleisterKategorie.papeterie:
        return 'Papeterie';
      case DienstleisterKategorie.transport:
        return 'Transport';
      case DienstleisterKategorie.kinderbetreuung:
        return 'Kinderbetreuung';
      case DienstleisterKategorie.technik:
        return 'Technik';
      case DienstleisterKategorie.fotobox:
        return 'Fotobox';
      case DienstleisterKategorie.unterkunft:
        return 'Unterkunft';
      case DienstleisterKategorie.planer:
        return 'Planer';
      case DienstleisterKategorie.sonstiges:
        return 'Sonstiges';
    }
  }

  IconData get icon {
    switch (this) {
      case DienstleisterKategorie.location:
        return Icons.business;
      case DienstleisterKategorie.trauredner:
        return Icons.record_voice_over;
      case DienstleisterKategorie.catering:
        return Icons.restaurant;
      case DienstleisterKategorie.torte:
        return Icons.cake;
      case DienstleisterKategorie.fotografie:
        return Icons.camera_alt;
      case DienstleisterKategorie.video:
        return Icons.videocam;
      case DienstleisterKategorie.musik:
        return Icons.music_note;
      case DienstleisterKategorie.floristik:
        return Icons.local_florist;
      case DienstleisterKategorie.styling:
        return Icons.face;
      case DienstleisterKategorie.kleidung:
        return Icons.checkroom;
      case DienstleisterKategorie.papeterie:
        return Icons.article;
      case DienstleisterKategorie.transport:
        return Icons.directions_car;
      case DienstleisterKategorie.kinderbetreuung:
        return Icons.child_care;
      case DienstleisterKategorie.technik:
        return Icons.audiotrack;
      case DienstleisterKategorie.fotobox:
        return Icons.photo_camera;
      case DienstleisterKategorie.unterkunft:
        return Icons.hotel;
      case DienstleisterKategorie.planer:
        return Icons.event_note;
      case DienstleisterKategorie.sonstiges:
        return Icons.more_horiz;
    }
  }

  Color get color {
    const colors = [
      Color(0xFFF44336),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF3F51B5),
      Color(0xFF2196F3),
      Color(0xFF03A9F4),
      Color(0xFF00BCD4),
      Color(0xFF009688),
      Color(0xFF4CAF50),
      Color(0xFF8BC34A),
      Color(0xFFCDDC39),
      Color(0xFFFFEB3B),
      Color(0xFFFFC107),
      Color(0xFFFF9800),
      Color(0xFFFF5722),
      Color(0xFF795548),
      Color(0xFF9E9E9E),
    ];
    return colors[index % colors.length];
  }
}

enum DienstleisterStatus {
  recherche,
  angefragt,
  angebot,
  shortlist,
  gebucht,
  briefingFertig,
  geliefert,
  abgerechnet,
  bewertet;

  String get label {
    switch (this) {
      case DienstleisterStatus.recherche:
        return 'Recherche';
      case DienstleisterStatus.angefragt:
        return 'Angefragt';
      case DienstleisterStatus.angebot:
        return 'Angebot';
      case DienstleisterStatus.shortlist:
        return 'Shortlist';
      case DienstleisterStatus.gebucht:
        return 'Gebucht';
      case DienstleisterStatus.briefingFertig:
        return 'Briefing Fertig';
      case DienstleisterStatus.geliefert:
        return 'Geliefert';
      case DienstleisterStatus.abgerechnet:
        return 'Abgerechnet';
      case DienstleisterStatus.bewertet:
        return 'Bewertet';
    }
  }

  Color get color {
    switch (this) {
      case DienstleisterStatus.recherche:
        return Colors.grey;
      case DienstleisterStatus.angefragt:
        return Colors.blue;
      case DienstleisterStatus.angebot:
        return Colors.orange;
      case DienstleisterStatus.shortlist:
        return Colors.amber;
      case DienstleisterStatus.gebucht:
        return Colors.green;
      case DienstleisterStatus.briefingFertig:
        return Colors.purple;
      case DienstleisterStatus.geliefert:
        return Colors.teal;
      case DienstleisterStatus.abgerechnet:
        return Colors.indigo;
      case DienstleisterStatus.bewertet:
        return Colors.pink;
    }
  }
}

// Hilfsklassen
class Geld {
  final double betrag;
  final String waehrung;

  Geld({required this.betrag, this.waehrung = 'EUR'});

  Map<String, dynamic> toJson() => {'betrag': betrag, 'waehrung': waehrung};

  factory Geld.fromJson(Map<String, dynamic> json) => Geld(
    betrag: json['betrag']?.toDouble() ?? 0.0,
    waehrung: json['waehrung'] ?? 'EUR',
  );
}

class Kontakt {
  final String name;
  final String email;
  final String telefon;

  Kontakt({required this.name, this.email = '', this.telefon = ''});

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'telefon': telefon,
  };

  factory Kontakt.fromJson(Map<String, dynamic> json) => Kontakt(
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    telefon: json['telefon'] ?? '',
  );
}

class Logistik {
  final String adresse;
  final String ankunftsfenster;
  final String parken;
  final String strom;
  final String zugangshinweise;

  Logistik({
    this.adresse = '',
    this.ankunftsfenster = '',
    this.parken = '',
    this.strom = '',
    this.zugangshinweise = '',
  });

  Map<String, dynamic> toJson() => {
    'adresse': adresse,
    'ankunftsfenster': ankunftsfenster,
    'parken': parken,
    'strom': strom,
    'zugangshinweise': zugangshinweise,
  };

  factory Logistik.fromJson(Map<String, dynamic> json) => Logistik(
    adresse: json['adresse'] ?? '',
    ankunftsfenster: json['ankunftsfenster'] ?? '',
    parken: json['parken'] ?? '',
    strom: json['strom'] ?? '',
    zugangshinweise: json['zugangshinweise'] ?? '',
  );
}

// Hauptklassen
class Dienstleister {
  final String id;
  final String name;
  final DienstleisterKategorie kategorie;
  final DienstleisterStatus status;
  final String? website;
  final String instagram;
  final Kontakt hauptkontakt;
  final double bewertung;
  final Geld? angebotsSumme;
  final DateTime? optionBis;
  final DateTime? briefingDatum;
  final DateTime? ankunft;
  final Logistik logistik;
  final List<String> tags;
  final List<String> dateien;
  final String notizen;
  final bool istFavorit;

  Dienstleister({
    required this.id,
    required this.name,
    required this.kategorie,
    required this.status,
    this.website,
    this.instagram = '',
    required this.hauptkontakt,
    this.bewertung = 0.0,
    this.angebotsSumme,
    this.optionBis,
    this.briefingDatum,
    this.ankunft,
    required this.logistik,
    this.tags = const [],
    this.dateien = const [],
    this.notizen = '',
    this.istFavorit = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kategorie': kategorie.name,
    'status': status.name,
    'website': website,
    'instagram': instagram,
    'kontakt_name': hauptkontakt.name,
    'kontakt_email': hauptkontakt.email,
    'kontakt_telefon': hauptkontakt.telefon,
    'bewertung': bewertung,
    'angebot_betrag': angebotsSumme?.betrag,
    'angebot_waehrung': angebotsSumme?.waehrung ?? 'EUR',
    'option_bis': optionBis?.toIso8601String(),
    'briefing_datum': briefingDatum?.toIso8601String(),
    'ankunft': ankunft?.toIso8601String(),
    'logistik_json': jsonEncode(logistik.toJson()),
    'tags_json': jsonEncode(tags),
    'dateien_json': jsonEncode(dateien),
    'notizen': notizen,
    'ist_favorit': istFavorit ? 1 : 0,
  };

  factory Dienstleister.fromMap(Map<String, dynamic> map) {
    return Dienstleister(
      id: map['id'],
      name: map['name'] ?? '',
      kategorie: DienstleisterKategorie.values.firstWhere(
        (e) => e.name == map['kategorie'],
        orElse: () => DienstleisterKategorie.sonstiges,
      ),
      status: DienstleisterStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DienstleisterStatus.recherche,
      ),
      website: map['website'],
      instagram: map['instagram'] ?? '',
      hauptkontakt: Kontakt(
        name: map['kontakt_name'] ?? '',
        email: map['kontakt_email'] ?? '',
        telefon: map['kontakt_telefon'] ?? '',
      ),
      bewertung: map['bewertung']?.toDouble() ?? 0.0,
      angebotsSumme: map['angebot_betrag'] != null
          ? Geld(
              betrag: map['angebot_betrag']?.toDouble() ?? 0.0,
              waehrung: map['angebot_waehrung'] ?? 'EUR',
            )
          : null,
      optionBis: map['option_bis'] != null
          ? DateTime.parse(map['option_bis'])
          : null,
      briefingDatum: map['briefing_datum'] != null
          ? DateTime.parse(map['briefing_datum'])
          : null,
      ankunft: map['ankunft'] != null ? DateTime.parse(map['ankunft']) : null,
      logistik: map['logistik_json'] != null
          ? Logistik.fromJson(jsonDecode(map['logistik_json']))
          : Logistik(),
      tags: map['tags_json'] != null
          ? List<String>.from(jsonDecode(map['tags_json']))
          : [],
      dateien: map['dateien_json'] != null
          ? List<String>.from(jsonDecode(map['dateien_json']))
          : [],
      notizen: map['notizen'] ?? '',
      istFavorit: map['ist_favorit'] == 1,
    );
  }

  Dienstleister copyWith({
    String? id,
    String? name,
    DienstleisterKategorie? kategorie,
    DienstleisterStatus? status,
    String? website,
    String? instagram,
    Kontakt? hauptkontakt,
    double? bewertung,
    Geld? angebotsSumme,
    DateTime? optionBis,
    DateTime? briefingDatum,
    DateTime? ankunft,
    Logistik? logistik,
    List<String>? tags,
    List<String>? dateien,
    String? notizen,
    bool? istFavorit,
  }) {
    return Dienstleister(
      id: id ?? this.id,
      name: name ?? this.name,
      kategorie: kategorie ?? this.kategorie,
      status: status ?? this.status,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      hauptkontakt: hauptkontakt ?? this.hauptkontakt,
      bewertung: bewertung ?? this.bewertung,
      angebotsSumme: angebotsSumme ?? this.angebotsSumme,
      optionBis: optionBis ?? this.optionBis,
      briefingDatum: briefingDatum ?? this.briefingDatum,
      ankunft: ankunft ?? this.ankunft,
      logistik: logistik ?? this.logistik,
      tags: tags ?? this.tags,
      dateien: dateien ?? this.dateien,
      notizen: notizen ?? this.notizen,
      istFavorit: istFavorit ?? this.istFavorit,
    );
  }
}

class DienstleisterZahlung {
  final String id;
  final String dienstleisterId;
  final String bezeichnung;
  final Geld betrag;
  final DateTime? faelligAm;
  final bool bezahlt;

  DienstleisterZahlung({
    required this.id,
    required this.dienstleisterId,
    required this.bezeichnung,
    required this.betrag,
    this.faelligAm,
    this.bezahlt = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'bezeichnung': bezeichnung,
    'betrag': betrag.betrag,
    'waehrung': betrag.waehrung,
    'faellig_am': faelligAm?.toIso8601String(),
    'bezahlt': bezahlt ? 1 : 0,
  };

  factory DienstleisterZahlung.fromMap(Map<String, dynamic> map) =>
      DienstleisterZahlung(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        bezeichnung: map['bezeichnung'] ?? '',
        betrag: Geld(
          betrag: map['betrag']?.toDouble() ?? 0.0,
          waehrung: map['waehrung'] ?? 'EUR',
        ),
        faelligAm: map['faellig_am'] != null
            ? DateTime.parse(map['faellig_am'])
            : null,
        bezahlt: map['bezahlt'] == 1,
      );

  DienstleisterZahlung copyWith({
    String? id,
    String? dienstleisterId,
    String? bezeichnung,
    Geld? betrag,
    DateTime? faelligAm,
    bool? bezahlt,
  }) {
    return DienstleisterZahlung(
      id: id ?? this.id,
      dienstleisterId: dienstleisterId ?? this.dienstleisterId,
      bezeichnung: bezeichnung ?? this.bezeichnung,
      betrag: betrag ?? this.betrag,
      faelligAm: faelligAm ?? this.faelligAm,
      bezahlt: bezahlt ?? this.bezahlt,
    );
  }
}

class DienstleisterNotiz {
  final String id;
  final String dienstleisterId;
  final DateTime erstelltAm;
  final String text;

  DienstleisterNotiz({
    required this.id,
    required this.dienstleisterId,
    required this.erstelltAm,
    required this.text,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'erstellt_am': erstelltAm.toIso8601String(),
    'text': text,
  };

  factory DienstleisterNotiz.fromMap(Map<String, dynamic> map) =>
      DienstleisterNotiz(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        erstelltAm: DateTime.parse(map['erstellt_am']),
        text: map['text'] ?? '',
      );
}

class DienstleisterAufgabe {
  final String id;
  final String dienstleisterId;
  final String titel;
  final DateTime? faelligAm;
  final bool erledigt;

  DienstleisterAufgabe({
    required this.id,
    required this.dienstleisterId,
    required this.titel,
    this.faelligAm,
    this.erledigt = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'titel': titel,
    'faellig_am': faelligAm?.toIso8601String(),
    'erledigt': erledigt ? 1 : 0,
  };

  factory DienstleisterAufgabe.fromMap(Map<String, dynamic> map) =>
      DienstleisterAufgabe(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        titel: map['titel'] ?? '',
        faelligAm: map['faellig_am'] != null
            ? DateTime.parse(map['faellig_am'])
            : null,
        erledigt: map['erledigt'] == 1,
      );

  DienstleisterAufgabe copyWith({
    String? id,
    String? dienstleisterId,
    String? titel,
    DateTime? faelligAm,
    bool? erledigt,
  }) {
    return DienstleisterAufgabe(
      id: id ?? this.id,
      dienstleisterId: dienstleisterId ?? this.dienstleisterId,
      titel: titel ?? this.titel,
      faelligAm: faelligAm ?? this.faelligAm,
      erledigt: erledigt ?? this.erledigt,
    );
  }
}
