# PRD.md

## 1. Produktvision und Problemstellung

### Produktvision
Eine iOS-App für Pokémon-Fans und Gelegenheitssammler, mit der physische Pokémon-Karten schnell per Kamera erfasst, automatisch identifiziert und als digitale Sammlung mit Wertinformationen verwaltet werden können.

### Problem Statement
Pokémon-Sammler besitzen oft viele physische Karten, haben aber keine einfache, mobile und visuell angenehme Möglichkeit, ihre Sammlung zu digitalisieren und zu organisieren. Manuelle Eingabe ist mühsam, fehleranfällig und gerade für Kinder oder Gelegenheitssammler unattraktiv. Gleichzeitig sind Preis- und Seltenheitsinformationen ein relevanter Zusatznutzen, der Sammlern hilft, ihre Sammlung besser einzuordnen.

### Ziel
Die App soll den schnellsten und angenehmsten Weg bieten, eine physische Pokémon-Kartensammlung in eine digitale, durchsuchbare und wertorientierte Sammlung zu überführen.

## 2. Zielgruppe und User Personas

### Primäre Zielgruppe
Allgemeine Pokémon-Fans und Gelegenheitssammler.

### Sekundäre Zielgruppe
Kinder und jüngere Pokémon-Fans, die eine einfache und visuelle Nutzung benötigen.

### Persona 1: Gelegenheitssammler
- sammelt Karten nebenbei
- will Karten schnell erfassen
- interessiert sich für Seltenheit und groben Wert
- möchte Filter, Übersicht und Gesamtwert

### Persona 2: Kind / junger Fan
- liebt Pokémon, aber will keine komplizierten Eingaben
- profitiert von klarer, visueller UX
- möchte Karten sehen, sammeln und leicht wiederfinden

### Persona 3: fortgeschrittener Sammler light
- besitzt mehrere Exemplare derselben Karte
- möchte Zustand pflegen
- will Karten gruppieren, sortieren und bei Bedarf aus Stapeln herauslösen

## 3. Scope des MVP & Core Epics/User Stories

### MVP-Ziel
Der Nutzer kann Pokémon-Karten fotografieren, identifizieren, bestätigen und als digitale Sammlung verwalten.

### Core Epics

#### Epic A: Kartenerkennung und Bestätigung
- Als Nutzer möchte ich eine Karte fotografieren, damit ich sie nicht manuell eingeben muss.
- Als Nutzer möchte ich bei unsicheren Ergebnissen eine kleine Trefferliste sehen, damit ich die richtige Karte auswählen kann.
- Als Nutzer möchte ich das Ergebnis vor dem Speichern bestätigen, damit keine falschen Karten in meiner Sammlung landen.

#### Epic B: Sammlung aufbauen und verwalten
- Als Nutzer möchte ich Karten speichern, damit ich meine physische Sammlung digital abbilden kann.
- Als Nutzer möchte ich dieselbe Karte mehrfach besitzen können, damit mein realer Bestand korrekt dargestellt wird.
- Als Nutzer möchte ich gleiche Karten standardmäßig als Stapel sehen, damit die Sammlung übersichtlich bleibt.
- Als Nutzer möchte ich Karten aus einem Stapel herauslösen können, damit ich besondere Exemplare separat verwalten kann.

#### Epic C: Sammlungsübersicht und Bewertung
- Als Nutzer möchte ich Kartenbild, Seltenheit und Preis sehen, damit ich die Karte schnell einordnen kann.
- Als Nutzer möchte ich meine Sammlung nach Set, Seltenheit, Typ und Wert filtern bzw. sortieren.
- Als Nutzer möchte ich einen Gesamtwert meiner Sammlung sehen.

#### Epic D: Konten und Sync
- Als Nutzer möchte ich die App ohne Login verwenden können.
- Als Nutzer möchte ich optional ein Konto erstellen, um meine Sammlung zu synchronisieren und wiederherzustellen.

#### Epic E: Zustand und Metadaten
- Als Nutzer möchte ich den Zustand einer Karte pflegen, damit meine Sammlung realistischer bewertet und organisiert werden kann.

### Was bewusst nicht im MVP ist
- Social Features
- öffentliche Profile
- Tauschbörse
- Wunschliste
- Preisalarme
- Deck Builder
- komplexe Community-Funktionen
- automatische Preisentwicklung mit Alerts
- Android- oder Web-Client im ersten Release

## 4. High-Level Architektur & Tech-Stack-Empfehlungen

