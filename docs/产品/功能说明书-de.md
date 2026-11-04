# AIBook Benutzerhandbuch

> **AIBook** (Projektkennung `ai-book`) ist ein natives Leseprogramm für macOS: Die **linke Seite** liest und bearbeitet lokalen Text, die **rechte Seite** nutzt KI für Erklärung, Übersetzung, Vorlesen und (optional) ein Upgrade der App selbst.  
> **System**: macOS 13 oder neuer.  
> **Zweck**: Wortlaut, Zusammenhang und eine Übersetzung neben dem Original verständlich machen und ungestört lesen. Kein Ersatz für ein vollständiges E-Book-Programm.

Das Handbuch in der App folgt der Oberflächensprache. Diese Datei ist die deutsche Fassung. Vereinfachtes Chinesisch ist `功能说明书.md`; die übrigen Fassungen liegen im selben Ordner als `功能说明书-en.md`, `功能说明书-ja.md`, `功能说明书-fr.md`, `功能说明书-it.md`, `功能说明书-la.md` und `功能说明书-el.md`. Nach einer Änderung die gleichnamige Datei nach `Sources/AIBook/Resources/` kopieren, bevor Sie paketieren.

---

## So öffnen Sie es in der App

- Menüleiste **Hilfe → AIBook Benutzerhandbuch** (Fenster in der App; Text lässt sich markieren und kopieren)
- **Hilfe → Handbuch im Finder zeigen** (wählt die Handbuchdatei der aktuellen Sprache)
- **In Standard-App öffnen** in der Titelleiste des Handbuchfensters
- Die Schaltfläche **Handbuch** in der Titelleiste von **Book-Einstellungen** und **Evolutions-Einstellungen**

---

## 1. Überblick

### 1.1 Was Sie tun können

- Eine lokale `.txt`-Datei auf der linken Seite lesen und bearbeiten.
- Eine Auswahl oder den ganzen Text erklären lassen und in demselben Gespräch nachfragen.
- Wort für Wort oder absatzweise übersetzen und eine Gegenüberstellung sehen.
- Original, Übersetzung oder Erklärung vorlesen lassen.
- In den Lesemodus wechseln und wie in einem aufgeschlagenen Buch blättern.
- Optional die KI-Evolution nutzen: das Projekt analysieren, einen Eintrag aus der Warteschlange anwenden und die App neu bauen.

### 1.2 Der Schreibtisch

Das Fenster ist ein Schreibtisch. Links liegt das Original, rechts der Assistent. Der Lesemodus blendet den Assistenten aus und zeigt ein Buch, das Sie umblättern.

### 1.3 Zwei übergeordnete Modi

| Modus | Wofür |
|-------|--------|
| **Lernmodus** | Original links; Erklärung, Übersetzung und Vorlesen rechts |
| **Lesemodus** | Ruhiges Blättern. Erklärung und Übersetzung erst nach der Rückkehr |

Wechsel in der Titelleiste: **Lesemodus** (⌘⇧P) und **Lernmodus**.

---

## 2. Hauptfenster (Lernmodus)

Die Titelleiste enthält Dokument, Erklärung, Übersetzung, Vorlesen, Layout und Einstellungen. Links steht das Original. Rechts ist der Leseassistent, oder **KI-Evolution**, wenn dieser Tab gewählt ist.

### 2.1 Layout

| Layout | Bedeutung |
|--------|-----------|
| **Doppelseite** | Linke und rechte Seite nebeneinander |
| **Original im Vollbild** | ⌘⌥2. Das Original füllt den Schreibtisch |
| **Rechts Vollbild** | ⌘⌥3. Der Assistent füllt den Schreibtisch |

**Esc** stellt die Doppelseite wieder her.

### 2.2 Bereiche im Leseassistenten

| Bereich | Inhalt |
|---------|--------|
| **Erklärung** | Gespräch über mehrere Runden, fortlaufende Ausgabe, Sichern / Öffnen / Leeren |
| **Übersetzung** | Übersetzungs-JSON oder Vergleichstabelle, bearbeitbar, mit Ausrichten und Sperren |

