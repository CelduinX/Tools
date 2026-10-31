# Hytale auf Deutsch

Der PowerShell-Einzeiler installiert das vollständige **Deutsche Sprachpaket 2.0.1 für Hytale 0.7**: Spieltexte, Avatar-Optionen und Menüsprache.

Quelle: [Deutsches Sprachpaket von EinfachNurTeo auf CurseForge](https://www.curseforge.com/hytale/translations/deutsches-sprachpaket/files/9261557), veröffentlicht am 19.10.2026. Dies ist die neueste stabile Release-Version; die neuere 2.1.0 ist eine Beta für Hytale 0.8 und wird hier nicht installiert.

## Installation

1. Hytale vollständig schließen.
2. PowerShell oder Windows-Terminal mit PowerShell öffnen. Administratorrechte sind nicht erforderlich.
3. Den folgenden Befehl vollständig kopieren, einfügen und mit `Enter` ausführen:

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1|iex
```

Danach Hytale starten und unter **Settings → Language → Deutsch** auswählen. Für die Spieltexte muss die Mod in der jeweiligen Spielwelt aktiviert sein.

## Was macht der Befehl?

Das Installationsskript lädt `Deutsches_Sprachpaket-2.0.1-komplett.zip` aus diesem Repository herunter, prüft die SHA-256-Prüfsumme und entpackt das Archiv in einen zufälligen temporären Ordner. Es prüft die benötigten Dateien, bevor es die Installation verändert.

- Die unveränderte Mod-ZIP wird als `%APPDATA%\Hytale\UserData\Mods\Deutsches_Sprachpaket.zip` installiert.
- Der Inhalt von `Menuesprache\de-DE` wird nach `%APPDATA%\Hytale\install\release\package\game\latest\Client\Data\Shared\Language\de-DE` kopiert.
- Vorhandene Dateien mit gleichem Namen werden überschrieben. Andere Mods und Dateien werden nicht gelöscht.
- Temporäre Downloads und entpackte Dateien werden anschließend entfernt, auch bei einem Fehler.

SHA-256 des Originalarchivs:

```text
95418AD6EDB2B218B2EF6C941DCFAB8C9D2879760A0FE1BA13C3F519032EFBAC
```

## Aktualisieren oder erneut installieren

Den Einzeiler erneut ausführen. Die Mod wird unter demselben Dateinamen ersetzt und die Menüsprache erneut kopiert. Nach einem größeren Hytale-Update kann dies erneut nötig sein.

Falls dasselbe Sprachpaket bereits über CurseForge oder manuell unter einem anderen ZIP-Dateinamen installiert ist, vorab die doppelte Installation entfernen. Andere Übersetzungsmods können ebenfalls Konflikte verursachen.

## Hinweise

- Nur unter Windows mit PowerShell verwenden.
- Die Installation betrifft den aktuell angemeldeten Windows-Benutzer unter `%APPDATA%\Hytale`.
- Auf einem fremden Multiplayer-Server müssen die serverseitigen Spieltexte dort installiert sein.
- Die Übersetzung ist ein Community-Projekt von EinfachNurTeo und keine offizielle Hytale-Veröffentlichung.
