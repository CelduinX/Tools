<div align="center">

# 🧰 Tools

**Kleine Hilfswerkzeuge und automatisierte Setups.**

</div>

---

## 🎮 Hytale auf Deutsch

**Windows · Hytale 0.7** · Deutsche Menüs und Spieltexte mit automatischer Installation.

Hytale schließen, **Windows-Taste + R** drücken, die gesamte Zeile einfügen und mit **Enter** starten:

```text
powershell.exe -NoProfile -Command "try{irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1 -ea Stop|iex}catch{Write-Host $_ -ForegroundColor Red};Read-Host 'Enter zum Schliessen'"
```

PowerShell installiert das Sprachpaket automatisch und bleibt bis zur Bestätigung mit **Enter** geöffnet. Danach in Hytale unter **Settings → Language → Deutsch** die Sprache auswählen und das Sprachpaket für die Spielwelt aktivieren.

📖 [Schritt für Schritt & Hilfe](Hytale/README.md)

---

## 🐳 Automatic Docker Setup

**Ubuntu Server** · Aktualisiert das System und richtet Docker automatisch ein.

```bash
curl -fsSL https://raw.githubusercontent.com/CelduinX/Tools/main/Docker/install.sh | sudo bash
```

📄 [Skript ansehen](Docker/install.sh)

---

## 🖥️ PC-Prüfprotokoll

**Windows 10/11** · Prüft Hardware, Windows, Sicherheit, Datenträger und Netzwerk und erstellt ein professionelles, druckbares Prüfprotokoll.

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/PC-Pruefprotokoll/install.ps1|iex
```

Durchgeführte Tätigkeiten können beim Start eingegeben werden und erscheinen anschließend als Stichpunktliste im Bericht.

📖 [Download und Anleitung](PC-Pruefprotokoll/README.md)