### Frontend
- iOS nativ mit Swift und SwiftUI
- Best Practice für dieses Vorhaben, da Kamera, Apple-Frameworks und Plattformintegration sehr wichtig sind

### Erkennung / Scan
- Hauptflow: Foto aufnehmen → analysieren
- optional: Bild aus Mediathek wählen
- OCR-/Vision-basierte Extraktion von Merkmalen wie:
  - Kartenname
  - Kartennummer
  - Set-Hinweis
- Lookup gegen serverseitig gekapselte Kartendaten

### Backend
- Convex als Backend-Plattform
- Self-hosted über Coolify auf deinem VPS
- Backend übernimmt:
  - Nutzerkonten
  - Sammlungsdaten
  - Synchronisation
  - serverseitige PokéWallet-Integration
  - Caching
  - Normalisierung von Kartendaten
  - Rate-Limit-Schutz

### Externe API
- PokéWallet API als Datenquelle für Kartendetails, Seltenheit, Bilder und Preise
- Zugriffe ausschließlich serverseitig, da API-Key nicht im Client liegen sollte; zusätzlich sprechen die dokumentierten Rate Limits für ein Backend mit Caching

### Authentifizierung
Empfehlung:
- Gastmodus ohne Konto
- optionaler Login mit:
  - E-Mail
  - Sign in with Apple
  - Google

### Architekturentscheidung: Monolith statt Microservices
Empfehlung für MVP: modularer Monolith

Begründung:
- geringere Komplexität
- schnelleres Iterieren
- einfacher Betrieb
- für frühe Produktphase völlig ausreichend

### Mobile-/Plattform-Strategie
- Start mit iOS
- Backend so gestalten, dass Android und Web später dieselben Domänenmodelle und APIs nutzen können

## 5. Konzeptionelles Datenmodell

### Kernobjekte

#### User
- id
- optionaler Auth-Provider / Login-Daten
- Sprache
- Consent-/Privacy-Einstellungen
- CreatedAt / UpdatedAt

#### Card
Repräsentiert die referenzierte externe Karte.
- externalCardId
- name
- setCode
- setName
- cardNumber
- rarity
- type
- imageUrl
- basePrice / marketPrice
- pricingMetadata
- lastPriceSyncAt

#### CollectionStack
Standarddarstellung für gleiche Karten.
- id
- ownerId oder guestScope
- cardId
- quantity
- aggregateValue
- createdAt
- updatedAt

#### CollectionItem
Einzelnes Exemplar innerhalb oder außerhalb eines Stapels.
- id
- stackId
- condition
- language
- foilVariant
- notes
- addedAt
- isDetached

#### ScanJob
- id
- sourceType: camera / photoLibrary
- localStatus / syncStatus
- extractedTextOrFeatures
- matchConfidence
- matchedCardId
- failureReason
- createdAt

### Modellierungsprinzip
- Card = Katalogobjekt
- CollectionStack = gruppierte Besitzansicht
- CollectionItem = einzelnes Exemplar mit sammlerspezifischen Eigenschaften

Das ist die sauberste Struktur, weil sie Stapel-UX erlaubt und zugleich spätere Differenzierung nach Zustand oder Variante ermöglicht.

## 6. UI/UX-Prinzipien & Accessibility-Vorgaben

### Hauptnavigation im MVP
- Sammlung
- Scannen
- Kartendetail
- Profil / Einstellungen

### UX-Prinzipien
- sehr visuell
- geringe Eingabelast
- schnelle Erfolgsrückmeldung
- klare Bestätigung vor Persistierung
- einfache Standardsicht, tiefere Details erst im zweiten Schritt

### Scan-Flow
1. Karte fotografieren oder Bild wählen
2. Analyse läuft
3. Treffer oder kleine Trefferliste
4. Detailvorschau mit:
   - Kartenbild
   - Seltenheit
   - Preis
5. Zustand/Menge prüfen
6. Speichern bestätigen

### Offline-Verhalten
- Sammlung lokal weiterhin ansehbar
- Scan kann gestartet werden
- falls keine Verbindung zum Server besteht, klare UI-Fehlermeldung
- Preisaktualisierung nur online

### Accessibility
- Dynamic Type unterstützen
- ausreichend Kontrast
- VoiceOver-kompatible Beschriftungen
- keine rein farbbasierte Statuskommunikation
- klare Touch Targets
- lokalisierte UI-Texte in Deutsch und Englisch

### Tonalität
- zugänglich für Kinder
- aber visuell modern genug für erwachsene Fans
- eher „friendly collector app“ als „Kinderspiel-App“

## 7. Security & Compliance-Aspekte

