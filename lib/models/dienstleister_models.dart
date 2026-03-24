// lib/models/dienstleister_models.dart  —  v3 (Drop-in Ersatz)
// Neu: ChecklistenEintrag + ChecklistenVorlagen (18 Kategorien, ~180 Punkte)

import 'dart:convert';
import 'package:flutter/material.dart';

// ============================================================================
// ENUMS
// ============================================================================

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

enum VergleichsTag {
  favorit,
  backup,
  abgelehnt,
  inPruefung;

  String get label {
    switch (this) {
      case VergleichsTag.favorit:
        return 'Favorit';
      case VergleichsTag.backup:
        return 'Backup';
      case VergleichsTag.abgelehnt:
        return 'Abgelehnt';
      case VergleichsTag.inPruefung:
        return 'In Prüfung';
    }
  }

  Color get color {
    switch (this) {
      case VergleichsTag.favorit:
        return const Color(0xFF4CAF50);
      case VergleichsTag.backup:
        return const Color(0xFF2196F3);
      case VergleichsTag.abgelehnt:
        return const Color(0xFFF44336);
      case VergleichsTag.inPruefung:
        return const Color(0xFFFFC107);
    }
  }

  IconData get icon {
    switch (this) {
      case VergleichsTag.favorit:
        return Icons.star;
      case VergleichsTag.backup:
        return Icons.bookmark;
      case VergleichsTag.abgelehnt:
        return Icons.close;
      case VergleichsTag.inPruefung:
        return Icons.hourglass_empty;
    }
  }
}

enum KommunikationsTyp {
  email,
  anruf,
  treffen,
  whatsapp,
  notiz,
  angebotErhalten,
  vertragGeschickt,
  sonstiges;

  String get label {
    switch (this) {
      case KommunikationsTyp.email:
        return 'E-Mail';
      case KommunikationsTyp.anruf:
        return 'Anruf';
      case KommunikationsTyp.treffen:
        return 'Treffen';
      case KommunikationsTyp.whatsapp:
        return 'WhatsApp';
      case KommunikationsTyp.notiz:
        return 'Notiz';
      case KommunikationsTyp.angebotErhalten:
        return 'Angebot erhalten';
      case KommunikationsTyp.vertragGeschickt:
        return 'Vertrag geschickt';
      case KommunikationsTyp.sonstiges:
        return 'Sonstiges';
    }
  }

  IconData get icon {
    switch (this) {
      case KommunikationsTyp.email:
        return Icons.email;
      case KommunikationsTyp.anruf:
        return Icons.phone;
      case KommunikationsTyp.treffen:
        return Icons.people;
      case KommunikationsTyp.whatsapp:
        return Icons.chat;
      case KommunikationsTyp.notiz:
        return Icons.note;
      case KommunikationsTyp.angebotErhalten:
        return Icons.description;
      case KommunikationsTyp.vertragGeschickt:
        return Icons.assignment;
      case KommunikationsTyp.sonstiges:
        return Icons.more_horiz;
    }
  }

  Color get color {
    switch (this) {
      case KommunikationsTyp.email:
        return Colors.blue;
      case KommunikationsTyp.anruf:
        return Colors.green;
      case KommunikationsTyp.treffen:
        return Colors.purple;
      case KommunikationsTyp.whatsapp:
        return const Color(0xFF25D366);
      case KommunikationsTyp.notiz:
        return Colors.orange;
      case KommunikationsTyp.angebotErhalten:
        return Colors.teal;
      case KommunikationsTyp.vertragGeschickt:
        return Colors.indigo;
      case KommunikationsTyp.sonstiges:
        return Colors.grey;
    }
  }
}

// ============================================================================
// HILFSKLASSEN
// ============================================================================

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

