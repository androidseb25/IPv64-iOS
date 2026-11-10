# IPv64.net iOS 2.1.0 – Port der Android-App

Paritätsliste gegen Android 2.1.0. Status: ☐ offen · ◐ umgesetzt, nicht abgenommen · ☑ im Simulator mit Mock-API abgenommen · ✕ bewusst abweichend (siehe Abweichungen).

## 4.1 Start, Login, Accounts
| # | Punkt | Status |
|---|---|---|
| 1.1 | Welcome → Login mit API-Key-Feld und QR-Scanner | ☐ |
| 1.2 | Mehrere Accounts: Liste, wechseln, bearbeiten, entfernen (Removal-Regeln, Texte) | ☐ |
| 1.3 | Lockscreen per Face ID/Touch ID, schaltbar unter Mehr | ☐ |
| 1.4 | Nach erstem Login automatisch Push notifications (Account-ID vorher, einmal pro Account, nicht wenn erledigt/Kanal vorhanden) | ☐ |

## 4.2 Tabs
| # | Punkt | Status |
|---|---|---|
| 2.1 | DynDNS, Healthchecks, CDN64↔Proxy64 (cdn64-Modul), DNS64 (dns64-Modul), More | ☐ |
| 2.2 | Modul-Flags bei Start, Rückkehr in die App, Routenwechsel | ☐ |

## 4.3 DynDNS
| # | Punkt | Status |
|---|---|---|
| 3.1 | Liste: Filter All/DynDNS/Own, Status-Chip (IP matches/differs/No IP/Checking), Pull-to-Refresh | ☐ |
| 3.2 | Sheet New domain (Subdomain + Domain-Auswahl) | ☐ |
| 3.3 | Detail: Kopf mit Status, IP-Abweichung mit „auf aktuelle IP setzen“ | ☐ |
| 3.4 | Kacheln Copy update URL, DynDNS update, Settings | ☐ |
| 3.5 | Records bearbeiten/löschen, Sheet New DNS record (Name leer = Domain, Typ, Wert) | ☐ |
| 3.6 | Menü: Update-URL neu erzeugen (Screenshot-Schutz), Domain löschen | ☐ |
| 3.7 | Manual DynDNS update (IPv4/IPv6, My IPv4/IPv6, Präfix), Ergebnis als Sheet | ☐ |

## 4.4 Healthchecks
| # | Punkt | Status |
|---|---|---|
| 4.1 | Liste: Suche, Status-Filter, Account-Checks, Gruppe je verbundener Node | ☐ |
| 4.2 | Node-Status: Modul aus → Hinweis, fehlt → ausblenden, nicht erreichbar → Texte | ☐ |
| 4.3 | Eigentümer-Filter (Node-Gruppen / Account-Liste) | ☐ |
| 4.4 | „+“: Sheet Ziel Account oder Node (nicht erreichbare fehlen) | ☐ |
| 4.5 | Cloud-Detail: Kacheln Pause/Resume, Run now, Open in browser; Statistik, Events, Löschen | ☐ |
| 4.6 | Formular: Wesentliches oben, „Advanced“ und „Notifications & organisation“ einklappbar, lesbare Typen | ☐ |
| 4.7 | Node-Check-Detail: Kacheln, Statistik je Zeitraum, Incidents, Events, Edit/Delete Toolbar, unbekannter Typ → Edit aus, Jahr 0001 ausgeblendet | ☐ |
| 4.8 | Node-Check-Edit: Formular, Save/Delete in Toolbar | ☐ |

## 4.5 CDN64 / Proxy64
| # | Punkt | Status |
|---|---|---|
| 5.1 | CDN64 ohne Proxy-Node: Namen je Node, Gruppe „Old CDN“, Detail, Einstellungen, Hinzufügen als Sheet | ☐ |
| 5.2 | Proxy64 Statistik-Karte (Node-Kontingent, MB→GB/TB, 0/leer = ∞) | ☐ |
| 5.3 | Host-Zeilen mit Chips (ms, SSL-Tage, Optionen, „CDN64 · Mode N · x/y servers“, Zähler) | ☐ |
| 5.4 | Host-Editor: Toolbar Delete/Save, Kopfzeile, Kacheln, Sektionen, Advanced, Validierungsmeldung | ☐ |
| 5.5 | CDN64 einschalten: Modus 1/2 als Radio-Karten, Modus 3 Info, „Create healthcheck“ | ☐ |