Die Kapseln **Erklärung** / **Übersetzung** in der Titelleiste wechseln den Bereich. Eine Übersetzungsaktion wechselt selbst dorthin.

### 2.3 Konzentration

Erklärung und Übersetzung können die Leiste und die Eingabe ausblenden. Zurückholen: **Fokus Lesen**, **Symbolleiste anzeigen** und **Eingabe anzeigen**.

---

## 3. Lesemodus

### 3.1 Eintritt und Austritt

| Aktion | Wie |
|--------|-----|
| Eintreten | Titelleiste **Lesemodus**, Kürzel **⌘⇧P** (ein nicht leeres Original muss offen sein) |
| Verlassen | **Lesemodus beenden** oder **Esc** |

Im Lesemodus gibt es keine Erklärung und keine Übersetzung. Wechseln Sie zurück, wenn Sie die KI brauchen.

### 3.2 Layout

| Option | Bedeutung |
|--------|-----------|
| **Doppelseite** | Links Seite N, rechts Seite N+1. Der **Buchrücken bleibt fest** |
| **Vollbild** | Eine Seite füllt das Fenster |
| Wechsel | **Doppelseite / Vollbild** in der Lesetitelleiste, oder **⌘⌥1 / ⌘⌥2** |

### 3.3 Blättern

| Geste | Verhalten |
|-------|-----------|
| **← / →** | Vorherige Doppelseite / nächste Doppelseite |
| **Linke / rechte Seite anklicken** | In der Doppelseite vor / zurück |
| **Waagerecht ziehen** | Folgt der Hand. Nach etwa einem Drittel blättert die Seite zu Ende, sonst springt sie zurück |
| **Pfeile in der Titelleiste** | Wie die Tastatur |

Die Animation biegt **ein Blatt**. Der Rücken verformt sich nicht.

### 3.4 Seiten und Fortschritt

- Die Seiteneinteilung nutzt dieselben **Größe, Schrift, Zeilenabstand und Ränder** wie die linke Seite (**Book-Einstellungen → Erscheinungsbild**).
- Ändert sich das Fenster oder der Satz, wird **neu umbrochen**, und die Stelle bleibt möglichst erhalten.
- Jede Datei merkt sich den **Doppelseiten-Index**. Der Lesemodus stellt ihn wieder her.
- Die Fußzeile zeigt etwa **Seite 3–4 von 128** (Doppelseite) oder **Seite N von M** (Vollbild).

---

## 4. Dokumente und Dateien

### 4.1 Dateitypen

- Das Hauptformat ist **UTF-8-Klartext `.txt`**.
- Die linke Seite ist **frei bearbeitbar**. Sie können markieren, kopieren und eine Datei auf das Fenster ziehen.

### 4.2 Dateimenü und Original

| Aktion | Kürzel | Hinweis |
|--------|--------|---------|
| **Neues Original** | ⌘N | Linke Seite leeren und neu beginnen |
| **Original öffnen…** | ⌘O | Eine lokale `.txt`. In der Titelleiste: **Original öffnen** |
| **Ordner des Originals öffnen…** | | Siehe 4.4. In der Titelleiste: **Ordner des Originals öffnen** |
| **Original sichern** | ⌘S | Unter dem aktuellen Pfad sichern |
| **Original sichern unter…** | ⌘⇧S | Die linke Seite als neue Datei |
| **Original als AIBook sichern…** | | Original samt vorhandener Übersetzungen und Erklärungen als `.aibook` |
| **Auswahl des Originals exportieren…** | ⌘⌥S | Nur die aktuelle Auswahl |
| **Gesamtes Original wählen** | ⌘⌃A | |
| **Original ergänzen** | ⌘⇧C | Siehe Abschnitt 9 |

Ohne externe Datei lädt die linke Seite die **Befehlsnotizen** (siehe 4.3).

### 4.3 Befehlsnotizen (vorbesetzte linke Seite)

- Beim ersten Start oder ohne geöffnete Datei zeigt die linke Seite Notizen für eigene Bemerkungen oder älteren Evolutionstext.
- Gespeichert unter `~/Library/Application Support/AIBook/readme-notes.txt`.
- Fehlt die lokale Kopie, fällt die App auf die eingebaute oder die `readme.txt`-Vorlage im Projekt zurück.
- **⌘S** sichert die Notizen in Application Support.