// ============================================================================
// DIENSTLEISTER
// ============================================================================

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
  final VergleichsTag? vergleichsTag;

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
    this.vergleichsTag,
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
    'vergleichs_tag': vergleichsTag?.name,
  };

  factory Dienstleister.fromMap(Map<String, dynamic> map) => Dienstleister(
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
    vergleichsTag: map['vergleichs_tag'] != null
        ? VergleichsTag.values.firstWhere(
            (e) => e.name == map['vergleichs_tag'],
            orElse: () => VergleichsTag.inPruefung,
          )
        : null,
  );

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
    VergleichsTag? vergleichsTag,
    bool clearVergleichsTag = false,
  }) => Dienstleister(
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
    vergleichsTag: clearVergleichsTag
        ? null
        : (vergleichsTag ?? this.vergleichsTag),
  );
}

// ============================================================================
// DIENSTLEISTER ZAHLUNG
// ============================================================================

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
  }) => DienstleisterZahlung(
    id: id ?? this.id,
    dienstleisterId: dienstleisterId ?? this.dienstleisterId,
    bezeichnung: bezeichnung ?? this.bezeichnung,
    betrag: betrag ?? this.betrag,
    faelligAm: faelligAm ?? this.faelligAm,
    bezahlt: bezahlt ?? this.bezahlt,
  );
}

// ============================================================================
// DIENSTLEISTER NOTIZ
// ============================================================================

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

// ============================================================================
// DIENSTLEISTER AUFGABE
// ============================================================================

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
  }) => DienstleisterAufgabe(
    id: id ?? this.id,
    dienstleisterId: dienstleisterId ?? this.dienstleisterId,
    titel: titel ?? this.titel,
    faelligAm: faelligAm ?? this.faelligAm,
    erledigt: erledigt ?? this.erledigt,
  );
}

// ============================================================================
// KOMMUNIKATIONS-LOG EINTRAG
// ============================================================================

class KommunikationsLogEintrag {
  final String id;
  final String dienstleisterId;
  final DateTime erstelltAm;
  final KommunikationsTyp typ;
  final String text;
  final String? vorlageKey;

  KommunikationsLogEintrag({
    required this.id,
    required this.dienstleisterId,
    required this.erstelltAm,
    required this.typ,
    required this.text,
    this.vorlageKey,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'erstellt_am': erstelltAm.toIso8601String(),
    'typ': typ.name,
    'text': text,
    'vorlage_key': vorlageKey,
  };

  factory KommunikationsLogEintrag.fromMap(Map<String, dynamic> map) =>
      KommunikationsLogEintrag(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        erstelltAm: DateTime.parse(map['erstellt_am']),
        typ: KommunikationsTyp.values.firstWhere(
          (e) => e.name == map['typ'],
          orElse: () => KommunikationsTyp.notiz,
        ),
        text: map['text'] ?? '',
        vorlageKey: map['vorlage_key'],
      );
}

// ============================================================================
// ANGEBOT VERGLEICH
// ============================================================================

class AngebotVergleich {
  final String id;
  final String dienstleisterId;
  final String bezeichnung;
  final double preis;
  final String leistungen;
  final String notizen;
  final DateTime erstelltAm;
  final bool istGewaehlt;