### Datenschutz / DSGVO
- Datensparsame Voreinstellungen
- keine Pflicht zur Kontoerstellung
- Bilder standardmäßig nicht dauerhaft speichern
- nur notwendige Metadaten persistieren
- Privacy by Design
- klare Einwilligung für Analytics
- einfache Lösch- und Exportpfade vorsehen

### PokéWallet-Sicherheit
- API-Key ausschließlich serverseitig halten
- keine direkten Schlüssel im Client
- Fehler- und Rate-Limit-Handling im Backend berücksichtigen

### Auth / Account Security
- Sign in with Apple
- Google Login
- E-Mail-basierter Login
- sichere Session-Verwaltung
- später erweiterbar um Mail-Verifikation / Passwort-Reset

### Analytics
Empfehlung: Analytics nicht im ersten Build priorisieren, sondern datensparsam nachziehen.
Wenn PostHog eingesetzt wird:
- bevorzugt EU-Hosting oder Self-Hosting
- IP-Erfassung minimieren/deaktivieren
- Consent sauber abbilden
- sensible Properties filtern
- standardmäßig nur produktrelevante Ereignisse erfassen

## 8. Nicht-funktionale Anforderungen (NFRs)

### Performance
- Scan-Feedback soll zügig sein
- Collection-Views müssen auch bei größeren Sammlungen flüssig bleiben
- Filter und Sortierungen dürfen sich nicht träge anfühlen

### Verfügbarkeit
- lokale Kernfunktionen sollen auch ohne Login und offline nutzbar bleiben
- serverseitige Preis- und Kartendaten sind onlineabhängig

### Zuverlässigkeit
- unsichere Erkennungen müssen klar als unsicher behandelt werden
- kein stilles Speichern falscher Treffer
- robuste Fehlerzustände bei Netzwerkproblemen

### Skalierbarkeit
- Architektur soll später Android und Web unterstützen
- Backend muss zusätzliche Clients ohne Domänen-Neudesign aufnehmen können

### Wartbarkeit
- modulare Domänentrennung:
  - Scan
  - Card Catalog
  - Collection
  - Auth
  - Pricing
- bevorzugt klarer Monolith statt früher Service-Zersplitterung

## 9. Entwicklungsphasen und Meilensteine

### Phase 0: Produktdefinition
- PRD finalisieren
- User Flows skizzieren
- Informationsarchitektur festziehen
- erste Wireframes erstellen

### Phase 1: Prototyp
- Kamera-/Fotoimport
- OCR-/Vision-Experiment
- Lookup-Prototyp gegen PokéWallet über Backend
- Trefferbestätigung testen

### Phase 2: MVP
- Gastmodus
- Sammlung lokal speichern
- Karten scannen und speichern
- Stapelmodell
- Zustand erfassen
- Filter/Sortierung
- Gesamtwert
- zweisprachige UI
- optionaler Login

### Phase 3: MVP+
- Sync für eingeloggte Nutzer
- Konfliktbehandlung lokal ↔ Cloud
- verbesserte Preisdarstellung
- Preisaktualisierung im Hintergrund bei Online-Verbindung

### Phase 4: v2.0
- Android-App
- Web-Frontend
- Wunschliste / Tauschliste
- Preisverlauf
- richer analytics
- geteilte Sammlungen

## 10. Potenzielle technische Herausforderungen & Lösungsansätze

### 1. Ungenaue Kartenerkennung
Risiko: falsche Zuordnung
Mitigation: Lookup mit Name + Kartennummer + Set-Hinweisen; Trefferliste bei Unsicherheit; kein automatisches blindes Speichern

### 2. API-Limits und externe Abhängigkeit
Risiko: Rate Limits, Ausfälle, höhere Latenz
Mitigation: serverseitiges Caching, Retry-Strategie, Fehler-UI, lokale Datenhaltung bereits erkannter Karten

### 3. Stapel vs. Einzelkarte
Risiko: UX wird unklar
Mitigation: Standard = Stapel, Erweiterung = „aus Stapel herauslösen“, Datenmodell von Anfang an dual auslegen

### 4. Offline-/Sync-Konflikte
Risiko: Dubletten oder widersprüchliche Mengen
Mitigation: klare Merge-Regeln, serverseitige Konfliktlogik, lokales Änderungsprotokoll

### 5. DSGVO und Analytics
Risiko: zu frühe, zu invasive Datenerfassung
Mitigation: Analytics minimal starten, Consent-Management, keine sensiblen Rohdaten, EU-Hosting/Self-Hosting prüfen