> Die **Optimierungswarteschlange** ist `optimization-queue.json`. Die Notizen sind nicht mehr die Befehlsquelle der Evolution, bleiben aber ein persönliches Blatt.

### 4.4 Ordnerbrowser (Bibliothek)

**Einstieg**: **Ordner des Originals öffnen…**. Der Fenstertitel ist **Ordnerbrowser**. Die Seitenleiste heißt **Geöffnete Ordner**.

| Schritt | Was geschieht |
|---------|----------------|
| Ordner hinzufügen | **+** in der Seitenleiste, dann den Buchstamm wählen |
| Ordner wechseln | In der Liste der geöffneten Ordner wählen |
| Durchsehen | Unterordner im mittleren Baum aufklappen |
| Ziel wählen | **Im Originalbereich links öffnen**, **Im Übersetzungsbereich rechts öffnen**, **Im Erklärungsbereich rechts öffnen** |
| Öffnen | Doppelklick oder unten bestätigen |

Hinzugefügte Ordner und ihr aufgeklappter Zustand werden **gespeichert**. So wechseln Sie in einer Bibliothek zwischen `.txt`, `-翻译.txt` und Erklärungsentwürfen.

---

## 5. KI-Anbindung und Einstellungen

Erklärung, Übersetzung und **Original ergänzen** nutzen das Buchmodell in **Book-Einstellungen**. Die KI-Evolution verwendet fest Cursor, in den **Evolutions-Einstellungen**. In der Titelleiste gibt es keinen Umschalter.

### 5.1 Buchmodell zum Lesen, Cursor für die Evolution

| Verwendung | Steuerung |
|------------|-----------|
| Erklären, übersetzen, Original ergänzen | **Book-Einstellungen** → **KI-Modelle** → **Aktiver Anbieter** |
| **Analysieren** und **Evolution** | **Cursor-Modell** in den **Evolutions-Einstellungen** |

Die Titelleistenkapsel zeigt den Dateinamen und **Ungesichert**. Fehlt das Buchmodell, sagt sie **Book-LLM fehlt**. Ist Cursor nicht bereit, sagt sie **Cursor nicht bereit**.

### 5.2 Book-Einstellungen

**Einstieg**: die Schaltfläche **Book-Einstellungen** in der Titelleiste.

#### Modell

- Adresse, Schlüssel und Standardmodell werden **je Anbieter** gespeichert.
- Eingebaute Beispiele:

| Anbieter | Typische Verwendung |
|----------|---------------------|
| OpenAI | GPT-Modelle in der Cloud |
| DeepSeek | Günstigeres Chinesisch |
| Ollama | **Kostenlos auf diesem Mac** (für das tägliche Lesen empfohlen) |
| Moonshot / Qwen / Zhipu | Cloud-Modelle in China |
| Benutzerdefiniert | Jeder OpenAI-kompatible Endpunkt |

**Ollama, kurzer Start**:

```bash
ollama serve
ollama pull llama3.2
```

Wählen Sie Ollama in den Book-Einstellungen und **suchen Sie die auf diesem Mac installierten Modelle**. Verlangt Ollama einen API-Schlüssel, tragen Sie ihn dort ein.

- **Übersetzungssprachen** und **Erklärungssprachen**: Sie können mehrere aus Vereinfachtem Chinesisch, Englisch, Japanisch, Deutsch, Französisch, Italienisch, Latein oder Griechisch wählen. Der nächste Lauf erzeugt sie in der angekreuzten Reihenfolge. Vorhandene Ergebnisse bleiben auf der rechten Seite und lassen sich umschalten. Eine `.aibook`-Datei behält alle.
- **Auszugsanteil links**: wie viel Original der linken Seite jede Anfrage mitnimmt, damit das Fenster des Modells nicht überläuft.

#### Sprache

Siehe Abschnitt 8.

#### Erscheinungsbild

Siehe Abschnitt 11.

### 5.3 Evolutions-Einstellungen

