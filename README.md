<div align="center">

# 🧰 Tools

**Kleine Hilfswerkzeuge und automatisierte Setups.**

</div>

---

## 🎮 Hytale auf Deutsch

**Windows** · Installiert die deutsche Community-Übersetzung für Hytale.

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1|iex
```

📖 [Anleitung](Hytale/README.md)

---

## 🐳 Automatic Docker Setup

**Ubuntu Server** · Aktualisiert das System und richtet Docker automatisch ein.

```bash
curl -fsSL https://raw.githubusercontent.com/CelduinX/Tools/refs/heads/main/Docker/setup-ubuntu-docker.sh | sudo DOCKER_BASE_DIR=/opt/docker bash
```

📄 [Skript ansehen](Docker/setup-ubuntu-docker.sh)