### 6. Self-Hosting-Operations
Risiko: Deployment-, Backup- und Wartungsaufwand
Mitigation: MVP-Infrastruktur bewusst klein halten, Backups und Monitoring früh automatisieren, klare Betriebsgrenzen definieren

## 11. Zukünftige Erweiterungsmöglichkeiten

- Preisverlauf
- Portfolio-/Sammlungsentwicklung über Zeit
- Wunschliste
- Tauschliste
- öffentliche oder private Collection-Sharing-Links
- Familienmodus
- Scanner für mehrere Karten nacheinander
- Bulk-Erfassung für häufige Karten
- Benachrichtigungen bei Wertänderungen
- Android-App
- Web-App / Webview
- Community-Features nur nach bewusster Produktentscheidung

## 12. Empfehlungen des Product Managers

### Klare Best-Practice-Empfehlungen
- Backend von Anfang an vorsehen
- Gastmodus zuerst
- Konto optional
- modularer Monolith statt Microservices
- Stapel als Standardmodell
- CollectionItem im Datenmodell trotzdem früh mitdenken
- Analytics nur datensparsam und bewusst
- iOS zuerst, aber Backend plattformoffen modellieren
- Erkennung nie blind vollautomatisch speichern

### Wichtigster MVP-Fokus
Das Produkt gewinnt oder verliert nicht am „wie viele Features“, sondern an drei Dingen:

1. Scan fühlt sich zuverlässig an
2. Sammlung bleibt übersichtlich
3. Speichern und Wiederfinden sind extrem einfach

Wenn diese drei Dinge sitzen, ist das Produkt schon wertvoll.

## 13. Konkrete User Flows

### Flow 1: Gastnutzer scannt und speichert eine Karte
1. Nutzer öffnet die App
2. Nutzer landet in der Sammlungsübersicht oder im Scan-Bereich
3. Nutzer tippt auf Scannen
4. Nutzer fotografiert eine Karte oder wählt ein Bild aus der Mediathek
5. App analysiert das Bild
6. Backend gleicht erkannte Merkmale mit Kartendaten ab
7. App zeigt:
   - Kartenbild
   - Kartenname
   - Seltenheit
   - Preis
   - ggf. mehrere Treffer bei Unsicherheit
8. Nutzer bestätigt die richtige Karte
9. Nutzer kann optional Zustand wählen und Anzahl festlegen
10. Nutzer tippt auf Speichern
11. Karte wird lokal gespeichert
12. Sammlung aktualisiert sich und zeigt den Stapel bzw. erhöht die Menge

### Flow 2: Bereits vorhandene Karte erneut scannen
1. Nutzer scannt eine Karte
2. App erkennt, dass diese Karte bereits in der Sammlung existiert
3. App zeigt einen Hinweis: „Diese Karte ist bereits in deiner Sammlung“
4. Nutzer bekommt Optionen:
   - Zum Stapel hinzufügen
   - Als eigenes Exemplar speichern
5. Standardaktion ist Zum Stapel hinzufügen
6. Menge des Stapels wird erhöht

### Flow 3: Karte aus Stapel herauslösen
1. Nutzer öffnet einen Kartenstapel
2. Detailansicht zeigt Gesamtmenge und exemplarbezogene Attribute
3. Nutzer wählt Exemplar herauslösen
4. App reduziert die Stapelmenge um 1
5. Neues einzelnes Collection Item wird erstellt
6. Nutzer kann für dieses Exemplar eigene Eigenschaften pflegen, z. B. Zustand

### Flow 4: Gastnutzer erstellt ein Konto und synchronisiert
1. Nutzer verwendet die App zunächst ohne Konto
2. Nutzer öffnet Profil / Einstellungen
3. Nutzer wählt E-Mail, Apple oder Google
4. Nach erfolgreichem Login erkennt das System lokale Sammlungsdaten
5. App bietet an: Lokale Sammlung mit Konto verknüpfen
6. Daten werden zum Backend synchronisiert
7. Nutzer erhält Bestätigung, dass die Sammlung künftig geräteübergreifend verfügbar ist

### Flow 5: Offline-Nutzung
1. Nutzer öffnet die App ohne Internet
2. Sammlung lädt aus lokalem Speicher
3. Nutzer kann Karten ansehen, suchen, filtern und sortieren
4. Nutzer startet Scan
5. Bildanalyse lokal läuft an
6. Sobald Serverabgleich nötig wäre, erscheint ein klarer Hinweis: „Zur Kartenerkennung wird gerade eine Internetverbindung benötigt.“
7. Nutzer kann später erneut versuchen