**Einstieg**: Menü **AIBook → Einstellungen** (Tab Evolution).

| Einstellung | Bedeutung |
|-------------|-----------|
| Cursor-API-Schlüssel | Oder die Umgebungsvariable `CURSOR_API_KEY` |
| Cursor-Modell | Zum Beispiel ein Composer-Modell |
| Pfad zu cursor-bridge | Das Verzeichnis `cursor-bridge` im Projekt |
| **Auto-Upgrade** | Nach einem Klick auf **Evolution** können weitere Einträge nacheinander laufen (siehe Abschnitt 10) |

**Lokale Cursor-Abhängigkeit**:

```bash
cd ai-book/cursor-bridge
npm install
```

**Node.js 18+** ist erforderlich.

---

## 6. Erklärung

### 6.1 Grundablauf

1. **Markieren** Sie eine Stelle links, oder lassen Sie die Markierung leer, damit der ganze Text der Kontext ist.
2. Klicken Sie **Auswahl erklären** (⌘R) oder **Gesamten Text erklären** (⌘⇧R), oder nutzen Sie das Erklärungsmenü.
3. Das Modell schreibt jede Erklärungssprache in den Bereich **Erklärung**. Bei mehreren Sprachen zeigt der Titel den Sprachnamen und die Nummer.
4. Danach kann die App die zuletzt gelungene Sprache **vorlesen** (abbrechbar; siehe Abschnitt 8).

Die Erklärung steht in der gewählten Sprache. Ist das Ziel Vereinfachtes Chinesisch, wird klassisches Chinesisch in modernem Schriftchinesisch erklärt. Rechts ist jeweils eine Sprache sichtbar. **Erklärung anzeigen** und das Erklärungsmenü wechseln zwischen schon erzeugten Erklärungen, ohne das Modell neu zu rufen. Eine `.aibook`-Datei behält jede Sprache. Eine Erklärungs-`.txt` schreibt nur in die Sprache, die Sie gerade sehen. Neu und Leeren entfernen nur diese Sprache.

### 6.2 Nachfragen

- Das **Eingabefeld** unten rechts setzt das Gespräch fort, mit der aktuellen Datei und den bisherigen Runden.
- Das Gespräch eines Buchs wird nach einem Neustart **möglichst wiederhergestellt**, über den Dateipfad.

### 6.3 Erklärungsdokumente

| Aktion | Bedeutung |
|--------|-----------|
| Neu | Die Erklärung der angezeigten Sprache leeren; die anderen bleiben im Paket |
| Öffnen | Eine Erklärungs-`.txt` in die angezeigte Sprache laden |
| Sichern | Die aktuelle Erklärung als UTF-8-Text sichern |
| Alles auswählen | Den ganzen Erklärungstext markieren |
| Erklärung leeren | Die Erklärung der aktuellen Sprache löschen |
| Erklärung vorlesen | Die ganze Erklärung vorlesen oder anhalten |

### 6.4 Eine Nachricht

**Rechtsklick** auf eine Blase kopiert sie, löscht sie oder liest **diese KI-Antwort** vor (das Menü folgt der installierten Fassung).

### 6.5 Auswahl

Ein Klick in der Titelleiste kann die Markierung links kurz löschen. Die App **behält die letzte nicht leere Auswahl**, damit **Auswahl erklären** weiterhin diesen Text verwendet.

---

## 7. Übersetzung

### 7.1 Zwei Arten

| Art | Einstieg | Ergebnis |
|-----|----------|----------|
| **Wort für Wort** | Übersetzungsmenü → Wort für Wort | Zerlegt das Original in Zeichen oder Wörter, mit einer kurzen Notiz. Für genaues Lesen |
| **Ganzer Absatz** | **Übersetzung** → **Ganzer Absatz** | Behält die Absätze in einer fortlaufenden Übersetzung. Für ein Kapitel |

**Ausgangstext**: die **aktuelle Auswahl** links, oder die **ganze linke Seite**, wenn nichts markiert ist.