## 4.6 DNS64
| # | Punkt | Status |
|---|---|---|
| 6.1 | Node-Auswahl-Chips bei mehreren Nodes | ☐ |
| 6.2 | Blocking-Karte: Dauer-Chips, „Pause blocking?“, Countdown (30 s / 1 s < 2 min), Reload bei Ablauf, „Resume“ | ☐ |
| 6.3 | Kennzahlen: 1 h/24 h/7 d, gleich hohe KPI-Kacheln, gestapeltes Balkendiagramm mit Details, Upstreams, Cache + Flush, Top-Listen | ☐ |
| 6.4 | Query log: 3-s-Polling nur im Vordergrund, Filter, Suche, Domain freigeben mit Rückfrage | ☐ |
| 6.5 | Local DNS records: Anlegen/Bearbeiten/Löschen im Sheet, noPtr/localOnly | ☐ |
| 6.6 | Nicht erreichbare Node: Fehlertext + Hinweis Mehr → Nodes | ☐ |

## 4.7 Mehr
| # | Punkt | Status |
|---|---|---|
| 7.1 | Gruppen und Reihenfolge, Icons mittig, Logout mit Abstand | ☐ |
| 7.2 | Nodes: Liste (Cloud + direkt), „Add node“ (Link node / Connect directly) | ☐ |
| 7.3 | Direct access: Adresse + Key, leerer Key behält gespeicherten, Normalisierung, rote Warnung | ☐ |
| 7.4 | Node-Detail: Spinner bis komplett, Live-Chip, Kacheln, Module mit Rückfrage, Checks, Logs, Details, Stift, Zugang vergessen, trennen, Befehle; keine DNS-Pause | ☐ |
| 7.5 | Channels, Channel setup, Verify channel, Notification settings | ☐ |
| 7.6 | Push notifications: 3 Schritte, Use existing / Create new, Test, Skip/Done, Token-Sync beim Start | ☐ |
| 7.7 | API keys: „New API key“-Sheet, Key nur einmal sichtbar | ☐ |
| 7.8 | Account links | ☐ |
| 7.9 | Honeypot: Netzwerkzahlen, Charts, eigener Anteil, Listen-Token (Rückfrage, maskiert, Screenshot-Schutz, bei Hintergrund verborgen); kein Live-Feed | ☐ |
| 7.10 | IP lookup & My IP | ☐ |
| 7.11 | Password check (lokal, k-Anonymität) | ☐ |
| 7.12 | Logs, About, YouTube, Discord | ☐ |

## 4.8 UX-Regeln
| # | Punkt | Status |
|---|---|---|
| 8.1 | Formulare/Auswahlen als Sheet mit Detents; kein Wegwischen während Anfrage; Verify channel/Push URL nie | ☐ |
| 8.2 | Bestätigungen/Löschen als Alert bzw. confirmationDialog | ☐ |
| 8.3 | Detail-Aktionen als Kacheln in einer Reihe | ☐ |
| 8.4 | Save/Delete in der Toolbar (Delete links, Save rechts, Save erst nach Laden) | ☐ |
| 8.5 | Spinner bis Screen vollständig | ☐ |

## iOS-spezifisch
| # | Punkt | Status |
|---|---|---|
| 9.1 | Healthcheck-Widget auf Healthchecks 2.0 über IPv64-SPM | ☐ |
| 9.2 | iOS 18.0 Deployment Target, Liquid Glass ab iOS 26 mit Fallback | ☐ |
| 9.3 | iPhone Duo / variable Fenstergröße, iPad Split View / Stage Manager | ☐ |
| 9.4 | Mock-API per `MOCK_API` (nur Debug) | ☐ |
| 9.5 | Keys im Keychain (Access Group mit Widget), Migration bestehender Accounts | ☐ |
| 9.6 | String Catalog `Localizable.xcstrings` | ☐ |

## Skills je Phase
(wird fortgeschrieben)

## Abweichungen von Android
(wird fortgeschrieben)

## Lücken in IPv64-SPM / SecNtfy-SPM
(wird fortgeschrieben)

## Offene Fragen
(wird fortgeschrieben)