  AngebotVergleich({
    required this.id,
    required this.dienstleisterId,
    required this.bezeichnung,
    required this.preis,
    this.leistungen = '',
    this.notizen = '',
    required this.erstelltAm,
    this.istGewaehlt = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'bezeichnung': bezeichnung,
    'preis': preis,
    'leistungen': leistungen,
    'notizen': notizen,
    'erstellt_am': erstelltAm.toIso8601String(),
    'ist_gewaehlt': istGewaehlt ? 1 : 0,
  };

  factory AngebotVergleich.fromMap(Map<String, dynamic> map) =>
      AngebotVergleich(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        bezeichnung: map['bezeichnung'] ?? '',
        preis: (map['preis'] ?? 0.0).toDouble(),
        leistungen: map['leistungen'] ?? '',
        notizen: map['notizen'] ?? '',
        erstelltAm: DateTime.parse(map['erstellt_am']),
        istGewaehlt: map['ist_gewaehlt'] == 1,
      );

  AngebotVergleich copyWith({
    String? id,
    String? dienstleisterId,
    String? bezeichnung,
    double? preis,
    String? leistungen,
    String? notizen,
    DateTime? erstelltAm,
    bool? istGewaehlt,
  }) => AngebotVergleich(
    id: id ?? this.id,
    dienstleisterId: dienstleisterId ?? this.dienstleisterId,
    bezeichnung: bezeichnung ?? this.bezeichnung,
    preis: preis ?? this.preis,
    leistungen: leistungen ?? this.leistungen,
    notizen: notizen ?? this.notizen,
    erstelltAm: erstelltAm ?? this.erstelltAm,
    istGewaehlt: istGewaehlt ?? this.istGewaehlt,
  );
}

// ============================================================================
// KOMMUNIKATIONS-VORLAGEN
// ============================================================================

class KommunikationsVorlage {
  final String key;
  final String titel;
  final String text;
  final KommunikationsTyp typ;
  final DienstleisterStatus? fuerStatus;
  const KommunikationsVorlage({
    required this.key,
    required this.titel,
    required this.text,
    required this.typ,
    this.fuerStatus,
  });
}

class KommunikationsVorlagen {
  static const List<KommunikationsVorlage> alle = [
    KommunikationsVorlage(
      key: 'erstanfrage',
      titel: 'Erstanfrage',
      typ: KommunikationsTyp.email,
      fuerStatus: DienstleisterStatus.recherche,
      text:
          'Guten Tag,\n\nwir planen unsere Hochzeit am [DATUM] und interessieren uns sehr für Ihre Dienstleistungen.\n\nKönnten Sie uns bitte ein unverbindliches Angebot zusenden?\n\nMit freundlichen Grüßen\n[NAME]',
    ),
    KommunikationsVorlage(
      key: 'nachfassen',
      titel: 'Nachfassen nach Anfrage',
      typ: KommunikationsTyp.email,
      fuerStatus: DienstleisterStatus.angefragt,
      text:
          'Guten Tag,\n\nvor einigen Tagen haben wir Ihnen eine Anfrage für unsere Hochzeit am [DATUM] gesendet.\n\nDa wir unsere Planung voranbringen möchten, würden wir uns sehr über eine Rückmeldung freuen.\n\nMit freundlichen Grüßen\n[NAME]',
    ),
    KommunikationsVorlage(
      key: 'buchung_bestaetigen',
      titel: 'Buchung bestätigen',
      typ: KommunikationsTyp.email,
      fuerStatus: DienstleisterStatus.angebot,
      text:
          'Guten Tag,\n\nwir freuen uns, Ihnen mitteilen zu können, dass wir uns für Ihr Angebot entschieden haben!\n\nBitte senden Sie uns den Vertrag zu, damit wir die Buchung abschließen können.\n\nMit freundlichen Grüßen\n[NAME]',
    ),
    KommunikationsVorlage(
      key: 'ablehnen',
      titel: 'Angebot ablehnen',
      typ: KommunikationsTyp.email,
      text:
          'Guten Tag,\n\nvielen Dank für Ihr Angebot. Nach reiflicher Überlegung haben wir uns leider für einen anderen Anbieter entschieden.\n\nWir wünschen Ihnen weiterhin viel Erfolg.\n\nMit freundlichen Grüßen\n[NAME]',
    ),
    KommunikationsVorlage(
      key: 'briefing_anfragen',
      titel: 'Briefing-Termin anfragen',
      typ: KommunikationsTyp.email,
      fuerStatus: DienstleisterStatus.gebucht,
      text:
          'Guten Tag,\n\nwir würden gerne einen Briefing-Termin vereinbaren, um alle Details für unsere Hochzeit am [DATUM] zu besprechen.\n\nWann wären Sie verfügbar?\n\nMit freundlichen Grüßen\n[NAME]',
    ),
    KommunikationsVorlage(
      key: 'dankeschoen',
      titel: 'Dankeschön nach dem Event',
      typ: KommunikationsTyp.email,
      fuerStatus: DienstleisterStatus.geliefert,
      text:
          'Guten Tag,\n\nvielen herzlichen Dank für Ihre wunderbare Arbeit bei unserer Hochzeit!\n\nSie haben zu einem unvergesslichen Tag beigetragen und wir werden Sie sehr gerne weiterempfehlen.\n\nMit freundlichen Grüßen\n[NAME]',
    ),
  ];