**Übersetzungssprachen**: mehrere unter **Book-Einstellungen → Modell → Übersetzungssprachen**, oder im **Übersetzungsmenü**. Die Erzeugung folgt dieser Reihenfolge. Rechts ist eine Sprache sichtbar; **Übersetzung anzeigen** wechselt zwischen vorhandenen Ergebnissen. Eine `.aibook`-Datei behält jede Sprache. Klassisches Chinesisch mit Ziel Vereinfachtes Chinesisch wird modernes Schriftchinesisch.

Das Ergebnis ist strukturiertes **JSON** (mit Ausrichtungsblöcken). Text und Tabelle können Sie **direkt bearbeiten**.

### 7.2 Übersetzungsdateien

| Aktion | Bedeutung |
|--------|-----------|
| Übersetzung öffnen | Vorhandenes Übersetzungs-JSON oder einen Text laden |
| Übersetzung sichern | Ein üblicher Name ist `Originalname-翻译.txt` |
| Übersetzung leeren | Die aktuelle Übersetzung und ihre Ausrichtung löschen |
| Übersetzung auswählen | ⌘⌃⇧A |
| Übersetzung vorlesen | ⌘⌥T oder **Vorlesen** in der Übersetzungsleiste |

### 7.3 Tabelle und Ausrichtung

Enthält das JSON gültige **Ausrichtungsblöcke** (Zeichen, Wort oder Absatz):

| Steuerung | Bedeutung |
|-----------|-----------|
| **Übersetzungsvergleich** | Rechts eine **Tabelle Original–Übersetzung** |
| **Übersetzung ausrichten** | Nach einer Änderung links die Zuordnung neu berechnen |
| **Übersetzung sperren** | Verhindert ein versehentliches Neuausrichten des Ganzen. Eine einzelne Zeile bleibt meist bearbeitbar |
| **Übersetzung entsperren** | Erlaubt wieder ein vollständiges Ausrichten |

Ändert sich die linke Seite stark, sagt die Leiste: **Ausrichtung veraltet. Tippen Sie auf „Übersetzung ausrichten“ oder „Erklärung ausrichten“.** Die Erklärungstasten heißen **Erklärungsvergleich**, **Erklärung ausrichten**, **Erklärung sperren** und **Erklärung entsperren**.

### 7.4 Mitlaufen mit der linken Seite

In der **Doppelseite** des Lernmodus, mit eingeschaltetem **Übersetzungsvergleich** und gültiger Ausrichtung, kann das Rollen links die **passende Zeile hervorheben**. Die genaue Hervorhebung folgt der installierten Fassung.

---

## 8. Vorlesen

### 8.1 Einstiege

| Was | Üblicher Einstieg |
|-----|-------------------|
| Auswahl links | Sprachmenü → Originalauswahl vorlesen; ⌘⌥R (Auswahl oder ganzer Text, wie das Menü es festlegt) |
| Ganze linke Seite | Sprachmenü → ganzes Original vorlesen |
| Übersetzung | ⌘⌥T, die Übersetzungsleiste oder das Übersetzungsmenü |
| Erklärung | Erklärungsmenü → Erklärung vorlesen; oder Rechtsklick auf eine Nachricht |
| Probe | Book-Einstellungen → Sprache → aktuelle Stimme anhören |

### 8.2 Steuerung in der Titelleiste

Während vorgelesen wird, zeigt die Mitte der Titelleiste **Pause**, **Fortsetzen** und **Stopp** für das, was gerade läuft. Ein Untermenü ist nicht nötig.

### 8.3 Tempo (Book-Einstellungen → Stimme)

Die Segmentsteuerung heißt **Tempo**. Optionen und die Zeile darunter:

| Option | Text darunter |
|--------|----------------|
| **Schnell** | Schnell: höheres Tempo. |
| **Ausgewogen** | Ausgewogen: Standardtempo. |
| **Natürlich** | Natürlich: klarere Artikulation. |
| **Entspannt** | Entspannt: langsamer. |

### 8.4 Sprachverarbeitung

Die Segmentsteuerung heißt **Sprachverarbeitung**.

| Option | Text darunter |
|--------|----------------|
| **Effizient** | Sprache · Effizient. |
| **Ausgewogen** | Sprache · Ausgewogen. |
| **Tief** | Sprache · Tief. |