## 14. Screen-Liste für SwiftUI

1. Onboarding / Welcome
2. Sammlung Home
3. Scan Screen
4. Scan Result Screen
5. Match Selection Screen
6. Add/Edit Collection Item Screen
7. Card Detail Screen
8. Filter & Sort Sheet
9. Profil / Einstellungen
10. Error / Empty States

## 15. Feature-Priorisierung nach Must / Should / Could

### Must Have
- iOS-App mit SwiftUI
- Gastmodus ohne Login
- optionaler Login
- Scan per Fotoaufnahme
- Bildauswahl aus Mediathek
- Erkennung über Bildanalyse + API-Lookup
- Trefferbestätigung vor Speicherung
- Anzeige von Kartenbild, Seltenheit und Preis
- lokale Sammlung
- Stapelmodell mit Menge
- mehrfaches Scannen zur Mengenerhöhung
- manuelles Setzen der Anzahl
- Zustand pflegbar
- Karten aus Stapel herauslösen
- Sammlung durchsuchen
- Filter/Sortierung nach Set, Seltenheit, Typ, Wert
- Gesamtwert der Sammlung
- Deutsch / Englisch
- klare Offline-Fehlermeldungen
- serverseitige Kapselung der PokéWallet-Zugriffe

### Should Have
- Sync zwischen lokal und Konto
- Merge lokaler Sammlung beim späteren Login
- Preisaktualisierung mit Zeitstempel
- bessere Empty States
- schnelle Bulk-UX für häufige Karten
- Basis-Analytics mit Consent
- Caching häufig angefragter Kartendaten im Backend

### Could Have
- Preisverlauf
- Wunschliste
- Tauschliste
- Collection-Sharing
- Familienmodus
- Android-App
- Web-App / Webview
- Push-Benachrichtigungen bei Preisänderungen
- Community-Funktionen

## 16. Roadmap für 4–6 Entwicklungswochen

### Woche 1: Produkt- und UX-Fundament
- Informationsarchitektur finalisieren
- Kernflows festzurren
- erste Wireframes erstellen
- Domänenmodell definieren

### Woche 2: App-Grundgerüst + lokales Modell
- SwiftUI-App-Struktur aufsetzen
- lokale Persistenz vorbereiten
- Sammlungsscreens anlegen
- Filter-/Sortierlogik vorbereiten

### Woche 3: Scan-Prototyp + Lookup-Kette
- Kamera-/Fotoimport integrieren
- Bildanalyse/OCR-Kette validieren
- BFF-Endpunkt für Kartensuche bauen
- Treffer- und Fehlerszenarien testen

### Woche 4: Speichern, Stapel, Zustand
- bestätigte Karten speichern
- Stapellogik implementieren
- mehrfache Scans und Mengenerhöhung
- Zustand pflegbar machen
- herauslösen von Exemplaren vorbereiten oder umsetzen

### Woche 5: Konten, Sync-Vorbereitung, Stabilisierung
- optionale Auth integrieren
- Gastmodus sauber halten
- Kontoübergang definieren
- Offline- und Fehlerzustände absichern

### Woche 6: Polish + Beta-Readiness
- Deutsch/Englisch
- Accessibility-Basics
- UI-Polish
- Datenschutz-/Consent-Basis
- Beta-Test mit kleinem Nutzerkreis

## 17. Umsetzungsempfehlung für deinen Start

1. Wireframes für 5 Kernscreens
   - Sammlung
   - Scan
   - Trefferbestätigung
   - Kartendetail
   - Profil

2. Domänenmodell finalisieren
   - Card
   - CollectionStack
   - CollectionItem
   - User
   - ScanJob

3. Technischen Spike bauen
   - Wie gut funktioniert die Bildanalyse auf echten Pokémon-Karten?
   - Welche Felder lassen sich robust extrahieren?
   - Wann braucht es die Trefferliste?

4. BFF zu PokéWallet definieren
   - Search
   - Card detail
   - Caching
   - Error handling

5. Erst dann UI-Polish und Analytics

## 18. Offene Entscheidungen für die nächste Iteration

- Soll der Gesamtwert eher auf Stack-Ebene oder Exemplar-Ebene berechnet werden?
- Wie sichtbar soll der Zustand in der Sammlungsansicht sein?
- Brauchst du im MVP schon Bulk-Aktionen wie „Anzahl schnell erhöhen“?
- Wie soll der Gast-zu-Konto-Merge genau aussehen?
- Soll die App optisch eher Pokémon-inspiriert oder eher neutral-modern auftreten?