  static List<KommunikationsVorlage> fuerStatus(DienstleisterStatus status) =>
      alle
          .where((v) => v.fuerStatus == null || v.fuerStatus == status)
          .toList();
}

// ============================================================================
// NEU v3: CHECKLISTEN-EINTRAG
// ============================================================================

class ChecklistenEintrag {
  final String id;
  final String dienstleisterId;
  final String text;
  final bool erledigt;
  final String? vorlagenKey;
  final int reihenfolge;

  const ChecklistenEintrag({
    required this.id,
    required this.dienstleisterId,
    required this.text,
    this.erledigt = false,
    this.vorlagenKey,
    this.reihenfolge = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'dienstleister_id': dienstleisterId,
    'text': text,
    'erledigt': erledigt ? 1 : 0,
    'vorlage_key': vorlagenKey,
    'reihenfolge': reihenfolge,
  };

  factory ChecklistenEintrag.fromMap(Map<String, dynamic> map) =>
      ChecklistenEintrag(
        id: map['id'],
        dienstleisterId: map['dienstleister_id'],
        text: map['text'] ?? '',
        erledigt: map['erledigt'] == 1,
        vorlagenKey: map['vorlage_key'],
        reihenfolge: map['reihenfolge'] ?? 0,
      );

  ChecklistenEintrag copyWith({
    String? id,
    String? dienstleisterId,
    String? text,
    bool? erledigt,
    String? vorlagenKey,
    int? reihenfolge,
    bool clearVorlagenKey = false,
  }) => ChecklistenEintrag(
    id: id ?? this.id,
    dienstleisterId: dienstleisterId ?? this.dienstleisterId,
    text: text ?? this.text,
    erledigt: erledigt ?? this.erledigt,
    vorlagenKey: clearVorlagenKey ? null : (vorlagenKey ?? this.vorlagenKey),
    reihenfolge: reihenfolge ?? this.reihenfolge,
  );
}

// ============================================================================
// NEU v3: CHECKLISTEN-VORLAGEN
// ============================================================================

class ChecklistenVorlagePunkt {
  final String key;
  final String text;
  const ChecklistenVorlagePunkt({required this.key, required this.text});
}

class ChecklistenVorlagen {
  static List<ChecklistenVorlagePunkt> fuerKategorie(
    DienstleisterKategorie k,
  ) => _vorlagen[k] ?? _allgemein;

  static const List<ChecklistenVorlagePunkt> _allgemein = [
    ChecklistenVorlagePunkt(key: 'allg_angebot', text: 'Angebot eingeholt'),
    ChecklistenVorlagePunkt(
      key: 'allg_vertrag',
      text: 'Vertrag unterschrieben',
    ),
    ChecklistenVorlagePunkt(key: 'allg_anzahlung', text: 'Anzahlung geleistet'),
    ChecklistenVorlagePunkt(
      key: 'allg_briefing',
      text: 'Briefing-Termin vereinbart',
    ),
    ChecklistenVorlagePunkt(
      key: 'allg_logistik',
      text: 'Ankunftszeit & Adresse bestätigt',
    ),
    ChecklistenVorlagePunkt(
      key: 'allg_restzahlung',
      text: 'Restzahlung terminiert',
    ),
    ChecklistenVorlagePunkt(key: 'allg_bewertung', text: 'Bewertung abgegeben'),
  ];