### 8.5 Stimmen für die Erklärung

- **Chinesische Systemstimme**: eine in macOS eingebaute chinesische Stimme.
- **Neuronale Frauenstimmen online** (Edge TTS): Xiaoyi, Xiaoxiao und regionale Stimmen.
- Laden Sie die **Probe** in den Einstellungen, bevor Sie sich auf eine Online-Stimme verlassen. Die Proben liegen lokal im Cache.

Vor der Wiedergabe werden Markdown und ähnliche Auszeichnung **bereinigt und in Sätze geteilt**.

### 8.6 Sprachbefehle

Halten Sie das Mikrofon in der Titelleiste, sprechen Sie, und lassen Sie los, um auszuführen. Im Lesemodus, wo diese Taste fehlt, **halten Sie Option+Leertaste**, solange die App vorn ist. Die App macht aus Sprache Text und ordnet den Satz mit demselben Buchmodell wie Übersetzung und Erklärung einer vorhandenen Aktion zu. Erklären, übersetzen, vorlesen, Layout, öffnen, sichern und exportieren laufen sofort. Evolution starten und Optimierungen analysieren fragen zuerst nach. Ist der Satz unklar oder passt zu keiner Aktion, geschieht nichts; die App zeigt nur den gehörten Text.

---

## 9. Original ergänzen

| Punkt | Bedeutung |
|-------|-----------|
| Einstieg | Titelleiste **Original ergänzen**, das Originalmenü, ⌘⇧C |
| Eingabe | Eine Auswahl links oder die ganze Seite |
| Verhalten | Das Modell erkennt das Werk und **ergänzt es zu einem fortlaufenden Abschnitt**, möglichst im ursprünglichen Ton |
| Ausgabe | Zurück auf die **linke Seite** (ersetzt die Auswahl oder den ganzen Text) und nach Möglichkeit **automatisch gesichert** |

Gedacht für den Zusammenhang um einen Lehrbuchauszug oder ein Fragment. Nutzen Sie es nicht, um ein Werk zu kopieren, an dem Sie kein Recht haben.

---

## 10. KI-Evolution (für Fortgeschrittene)

> **Warnung**: Die Evolution ändert den Quelltext von AIBook und installiert die App neu. Nutzen Sie sie nur, wenn Sie Git und Sicherungen kennen. Schalten Sie die **Auto-Upgrade** nicht auf einem Rechner ein, den Sie nicht verändern dürfen.

### 10.1 Was sie tut

- **Analysieren**: Das Modell **liest** das Projekt und schreibt Vorschläge in die **Optimierungswarteschlange**. Es ändert keinen Code.
- **Evolution**: Nimmt einen **offenen** Eintrag, **ändert den Code**, baut und installiert, dann **startet die App neu**.

### 10.2 Ein typischer Lauf

1. Öffnen Sie rechts den Tab **KI-Evolution**.
2. Klicken Sie **Analysieren** und warten Sie, bis Vorschläge in die Warteschlange kommen.
3. Lesen Sie die Einträge (Titel, Nummer, Status).
4. Klicken Sie **Evolution** (⌘E), um den **nächsten offenen** Eintrag auszuführen.
5. Beobachten Sie die **Überlegung** und die **Werkzeugschritte**.
6. Die App kann danach neu starten. Ist die **Auto-Upgrade** an und Sie haben in dieser Sitzung schon eine Evolution von Hand gestartet, können weitere offene Einträge **nacheinander** laufen.

### 10.3 Befehle und Warteschlangendatei

- Datei: `~/Library/Application Support/AIBook/optimization-queue.json`
- Im Evolution-Tab können Sie ein Befehlsdokument (UTF-8) **sichern und öffnen**.
- Die Analyse **verwirft Dubletten** über einen vereinheitlichten Titel. Eine Analyse schlägt eine begrenzte Zahl vor (etwa 8).

### 10.4 Kanal

**Analysieren** und **Evolution** nutzen beide den lokalen Cursor-Agenten. Es gibt keinen Rückfall auf das Buchmodell. Die Analyse liest nur. **Evolution** ändert den Code, baut und installiert. Ist Cursor nicht bereit, bleiben die Schaltflächen aus und die Kapsel sagt **Cursor nicht bereit**.

