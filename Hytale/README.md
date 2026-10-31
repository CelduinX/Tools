<div align="center">

# 🎮 Hytale auf Deutsch

### Dein Abenteuer. Deine Sprache. 🇩🇪

Deutsche Menüs, Gegenstände und Spieltexte — in wenigen Schritten startklar.

**Windows** &nbsp;•&nbsp; **Hytale 0.7** &nbsp;•&nbsp; **Sprachpaket 2.0.1**

[🚀 Loslegen](#installation) &nbsp;·&nbsp; [❓ Hilfe](#hilfe) &nbsp;·&nbsp; [💛 Credits](#credits)

</div>

---

<a id="installation"></a>

## 🚀 So geht’s

> [!IMPORTANT]
> Für **Hytale 0.7 unter Windows**. Schließe Hytale, bevor du beginnst.

**1. „Ausführen“ öffnen**

Drücke gleichzeitig <kbd>Windows</kbd> + <kbd>R</kbd>.

**2. Befehl kopieren und starten**

Kopiere die **gesamte Zeile** in das Feld „Öffnen“ und drücke <kbd>Enter</kbd>.

```text
powershell.exe -NoProfile -Command "try{irm https://raw.githubusercontent.com/CelduinX/Tools/main/Hytale/install.ps1 -ea Stop|iex}catch{Write-Host $_ -ForegroundColor Red};Read-Host 'Enter zum Schliessen'"
```

**3. Installation abwarten**

PowerShell öffnet sich und installiert das Sprachpaket automatisch. Du siehst jeden Schritt und am Ende **„Fertig! Dein Sprachpaket ist installiert.“**

Das Fenster bleibt geöffnet. Lies das Ergebnis und drücke anschließend **Enter**, um es zu schließen. Auch bei einem Fehler bleibt die Meldung sichtbar.

> [!TIP]
> Du brauchst keine Administratorrechte. Die Installation läuft automatisch. Warte bitte bis zur Abschlussmeldung.

---

## 🇩🇪 Deutsch auswählen

1. Starte Hytale.
2. Öffne **Settings → Language** und wähle **Deutsch**.
3. Aktiviere das **Deutsche Sprachpaket** für deine Spielwelt.

**Auf ins nächste Abenteuer!** 🗺️

---

## 🔄 Erneut installieren

Deutsch fehlt nach einem Hytale-Update? Schließe das Spiel und führe den Befehl oben erneut aus. Dein Sprachpaket wird wieder eingerichtet.

Die hier angebotene Übersetzung ist für **Hytale 0.7** gedacht. Prüfe bei einer neuen Spielversion zuerst den Versionshinweis oben.

---

<a id="hilfe"></a>

## ❓ Hilfe

<details>
<summary><strong>Das PowerShell-Fenster öffnet sich nicht.</strong></summary>

Prüfe deine Internetverbindung und kopiere den vollständigen Befehl erneut in **Windows + R**. Warte nach dem Start einen kurzen Moment. Wird ein Fehler angezeigt, versuche es später noch einmal.

</details>

<details>
<summary><strong>Die Installation meldet einen Fehler.</strong></summary>

Lies die Meldung im PowerShell-Fenster. Lass Hytale geschlossen und prüfe deine Internetverbindung sowie den freien Speicherplatz. Bestätige dann mit **Enter** und führe den Befehl erneut aus.

Falls du weitere Hilfe brauchst, [melde das Problem hier](https://github.com/CelduinX/Tools/issues). Nenne deine Hytale-Version und die angezeigte Meldung.

</details>

<details>
<summary><strong>„Deutsch“ fehlt in der Sprachauswahl.</strong></summary>

Schließe Hytale vollständig, führe die Installation erneut aus und starte das Spiel anschließend neu. Diese Installationshilfe ist für die normale Windows-Installation und Hytale 0.7 vorgesehen.

</details>

<details>
<summary><strong>Die Menüs sind deutsch, aber Spieltexte bleiben englisch.</strong></summary>

Prüfe, ob das **Deutsche Sprachpaket** für deine Spielwelt aktiviert ist. Zusätzliche Inhalte anderer Mods sind möglicherweise nicht übersetzt.

Auf einem fremden Multiplayer-Server entscheidet dessen Sprachpaket über die serverseitigen Spieltexte. Frage bei Bedarf das Serverteam.

</details>

<details>
<summary><strong>Ich habe bereits eine deutsche Übersetzung installiert.</strong></summary>

Verwende möglichst nur ein deutsches Sprachpaket gleichzeitig. Entferne eine bereits über CurseForge oder manuell installierte Ausgabe desselben Pakets, bevor du diese Installationshilfe verwendest. So vermeidest du doppelte Übersetzungen und Konflikte.

Wenn du diese Installationshilfe bereits verwendet hast, kannst du den Befehl einfach erneut ausführen.

</details>

---

<a id="credits"></a>

## 💛 Credits

Die Übersetzung stammt von **EinfachNurTeo**: [Deutsches Sprachpaket auf CurseForge](https://www.curseforge.com/hytale/translations/deutsches-sprachpaket).

Diese Installationshilfe wird von **CelduinX** bereitgestellt. Fehler in der Übersetzung kannst du direkt beim CurseForge-Projekt melden.

<div align="center">

*Von der Community für die Community. Keine offizielle Hytale-Veröffentlichung.*

</div>