  static const Map<DienstleisterKategorie, List<ChecklistenVorlagePunkt>>
  _vorlagen = {
    DienstleisterKategorie.location: [
      ChecklistenVorlagePunkt(
        key: 'loc_besichtigung',
        text: 'Besichtigung durchgeführt',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_kapazitaet',
        text: 'Kapazität & Bestuhlung geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_exklusiv',
        text: 'Exklusivbuchung geprüft',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_catering_ext',
        text: 'Externes Catering erlaubt?',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_musik_sperrstd',
        text: 'Musik-Sperrstunde geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_parken',
        text: 'Parkmöglichkeiten besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_backup_indoor',
        text: 'Indoor-Backup bei Regen vorhanden',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_depo',
        text: 'Kaution / Depotbetrag bekannt',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_aufbau_zeit',
        text: 'Aufbau- & Abbauzeiten bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'loc_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.trauredner: [
      ChecklistenVorlagePunkt(
        key: 'trau_kennenlern',
        text: 'Kennenlerngespräch geführt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_zeremonie',
        text: 'Zeremonie-Ablauf besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_persoenlich',
        text: 'Persönliche Geschichte übermittelt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_musik',
        text: 'Musikwünsche für Trauung mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_probe',
        text: 'Probetext / Entwurf erhalten & freigegeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_mikrofon',
        text: 'Mikrofon / Technik geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_ankunft',
        text: 'Ankunftszeit & Treffpunkt bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'trau_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.catering: [
      ChecklistenVorlagePunkt(
        key: 'cat_probe',
        text: 'Probeessen durchgeführt',
      ),
      ChecklistenVorlagePunkt(key: 'cat_menue', text: 'Menü finalisiert'),
      ChecklistenVorlagePunkt(
        key: 'cat_allergien',
        text: 'Allergien & Unverträglichkeiten übermittelt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_vegetarisch',
        text: 'Anzahl vegetarischer / veganer Gerichte festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_kinder',
        text: 'Kinderteller besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_getraenke',
        text: 'Getränkepauschale oder Einzelpreise geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_personal',
        text: 'Anzahl Servicepersonal bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_auf_abbau',
        text: 'Aufbau- und Abbauzeiten abgestimmt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_geschirr',
        text: 'Geschirr / Besteck inklusive?',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_final_gaeste',
        text: 'Finale Gästezahl übermittelt',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'cat_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.torte: [
      ChecklistenVorlagePunkt(
        key: 'torte_design',
        text: 'Design / Skizze freigegeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_geschmack',
        text: 'Geschmacksrichtung festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_probe',
        text: 'Verkostungstermin gemacht',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_allergien',
        text: 'Allergien mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_etagen',
        text: 'Anzahl Etagen & Personen geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_lieferung',
        text: 'Lieferzeit & Lieferadresse bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_transport',
        text: 'Transportbedingungen abgeklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_aufbau',
        text: 'Aufbau an Location besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'torte_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.fotografie: [
      ChecklistenVorlagePunkt(
        key: 'foto_portfolio',
        text: 'Portfolio angeschaut & Stil passt',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_kennenlern',
        text: 'Kennenlerngespräch geführt',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_wunschliste',
        text: 'Foto-Wunschliste übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_ablauf',
        text: 'Tagesablauf & Zeitplan besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_backup',
        text: 'Backup-Fotograf vorhanden?',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_bildrechte',
        text: 'Bildrechte & Nutzungsrecht geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_lieferzeit',
        text: 'Lieferzeit der Bilder vereinbart',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_formate',
        text: 'Bildformate (RAW/JPG) & Anzahl besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_locations',
        text: 'Shootinglocations abgestimmt',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'foto_restzahlung',
        text: 'Restzahlung nach Bildlieferung',
      ),
    ],
    DienstleisterKategorie.video: [
      ChecklistenVorlagePunkt(
        key: 'vid_portfolio',
        text: 'Showreel angeschaut & Stil passt',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_kennenlern',
        text: 'Kennenlerngespräch geführt',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_ablauf',
        text: 'Tagesablauf & Schlüsselszenen besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_musik',
        text: 'Musikwünsche für Video mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_lieferzeit',
        text: 'Lieferzeit & Schnittfassung vereinbart',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_format',
        text: 'Videoformat & Auflösung besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_drohne',
        text: 'Drohnenaufnahmen gewünscht & erlaubt?',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_bildrechte',
        text: 'Nutzungsrechte geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'vid_restzahlung',
        text: 'Restzahlung nach Lieferung',
      ),
    ],
    DienstleisterKategorie.musik: [
      ChecklistenVorlagePunkt(key: 'musik_demo', text: 'Demo / Mixe angehört'),
      ChecklistenVorlagePunkt(
        key: 'musik_wunschliste',
        text: 'Musikwunschliste übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_taboo',
        text: 'Taboo-Liste (keine dieser Songs) übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_einzug',
        text: 'Song für Einzug festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_erster_tanz',
        text: 'Song für ersten Tanz festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_technik',
        text: 'Technikbedarf & Stromversorgung geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_aufbau',
        text: 'Aufbauzeit & Soundcheck besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_sperrstd',
        text: 'Musik-Sperrstunde bekannt',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_pausen',
        text: 'Pausenregelung besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'musik_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.floristik: [
      ChecklistenVorlagePunkt(
        key: 'flor_beratung',
        text: 'Beratungstermin & Moodboard besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_brautstrauss',
        text: 'Brautstrauß-Design finalisiert',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_anstecker',
        text: 'Anstecker / Boutonnières bestellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_tischdeko',
        text: 'Tischdekorationen besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_zeremonie',
        text: 'Zeremoniedekoration besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_saisonal',
        text: 'Saisonale Verfügbarkeit geprüft',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_lieferung',
        text: 'Lieferzeitpunkt & Adresse bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_aufbau',
        text: 'Aufbau vor Ort besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_abbau',
        text: 'Abbau / Rückgabe geregelt',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'flor_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.styling: [
      ChecklistenVorlagePunkt(
        key: 'style_probe',
        text: 'Probestyling-Termin gemacht',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_frisur',
        text: 'Frisur-Design festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_makeup',
        text: 'Make-up-Look festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_fotos_ref',
        text: 'Referenzfotos übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_dauer',
        text: 'Zeitbedarf & Abfolge geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_brautjungfern',
        text: 'Styling für Brautjungfern / Familie besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_haarkranz',
        text: 'Haarkranz / Accessoires abgestimmt',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_anfahrt',
        text: 'Kommt zur Location oder Studio?',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'style_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.kleidung: [
      ChecklistenVorlagePunkt(key: 'kleid_probe1', text: '1. Anprobe gemacht'),
      ChecklistenVorlagePunkt(
        key: 'kleid_probe2',
        text: '2. Anprobe / Änderungen gemacht',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_abholung',
        text: 'Abholtermin bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_schuhe',
        text: 'Schuhe für Anprobe mitgebracht',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_unterwaesche',
        text: 'Passende Unterwäsche beim Termin dabei',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_reinigung',
        text: 'Reinigung nach Hochzeit besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_braeutigam',
        text: 'Anzug / Bräutigam-Outfit bestellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_transport',
        text: 'Transport des Kleides zum Ort geplant',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'kleid_restzahlung',
        text: 'Restzahlung bei Abholung',
      ),
    ],
    DienstleisterKategorie.papeterie: [
      ChecklistenVorlagePunkt(
        key: 'pap_design',
        text: 'Design & Stil besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_muster',
        text: 'Muster / Proof freigegeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_einladungen',
        text: 'Einladungen bestellt & verschickt',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_tischkarten',
        text: 'Tischkarten mit finaler Gästeliste bestellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_menuekarten',
        text: 'Menükarten erstellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_danksagungen',
        text: 'Danksagungs-Karten vorbereitet',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_lieferzeit',
        text: 'Lieferzeit rechtzeitig eingeplant',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'pap_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.transport: [
      ChecklistenVorlagePunkt(
        key: 'trans_fahrzeug',
        text: 'Fahrzeugtyp & Ausstattung bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_deko',
        text: 'Fahrzeugdekoration besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_routen',
        text: 'Routen & Haltepunkte festgelegt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_abholung',
        text: 'Abholadresse & Uhrzeit bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_gaeste',
        text: 'Gäste-Transfer geregelt (falls nötig)',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_foto',
        text: 'Zwischenstopp für Fotos eingeplant',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_fahrer',
        text: 'Fahrer-Kontakt erhalten',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'trans_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.kinderbetreuung: [
      ChecklistenVorlagePunkt(
        key: 'kids_anzahl',
        text: 'Anzahl & Alter der Kinder mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_allergien',
        text: 'Allergien / Unverträglichkeiten mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_programm',
        text: 'Kinderprogramm & Aktivitäten besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_raum',
        text: 'Kinderraum / -bereich an Location geprüft',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_essen',
        text: 'Kinderverpflegung geregelt',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_notfallkontakt',
        text: 'Notfallkontakte der Eltern übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'kids_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.technik: [
      ChecklistenVorlagePunkt(
        key: 'tech_begehung',
        text: 'Location-Begehung gemacht',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_licht',
        text: 'Lichtkonzept besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_ton',
        text: 'Tonanlage & Mikrofone geprüft',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_beamer',
        text: 'Beamer / Leinwand besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_strom',
        text: 'Stromversorgung & Absicherung geprüft',
      ),
      ChecklistenVorlagePunkt(key: 'tech_aufbau', text: 'Aufbauzeit bestätigt'),
      ChecklistenVorlagePunkt(
        key: 'tech_soundcheck',
        text: 'Soundcheck mit DJ/Band geplant',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_backup',
        text: 'Backup-Equipment vorhanden',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'tech_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.fotobox: [
      ChecklistenVorlagePunkt(
        key: 'fbox_design',
        text: 'Druckdesign / Rahmen freigegeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'fbox_props',
        text: 'Requisiten-Set besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'fbox_aufstellung',
        text: 'Aufstellungsort an Location geprüft',
      ),
      ChecklistenVorlagePunkt(
        key: 'fbox_strom',
        text: 'Stromversorgung sichergestellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'fbox_digital',
        text: 'Digitale Bildgalerie für Gäste eingerichtet',
      ),
      ChecklistenVorlagePunkt(key: 'fbox_aufbau', text: 'Aufbauzeit bestätigt'),
      ChecklistenVorlagePunkt(key: 'fbox_abbau', text: 'Abbauzeit bestätigt'),
      ChecklistenVorlagePunkt(
        key: 'fbox_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'fbox_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.unterkunft: [
      ChecklistenVorlagePunkt(
        key: 'unt_zimmer',
        text: 'Zimmerkontingent reserviert',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_suite',
        text: 'Brautpaar-Suite / Zimmer bestätigt',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_fruehbucher',
        text: 'Frühbucher-Rabatt für Gäste kommuniziert',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_fruehstueck',
        text: 'Frühstück inklusive?',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_checkin',
        text: 'Check-in-Zeiten für Gäste mitgeteilt',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_depo',
        text: 'Kaution / Depositum geklärt',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_transfer',
        text: 'Transfer zwischen Unterkunft und Location',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'unt_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
    DienstleisterKategorie.planer: [
      ChecklistenVorlagePunkt(
        key: 'plan_erstgespraech',
        text: 'Erstgespräch & Leistungsumfang besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_dienstleister',
        text: 'Dienstleister-Empfehlungen erhalten',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_timeline',
        text: 'Master-Timeline für den Tag erstellt',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_budget',
        text: 'Budget-Tracking gemeinsam aufgesetzt',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_probe',
        text: 'Ablaufprobe / Rehearsal koordiniert',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_notfall',
        text: 'Notfallplan & Backup-Optionen besprochen',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_kontakte',
        text: 'Alle Dienstleister-Kontakte an Planer übergeben',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_vertrag',
        text: 'Vertrag unterschrieben',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_anzahlung',
        text: 'Anzahlung geleistet',
      ),
      ChecklistenVorlagePunkt(
        key: 'plan_restzahlung',
        text: 'Restzahlung terminiert',
      ),
    ],
  };
}