### 10.5 Token und Status

- Evolution und lange Gespräche bleiben in einem **Token-Budget**. Die Oberfläche zeigt den Verbrauch und verweigert das Senden, wenn das Budget aufgebraucht ist.
- Die Kapsel in der Titelleiste kann die **Zahl der offenen Einträge** und die Nummer des nächsten zeigen.

---

## 11. Erscheinungsbild (Book-Einstellungen → Erscheinungsbild)

| Punkt | Wirkung |
|-------|---------|
| **Design-Vorlagen** | Leder, Papier, Schaltflächen und Schmuck |
| **Größe** | Der erste Eintrag ist **Design folgen**. Die übrigen sind Schriftgrößen. Sie wirken auf die linke Seite, den Umbruch im Lesemodus und die Momentaufnahme beim Blättern |
| **Schrift** | **Design folgen**, **Schrift Songti**, **Schrift Kaiti**, **Schrift Heiti**, **Schrift PingFang**, **Systemstandard** |

**Der Lesemodus bricht neu um.** Die linke Seite im Lernmodus ändert sich sofort. Die Papierstruktur der Blätteranimation folgt der aktuellen Vorlage. Die Schmuckschalter heißen **Leseband**, **Eckfalte**, **Papierstruktur** und **Kopfzeilenornament**.

---

## 12. Menüs

Neben den Schaltflächen der Titelleiste sammeln **Ablage / Bearbeiten** dieselben Kürzel wie die Original- und Erklärungsaktionen.  
**Hilfe** öffnet dieses Handbuch und zeigt es im Finder.

**AIBook → Einstellungen** gilt der Evolution.  
**Book-Einstellungen** in der Titelleiste gilt dem Lesen, der Übersetzung, der Sprache und dem Erscheinungsbild.

---

## 13. Kürzel

| Aktion | Kürzel |
|--------|--------|
| Neu | ⌘N |
| Öffnen | ⌘O |
| Sichern | ⌘S |
| Sichern unter | ⌘⇧S |
| Auswahl links exportieren | ⌘⌥S |
| Auswahl erklären | ⌘R |
| Ganzen Text erklären | ⌘⇧R |
| Original vorlesen (Auswahl oder alles, wie das Menü es festlegt) | ⌘⌥R |
| Ganze Übersetzung vorlesen | ⌘⌥T |
| Original ergänzen | ⌘⇧C |
| **Selbst-Evolution** (Menü) / **Evolution** (Titelleiste) | ⌘E |
| Lesemodus öffnen | ⌘⇧P |
| Sprachbefehl | Option+Leertaste halten |
| Lesen: **Vorherige Seite** / **Nächste Seite** | ← / → |
| Lesen: Doppelseite / Vollbild | ⌘⌥1 / ⌘⌥2 |
| **Lesemodus beenden**, oder **Doppelseite** herstellen | Esc |
| Linke Seite auswählen | ⌘⌃A |
| Übersetzung auswählen | ⌘⌃⇧A |

> Manche Layout-Kürzel folgen dem Menü **Darstellung**. Zeigen Sie auf eine Schaltfläche, um den vollen Hinweis zu sehen.

---

## 14. Daten und Privatsphäre

### 14.1 Lokaler Speicher (Application Support)

Wurzel: `~/Library/Application Support/AIBook/`

| Was | Pfad |
|-----|------|
| Befehlsnotizen | `readme-notes.txt` |
| Optimierungswarteschlange | `optimization-queue.json` |
| Gespräche | Zwischenspeicher nach Buchpfad |
| Ordnerbrowser | Geöffnete Wurzeln und aufgeklappter Zustand |
| Online-Stimmproben | `voices/` |
| **Auto-Upgrade** | `auto-evolution-active` und verwandte Dateien |

### 14.2 Netz und Schlüssel

