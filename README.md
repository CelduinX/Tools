# Tools

Eine Sammlung kleiner Hilfswerkzeuge und automatisierter Setups.

## Hytale auf Deutsch

Installiert die deutschen Sprachdateien automatisch unter Windows:

```powershell
irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1|iex
```

Eine ausführliche Anleitung und Hinweise gibt es unter [Hytale](Hytale/README.md).

## Automatic Docker Setup

```bash
curl -fsSL https://raw.githubusercontent.com/CelduinX/Tools/refs/heads/main/Docker/setup-ubuntu-docker.sh | sudo DOCKER_BASE_DIR=/opt/docker bash
```
