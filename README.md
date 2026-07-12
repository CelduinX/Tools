<div align="center">

# 🧰 Tools

**Kleine Hilfswerkzeuge, schnelle Installationen und automatisierte Setups.**

Ein Befehl genügt – das jeweilige Skript erledigt den Rest.

</div>

---

## 📋 Übersicht

| Tool | Plattform | Beschreibung |
| --- | --- | --- |
| [🎮 Hytale auf Deutsch](#-hytale-auf-deutsch) | Windows | Installiert die deutschen Sprachdateien für Hytale automatisch. |
| [🐳 Automatic Docker Setup](#-automatic-docker-setup) | Ubuntu Server | Aktualisiert Ubuntu und richtet Docker automatisiert ein. |

---

## 🎮 Hytale auf Deutsch

Installiert die deutsche Community-Übersetzung automatisch im richtigen Hytale-Verzeichnis. Vorhandene Sprachdateien werden ersetzt und der Download wird vor der Installation per SHA-256 geprüft.

### ⚡ Schnellinstallation

1. Hytale vollständig schließen.
2. Rechtsklick auf das Windows-Startmenü und **Terminal (Administrator)** auswählen.
3. Diesen Befehl einfügen und mit `Enter` ausführen:

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1|iex
```

➡️ [Ausführliche Anleitung und weitere Hinweise](Hytale/README.md)

---

## 🐳 Automatic Docker Setup

Bereitet einen Ubuntu Server für Docker vor. Das Skript aktualisiert die Systempakete, installiert Docker aus dem offiziellen Repository und richtet die gewünschten Datenverzeichnisse ein.

### ⚡ Schnellinstallation

Den folgenden Befehl auf einem Ubuntu Server ausführen:

```bash
curl -fsSL https://raw.githubusercontent.com/CelduinX/Tools/refs/heads/main/Docker/setup-ubuntu-docker.sh | sudo DOCKER_BASE_DIR=/opt/docker bash
```

> [!NOTE]
> Mit `DOCKER_BASE_DIR=/opt/docker` wird das Basisverzeichnis festgelegt. Der Pfad kann vor dem Ausführen angepasst werden.

➡️ [Docker-Setup-Skript ansehen](Docker/setup-ubuntu-docker.sh)

---

## ⚠️ Hinweis

Bitte Skripte vor der Ausführung prüfen und nur auf Systemen verwenden, für die sie vorgesehen sind.

<div align="center">

**Viel Spaß mit den Tools! 🚀**

</div>