- Anfragen an **Modell / Cursor** gehen an die von Ihnen eingetragene API oder den Cursor-Dienst. Schlüssel bleiben in den lokalen Einstellungen. Geben Sie den Rechner nicht weiter.
- **Edge TTS** braucht ein Netz. Systemstimmen arbeiten offline.
- **Sprachbefehle** nutzen Mikrofon und die Spracherkennung des Systems. Unterstützt die Systemsprache die Erkennung auf dem Gerät, bleibt das Audio auf diesem Mac. Der erkannte Text geht an dasselbe Buchmodell wie Übersetzung und Erklärung.

---

## 15. Installation und Update

### 15.1 In den Programme-Ordner

```bash
cd ai-book
./scripts/build-and-install.sh
```

### 15.2 Aus dem Quelltext starten

```bash
swift run
```

### 15.3 Beispieltext

`Sources/AIBook/Resources/sample.txt` ist ein kurzer Text für das erste Öffnen und eine erste Erklärung.

---

## 16. Vorgeschlagene Abläufe

### 16.1 Tägliches Lesen und Fragen

1. ⌘O öffnet ein Kapitel als `.txt`.
2. Eine schwierige Stelle markieren → ⌘R erklärt sie.
3. Unten nachfragen.
4. ⌘⇧P öffnet den Lesemodus, wenn nur die Seite bleiben soll.

### 16.2 Eine Fremdsprache oder ein Klassiker

1. Das Original auf die linke Seite laden.
2. Eine **Absatzübersetzung** oder eine **Übersetzung Wort für Wort** starten.
3. Den **Übersetzungsvergleich** einschalten und eine stabile Fassung **sperren**.
4. ⌘⌥T liest die Übersetzung, ⌘⌥R das Original.

### 16.3 Ein Ordner mit vielen Dateien

1. **Ablage → Ordner öffnen…** und den Bibliotheksstamm hinzufügen.
2. `chapter-01.txt` als **Original** öffnen.
3. `chapter-01-翻译.txt` als **Übersetzung** öffnen.
4. Erklärungs- und Übersetzungsbereich im selben Fenster wechseln.

### 16.4 Einen Auszug ergänzen

1. Einen Lehrbuchauszug links einfügen.
2. ⌘⇧C ergänzt das Original.
3. Das Ergebnis prüfen, dann mit ⌘S sichern.

---

## 17. Fragen

**Die Erklärung meldet, das Modell sei nicht konfiguriert.**  
Öffnen Sie **Book-Einstellungen → Modell**, wählen Sie einen Anbieter und tragen Sie einen API-Schlüssel ein. Auf diesem Mac ist Ollama die übliche Wahl.

**Cursor lokal ist nicht verfügbar.**  
Prüfen Sie Node.js, `npm install` in cursor-bridge, den Cursor-API-Schlüssel und den Pfad in den Evolutions-Einstellungen.

**Die Übersetzungstabelle ist ausgegraut.**  
Schließen Sie zuerst eine Wort-für-Wort- oder Absatzübersetzung ab, und das JSON muss gültige Ausrichtungsblöcke enthalten. Ist die Ausrichtung verfallen, nutzen Sie **Übersetzung ausrichten**.

**Die Seitenzahlen im Lesemodus haben sich geändert.**  
Eine andere Schriftgröße oder Fenstergröße bricht neu um. Das ist erwartet. Der Doppelseiten-Index wird wiederhergestellt, soweit das geht.

**Die App verhält sich nach der Evolution anders.**  
Die Evolution ändert die lokal installierte Kopie von AIBook. Halten Sie den Quelltext in Git, und nutzen Sie die **Auto-Upgrade** nur mit Absicht.

**Handbuch und Oberfläche widersprechen sich.**  
Maßgeblich ist der **installierte Stand von AIBook**. Zeigen Sie auf eine Schaltfläche, um den aktuellen Hinweis zu sehen.

---

## 18. Fassung und Dokumente

- Dieses Handbuch liegt in der App und öffnet sich über **Hilfe**.
- Das Repository enthält außerdem Entwurfsnotizen (Lesemodus, Erscheinungsbild, Evolution) für die Entwicklung.
- Die README des Projekts enthält die kurze Einrichtung von Ollama und Cursor.

---

**Danke, dass Sie AIBook verwenden.**
