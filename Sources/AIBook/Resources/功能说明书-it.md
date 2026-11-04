# Manuale AIBook

> **AIBook** (identificativo `ai-book`) è un’applicazione nativa di lettura assistita per macOS: la **pagina sinistra** legge e modifica il testo locale, la **pagina destra** usa l’IA per spiegazione, traduzione, lettura ad alta voce e, se vuoi, l’aggiornamento dell’app stessa.  
> **Sistema**: macOS 13 o successivo.  
> **Scopo**: aiutare a capire il senso letterale, il contesto e una traduzione accanto al testo, e leggere senza distrazioni. Non sostituisce un lettore di ebook completo.

Il manuale nell’app segue la lingua dell’interfaccia. Questo file è l’edizione italiana. Il cinese semplificato è `功能说明书.md`; le altre edizioni, nella stessa cartella, sono `功能说明书-en.md`, `功能说明书-ja.md`, `功能说明书-de.md`, `功能说明书-fr.md`, `功能说明书-la.md` e `功能说明书-el.md`. Dopo una modifica, copia il file con lo stesso nome in `Sources/AIBook/Resources/` prima di impacchettare.

---

## Come aprirlo nell’app

- Barra dei menu **Aiuto → Manuale AIBook** (finestra nell’app; il testo si può selezionare e copiare)
- **Aiuto → Mostra manuale nel Finder** (seleziona il file del manuale della lingua attuale)
- **Apri con app predefinita** nella barra del titolo della finestra del manuale
- Il pulsante **Manuale** nella barra del titolo di **Impostazioni book** e **Impostazioni evoluzione**

---

## 1. Panoramica

### 1.1 Che cosa puoi fare

- Leggere e modificare un `.txt` locale nella pagina sinistra.
- Chiedere la spiegazione di una selezione o di tutto il testo, poi continuare nella stessa conversazione.
- Tradurre parola per parola o per paragrafi, e vedere una tabella testo–traduzione.
- Far leggere il testo, la traduzione o una spiegazione.
- Entrare in modalità lettura e voltare le pagine come in un libro aperto.
- Usare, se vuoi, l’evoluzione IA: analizzare il progetto, applicare una voce della coda e ricostruire l’app.

### 1.2 La scrivania

La finestra è una scrivania. A sinistra il testo, a destra l’assistente. La modalità lettura nasconde l’assistente e mostra un libro da sfogliare.

### 1.3 Due modalità di primo livello

| Modalità | A che cosa serve |
|----------|------------------|
| **Modalità studio** | Testo a sinistra; spiegazione, traduzione e lettura a destra |
| **Modalità lettura** | Sfogliare senza distrazioni. Niente spiegazione né traduzione finché non torni indietro |

Si cambia dalla barra del titolo: **Modalità lettura** (⌘⇧P) e **Modalità studio**.

---

## 2. Finestra principale (modalità studio)

La barra del titolo raccoglie documento, spiegazione, traduzione, lettura, disposizione e impostazioni. La pagina sinistra è il testo. La pagina destra è l’assistente di lettura, oppure **evoluzione IA** quando è scelto quel pannello.

### 2.1 Disposizione

| Disposizione | Significato |
|--------------|-------------|
| **Doppia pagina** | Pagina sinistra e pagina destra affiancate |
| **Originale a schermo intero** | ⌘⌥2. Il testo occupa la scrivania |
| **Schermo destro** | ⌘⌥3. L’assistente occupa la scrivania |

**Esc** ripristina la doppia pagina.

### 2.2 Riquadri dell’assistente

| Riquadro | Contenuto |
|----------|-----------|
| **Spiegazione** | Conversazione a più turni, uscita in flusso, salva / apri / cancella |
| **Traduzione** | JSON di traduzione o tabella di confronto, modificabile, con allineamento e blocco |

Le capsule **Spiegazione** / **Traduzione** nella barra del titolo cambiano riquadro. Un’azione di traduzione passa al riquadro traduzione.

### 2.3 Concentrazione

Le aree di spiegazione e traduzione possono nascondere la barra e l’input. Si ripristinano con **Lettura focus**, **Mostra barra** e **Mostra input**.

---

## 3. Modalità lettura

### 3.1 Entrare e uscire

| Azione | Come |
|--------|------|
| Entrare | Barra del titolo **Modalità lettura**, scorciatoia **⌘⇧P** (deve essere aperto un testo non vuoto) |
| Uscire | **Esci da lettura**, oppure **Esc** |

La modalità lettura non spiega e non traduce. Torna alla modalità studio quando ti serve l’IA.

### 3.2 Disposizione

| Opzione | Significato |
|---------|-------------|
| **Doppia pagina** | Pagina N a sinistra, pagina N+1 a destra. Il **dorso resta fermo** |
| **Schermo intero** | Una pagina riempie la finestra |
| Cambio | **Doppia pagina / Schermo intero** nella barra di lettura, oppure **⌘⌥1 / ⌘⌥2** |

### 3.3 Voltare le pagine

| Gesto | Comportamento |
|-------|----------------|
| **← / →** | Doppia pagina precedente / successiva |
| **Clic sulla pagina sinistra / destra** | Avanti / indietro nella doppia pagina |
| **Trascinamento orizzontale** | Segue il dito. Oltre circa un terzo, la pagina completa il giro; altrimenti torna indietro |
| **Frecce della barra del titolo** | Come la tastiera |

L’animazione curva **un foglio**. Il dorso non si deforma.

### 3.4 Pagine e avanzamento

- L’impaginazione usa gli stessi **corpo, font, interlinea e margini** della pagina sinistra (**Impostazioni book → aspetto**).
- Se cambiano la finestra o la composizione, il testo viene **reimpaginato** e il punto di lettura resta, per quanto possibile.
- Ogni file ricorda l’**indice della doppia pagina**. Rientrando in modalità lettura, viene ripristinato.
- Il piè di pagina mostra per esempio **pagine 3–4 di 128** (doppia pagina) o **pagina N di M** (schermo intero).

---

## 4. Documenti e file

### 4.1 Tipi di documento

- Il formato principale è **testo semplice UTF-8 `.txt`**.
- La pagina sinistra è **modificabile liberamente**. Puoi selezionare, copiare e trascinare un file sulla finestra.

### 4.2 Menu File e testo

| Azione | Scorciatoia | Nota |
|--------|-------------|------|
| **Nuovo originale** | ⌘N | Svuota la pagina sinistra e inizia un documento |
| **Apri l’originale…** | ⌘O | Scegli un `.txt` locale. Nella barra: **Apri l’originale** |
| **Apri la cartella dell’originale…** | | Vedi 4.4. Nella barra: **Apri la cartella dell’originale** |
| **Salva l’originale** | ⌘S | Salva nel percorso attuale |
| **Salva l’originale con nome…** | ⌘⇧S | Salva la pagina sinistra in un file nuovo |
| **Salva l’originale come AIBook…** | | Originale e traduzioni e spiegazioni già presenti, un file `.aibook` |
| **Esporta la selezione dell’originale…** | ⌘⌥S | Esporta solo la selezione attuale |
| **Seleziona tutto originale** | ⌘⌃A | |
| **Integra l’originale** | ⌘⇧C | Vedi la sezione 9 |

Se non è aperto un file esterno, la pagina sinistra carica le **note di comando** (vedi 4.3).

### 4.3 Note di comando (pagina sinistra predefinita)

- Al primo avvio, o senza un file aperto, la pagina sinistra mostra note per i tuoi appunti o per un testo di evoluzione più vecchio.
- Salvate in `~/Library/Application Support/AIBook/readme-notes.txt`.
- Se manca la copia locale, l’app torna al modello integrato o al `readme.txt` del progetto.
- **⌘S** salva le note in Application Support.

> La **coda di ottimizzazione** è ora `optimization-queue.json`. Le note non sono più la fonte dei comandi di evoluzione, ma restano un foglio personale.

### 4.4 Browser delle cartelle (biblioteca)

**Ingresso**: **Apri la cartella dell’originale…**. Il titolo della finestra è **Browser cartelle**. La barra laterale si chiama **Cartelle aperte**. Il menu del documento si chiama **Documento**.

| Passo | Che cosa succede |
|-------|------------------|
| Aggiungi una cartella | **+** nella barra laterale, poi scegli la radice dei libri |
| Cambia cartella | Selezionala nell’elenco delle cartelle aperte |
| Sfoglia | Espandi le sottocartelle nell’albero centrale |
| Scegli la destinazione | **Apri nell’area originale della pagina sinistra**, **Apri nell’area traduzione della pagina destra**, **Apri nell’area spiegazione della pagina destra** |
| Apri | Doppio clic, oppure conferma in basso |

Le cartelle aggiunte e lo stato espanso vengono **conservati**. Servono per passare, nella stessa biblioteca, tra `.txt`, `-翻译.txt` e bozze di spiegazione.

---

## 5. Motori di IA e impostazioni

Spiegazione, traduzione e **Integra l’originale** usano il modello di lettura in **Impostazioni book**. L’evoluzione IA usa sempre Cursor, in **Impostazioni evoluzione**. La barra del titolo non ha un interruttore.

### 5.1 Modello di lettura, Cursor per l’evoluzione

| Uso | Controllo |
|-----|-----------|
| Spiegare, tradurre, integrare l’originale | **Impostazioni book** → **Modelli IA** → **Provider attivo** |
| **Analizza** ed **Evolvi** | **Modello Cursor** in **Impostazioni evoluzione** |

La capsula della barra del titolo mostra il nome del file e **Non salvato**. Senza modello di lettura dice **LLM book non configurato**. Se Cursor non è pronto: **Cursor non pronto**.

### 5.2 Impostazioni book

**Ingresso**: il pulsante **Impostazioni book** nella barra del titolo.

#### Modello

- Indirizzo, chiave e modello predefinito sono salvati **per fornitore**.
- Esempi integrati:

| Fornitore | Uso tipico |
|-----------|------------|
| OpenAI | Modelli GPT nel cloud |
| DeepSeek | Cinese a costo più basso |
| Ollama | **Gratis su questo Mac** (consigliato per la lettura quotidiana) |
| Moonshot / Qwen / Zhipu | Modelli cloud in Cina |
| Personalizzato | Qualsiasi endpoint compatibile con OpenAI |

**Avvio rapido di Ollama**:

```bash
ollama serve
ollama pull llama3.2
```

Scegli Ollama nelle Impostazioni book, poi **cerca i modelli installati su questo Mac**. Se Ollama richiede una chiave API, inseriscila lì.

- **Lingue di traduzione** e **lingue di spiegazione**: puoi sceglierne più di una tra cinese semplificato, inglese, giapponese, tedesco, francese, italiano, latino e greco. La generazione successiva le produce nell’ordine spuntato. I risultati già presenti restano nella pagina destra e si possono cambiare. Un file `.aibook` li conserva tutti.
- **Quota estratto sinistra**: quanta parte del testo di sinistra accompagna ogni richiesta, per restare nella finestra del modello.

#### Voce

Vedi la sezione 8.

#### Aspetto

Vedi la sezione 11.

### 5.3 Impostazioni evoluzione

**Ingresso**: menu **AIBook → Impostazioni** (pannello evoluzione).

| Impostazione | Significato |
|--------------|-------------|
| Chiave API Cursor | Oppure la variabile d’ambiente `CURSOR_API_KEY` |
| Modello Cursor | Per esempio un modello Composer |
| Percorso di cursor-bridge | La cartella `cursor-bridge` nel progetto |
| **Aggiornamento auto** | Dopo un clic su **Evolvi**, le voci rimaste possono eseguirsi una dopo l’altra (vedi la sezione 10) |

**Dipendenza Cursor locale**:

```bash
cd ai-book/cursor-bridge
npm install
```

Serve **Node.js 18 o successivo**.

---

## 6. Spiegazione

### 6.1 Svolgimento

1. **Seleziona** un brano a sinistra, oppure lascia la selezione vuota per usare tutto il testo come contesto.
2. Fai clic su **Spiega selezione** (⌘R) o **Spiega tutto** (⌘⇧R), oppure usa il menu della spiegazione.
3. Il modello scrive ogni lingua di spiegazione nel riquadro **Spiegazione**. Con più lingue, il titolo del foglio mostra il nome della lingua e il numero.
4. Al termine, l’app può **leggere ad alta voce** l’ultima lingua riuscita (puoi fermarla; vedi la sezione 8).

La spiegazione è scritta nella lingua scelta. Se la destinazione è il cinese semplificato, il cinese classico viene spiegato in cinese scritto moderno. La pagina destra mostra una lingua alla volta. **Mostra la spiegazione** e il menu della spiegazione passano da una spiegazione già prodotta a un’altra, senza richiamare il modello. Aprire o salvare un `.aibook` conserva ogni lingua. Aprire una `.txt` di spiegazione scrive solo nella lingua che stai guardando. Nuovo e Cancella tolgono solo quella lingua.

### 6.2 Domande successive

- Il **campo** in fondo alla pagina destra continua la conversazione, con il file attuale e i turni precedenti.
- La conversazione di un libro viene **ripristinata quando è possibile** dopo un riavvio, in base al percorso del file.

### 6.3 Documenti di spiegazione

| Azione | Significato |
|--------|-------------|
| Nuovo | Cancella la spiegazione della lingua visibile; le altre restano nel pacchetto |
| Apri | Carica una `.txt` di spiegazione nella lingua visibile |
| Salva | Salva la spiegazione attuale come testo UTF-8 |
| Seleziona tutto | Seleziona tutto il testo dell’area di spiegazione |
| Cancella spiegazione | Elimina la spiegazione della lingua attuale |
| Leggi spiegazione | Legge tutta la spiegazione, oppure si ferma |

### 6.4 Un messaggio

Un **clic destro** su una bolla la copia, la elimina, oppure legge **quella risposta dell’IA** (il menu segue la versione installata).

### 6.5 Selezione

Un pulsante della barra del titolo può togliere per un attimo l’evidenziazione a sinistra. L’app **conserva l’ultima selezione non vuota**, così **Spiega selezione** usa ancora il testo appena scelto.

---

## 7. Traduzione

### 7.1 Due modi

| Modo | Ingresso | Risultato |
|------|----------|-----------|
| **Parola per parola** | **Traduzione** → **Parola per parola** | Spezza il testo in caratteri o parole, con una nota breve. Per una lettura ravvicinata |
| **Paragrafo intero** | **Traduzione** → **Paragrafo intero** | Mantiene i paragrafi in una traduzione continua. Per leggere un capitolo |

**Testo di partenza**: la **selezione attuale** a sinistra, oppure **tutta la pagina sinistra** se non c’è selezione.

**Lingue di traduzione**: più di una in **Impostazioni book → modello → lingue di traduzione**, oppure nel **menu traduzione**. La generazione segue quell’ordine. La pagina destra mostra una lingua alla volta; **Mostra la traduzione** passa tra i risultati già prodotti. Un `.aibook` conserva ogni lingua. Il cinese classico rivolto al cinese semplificato diventa cinese scritto moderno.

Il risultato è **JSON** strutturato (con blocchi di allineamento). Puoi **modificare** direttamente il testo o la tabella.

### 7.2 File di traduzione

| Azione | Significato |
|--------|-------------|
| Apri traduzione | Carica un JSON o un testo di traduzione esistente |
| Salva traduzione | Un nome consueto è `nome-originale-翻译.txt` |
| Cancella traduzione | Elimina la traduzione attuale e il suo allineamento |
| Seleziona tutta la traduzione | ⌘⌃⇧A |
| Leggi traduzione | ⌘⌥T, oppure **Leggi** nella barra della traduzione |

### 7.3 Tabella e allineamento

Quando il JSON contiene **blocchi di allineamento** validi (carattere, parola o paragrafo):

| Controllo | Significato |
|-----------|-------------|
| **Confronto traduzione** | La pagina destra mostra una **tabella testo–traduzione** |
| **Allinea traduzione** | Dopo un cambiamento a sinistra, ricalcola la corrispondenza |
| **Blocca traduzione** | Impedisce un riallineamento completo accidentale. Modificare una riga di solito resta possibile |
| **Sblocca traduzione** | Consente di nuovo un riallineamento completo |

Se la pagina sinistra cambia molto, la barra dice: **Allineamento non valido. Tocca «Allinea traduzione» o «Allinea spiegazione».** I pulsanti della spiegazione sono **Confronto spiegazione**, **Allinea spiegazione**, **Blocca spiegazione** e **Sblocca spiegazione**.

### 7.4 Scorrimento con la pagina sinistra

Nella **doppia pagina** della modalità studio, con il **confronto** attivo e l’allineamento ancora valido, lo scorrimento a sinistra può **evidenziare la riga corrispondente**. Il dettaglio segue la versione installata.

---

## 8. Lettura ad alta voce

### 8.1 Da dove partire

| Che cosa | Ingresso abituale |
|----------|-------------------|
| Selezione a sinistra | Menu voce → leggi la selezione del testo; ⌘⌥R (selezione o testo intero, come definisce il menu) |
| Tutta la pagina sinistra | Menu voce → leggi tutto il testo |
| Traduzione | ⌘⌥T, la barra della traduzione o il menu traduzione |
| Spiegazione | Menu spiegazione → leggi la spiegazione; oppure clic destro su un messaggio |
| Prova | Impostazioni book → Voce → ascolta la voce attuale |

### 8.2 Controlli nella barra del titolo

Durante la lettura, il centro della barra del titolo mostra **Pausa**, **Riprendi** e **Stop** per ciò che sta suonando. Non serve un sottomenu.

### 8.3 Ritmo (Impostazioni book → Voce)

Il controllo segmentato si chiama **Ritmo**.

| Opzione | Testo sotto il controllo |
|---------|--------------------------|
| **Veloce** | Veloce: ritmo rapido. |
| **Bilanciato** | Bilanciato: ritmo predefinito. |
| **Naturale** | Naturale: articolazione chiara. |
| **Rilassato** | Rilassato: più lento. |

### 8.4 Elaborazione lingua

Il controllo si chiama **Elaborazione lingua**.

| Opzione | Testo sotto il controllo |
|---------|--------------------------|
| **Efficiente** | Lingua · Efficiente. |
| **Bilanciato** | Lingua · Bilanciato. |
| **Profondo** | Lingua · Profondo. |

### 8.5 Voci della spiegazione

- **Voce cinese di sistema**: una voce cinese integrata in macOS.
- **Voci femminili neurali in linea** (Edge TTS): Xiaoyi, Xiaoxiao e voci regionali.
- Scarica il **campione** nelle impostazioni prima di affidarti a una voce in linea. I campioni restano nella cache locale.

Prima della riproduzione, Markdown e marcature simili vengono **puliti e divisi in frasi**.

### 8.6 Comandi vocali

Tieni premuto il microfono della barra del titolo, parla e rilascia per eseguire. In modalità lettura, dove quel pulsante non c’è, **tieni premuto Opzione+spazio** mentre l’app è in primo piano. L’app trasforma la voce in testo, poi usa lo stesso modello di lettura di traduzione e spiegazione per collegare la frase a un’azione esistente. Spiegare, tradurre, leggere, cambiare disposizione, aprire, salvare ed esportare partono subito. Avviare l’evoluzione o analizzare le ottimizzazioni chiede prima conferma. Se la frase non è chiara o non corrisponde ad alcuna azione, non viene eseguito nulla; l’app mostra solo il testo udito.

---

## 9. Completare il testo

| Voce | Significato |
|------|-------------|
| Ingresso | Barra del titolo **Completa il testo**, menu del testo, ⌘⇧C |
| Ingresso di testo | Una selezione a sinistra, o tutta la pagina |
| Comportamento | Il modello riconosce l’opera e **la completa come un brano continuo**, conservando lo stile per quanto può |
| Uscita | Riscrive la **pagina sinistra** (sostituisce la selezione o tutto il testo) e, se può, **salva in automatico** |

Serve a restituire il contesto di un brano di manuale o di un frammento. Non usarlo per copiare un’opera di cui non hai il diritto d’uso.

---

## 10. Evoluzione IA (avanzata)

> **Avviso**: l’evoluzione modifica il codice sorgente di AIBook e reinstalla l’app. Usala solo se conosci Git e i backup. Non attivare la **Aggiornamento auto** su una macchina che non puoi permetterti di cambiare.

### 10.1 Che cosa fa

- **Analizza**: il modello **legge** il progetto e scrive suggerimenti nella **coda di ottimizzazione**. Non modifica il codice.
- **Evolvi**: prende una voce **in attesa**, **modifica il codice**, compila e installa, poi **riavvia l’app**.

### 10.2 Un percorso tipico

1. Apri a destra il pannello **Evoluzione IA**.
2. Fai clic su **Analizza** e attendi che i suggerimenti entrino in coda.
3. Leggi le voci (titolo, numero, stato).
4. Fai clic su **Evolvi** (⌘E) per eseguire la **prossima voce in attesa**.
5. Osserva il **ragionamento** e i **passi degli strumenti**.
6. Al termine l’app può riavviarsi. Se la **Aggiornamento auto** è attiva e in questa sessione hai già avviato un’evoluzione a mano, le voci successive possono **eseguirsi in sequenza**.

### 10.3 Comandi e file della coda

- File: `~/Library/Application Support/AIBook/optimization-queue.json`
- Nel pannello evoluzione puoi **salvare e aprire** un documento di comandi (UTF-8).
- L’analisi **scarta i duplicati** in base a un titolo normalizzato. Un’analisi propone un numero limitato di voci (circa 8).

### 10.4 Canale

**Analizza** ed **Evolvi** usano entrambi l’agente Cursor locale. Non c’è un ritorno al modello di lettura. L’analisi si limita a leggere. **Evolvi** modifica il codice, compila e installa. Se Cursor non è pronto, i pulsanti restano disattivati e la capsula dice **Cursor non pronto**.

### 10.5 Token e stato

- Evoluzione e conversazioni lunghe restano dentro un **budget di token**. L’interfaccia mostra l’uso e rifiuta l’invio quando il budget è esaurito.
- La capsula della barra del titolo può mostrare il **numero delle voci in attesa** e il numero della successiva.

---

## 11. Aspetto (Impostazioni book → aspetto)

| Voce | Che cosa influenza |
|------|--------------------|
| **Temi predefiniti** | Cuoio, carta, pulsanti e ornamenti |
| **Dimensione** | La prima voce è **Segui tema**. Le altre sono corpi. Agiscono sulla pagina sinistra, sull’impaginazione della modalità lettura e sull’istantanea del voltapagina |
| **Carattere** | **Segui tema**, **Carattere Songti**, **Carattere Kaiti**, **Carattere Heiti**, **Carattere PingFang**, **Predefinito di sistema** |

**La modalità lettura reimpagina** dopo un cambiamento. La pagina sinistra della modalità studio si aggiorna subito. La trama della carta nell’animazione segue la preimpostazione attuale. Gli interruttori degli ornamenti si chiamano **Nastro segnalibro**, **Angolo piegato**, **Texture carta** e **Ornamento intestazione**.

---

## 12. Menu

Oltre ai pulsanti della barra del titolo, i menu **File / Modifica** raccolgono le stesse scorciatoie delle azioni sul testo e sulla spiegazione.  
**Aiuto** apre questo manuale e lo mostra nel Finder.

**AIBook → Impostazioni** riguarda l’evoluzione.  
**Impostazioni book** nella barra del titolo riguarda lettura, traduzione, voce e aspetto.

---

## 13. Scorciatoie

| Azione | Scorciatoia |
|--------|-------------|
| Nuovo | ⌘N |
| Apri | ⌘O |
| Salva | ⌘S |
| Salva con nome | ⌘⇧S |
| Esporta la selezione di sinistra | ⌘⌥S |
| Spiega la selezione | ⌘R |
| Spiega tutto il testo | ⌘⇧R |
| Leggi il testo (selezione o tutto, come definisce il menu) | ⌘⌥R |
| Leggi tutta la traduzione | ⌘⌥T |
| Completa il testo | ⌘⇧C |
| **Auto-evoluzione** (menu) / **Evolvi** (barra del titolo) | ⌘E |
| Entra in modalità lettura | ⌘⇧P |
| Comando vocale | Tieni premuto Opzione+spazio |
| Lettura: **Pagina precedente** / **Pagina successiva** | ← / → |
| Lettura: doppia pagina / schermo intero | ⌘⌥1 / ⌘⌥2 |
| **Esci da lettura**, oppure ripristina **Doppia pagina** | Esc |
| Seleziona tutta la pagina sinistra | ⌘⌃A |
| Seleziona tutta la traduzione | ⌘⌃⇧A |

> Alcune scorciatoie di disposizione seguono il menu **Vista**. Passa il puntatore su un pulsante della barra del titolo per vedere l’indicazione completa.

---

## 14. Dati e riservatezza

### 14.1 Archiviazione locale (Application Support)

Radice: `~/Library/Application Support/AIBook/`

| Che cosa | Percorso |
|----------|----------|
| Note di comando | `readme-notes.txt` |
| Coda di ottimizzazione | `optimization-queue.json` |
| Conversazioni | Cache secondo il percorso del libro |
| Browser delle cartelle | Radici aperte e stato espanso |
| Campioni di voce in linea | `voices/` |
| **Aggiornamento auto** | `auto-evolution-active` e file collegati |

### 14.2 Rete e chiavi

- Le richieste a **modello / Cursor** vanno all’API o al servizio Cursor che hai configurato. Le chiavi restano nelle preferenze locali. Non condividere la macchina.
- **Edge TTS** ha bisogno della rete. Le voci di sistema funzionano senza rete.
- I **comandi vocali** usano il microfono e il riconoscimento vocale del sistema. Quando la lingua del sistema consente il riconoscimento sul dispositivo, l’audio resta su questo Mac. Il testo riconosciuto viene inviato allo stesso modello di lettura usato per traduzione e spiegazione.

---

## 15. Installazione e aggiornamento

### 15.1 Installare nella cartella Applicazioni

```bash
cd ai-book
./scripts/build-and-install.sh
```

### 15.2 Avviare dai sorgenti

```bash
swift run
```

### 15.3 Testo di esempio

`Sources/AIBook/Resources/sample.txt` è un testo breve per una prima apertura e una prima spiegazione.

---

## 16. Percorsi suggeriti

### 16.1 Lettura quotidiana e domande

1. ⌘O apre un capitolo `.txt`.
2. Seleziona un brano difficile → ⌘R per spiegarlo.
3. Fai una domanda successiva nel campo in basso.
4. ⌘⇧P entra in modalità lettura quando vuoi solo la pagina.

### 16.2 Una lingua straniera o un classico

1. Carica il testo nella pagina sinistra.
2. Avvia una traduzione **per paragrafo** o **parola per parola**.
3. Attiva il **confronto** e **blocca** una versione stabile.
4. ⌘⌥T legge la traduzione; ⌘⌥R legge il testo.

### 16.3 Una cartella con molti file

1. **File → Apri cartella…** e aggiungi la radice della biblioteca.
2. Scegli `chapter-01.txt` → aprilo come **testo**.
3. Scegli `chapter-01-翻译.txt` → aprilo come **traduzione**.
4. Cambia i riquadri spiegazione e traduzione nella stessa finestra.

### 16.4 Completare un brano

1. Incolla a sinistra un brano di manuale.
2. ⌘⇧C completa il testo.
3. Controlla il risultato, poi ⌘S per salvare.

---

## 17. Domande

**Il pulsante della spiegazione dice che il modello non è configurato.**  
Apri **Impostazioni book → modello**, scegli un fornitore e inserisci una chiave API. Su questo Mac la scelta abituale è Ollama.

**Cursor locale non è disponibile.**  
Controlla Node.js, `npm install` dentro cursor-bridge, la chiave API Cursor e il percorso nelle Impostazioni evoluzione.

**La tabella di traduzione è disattivata.**  
Completa prima una traduzione parola per parola o per paragrafo, e il JSON deve contenere blocchi di allineamento validi. Se l’allineamento è scaduto, usa **Allinea traduzione**.

**I numeri di pagina sono cambiati in modalità lettura.**  
Cambiare il corpo o la finestra reimpagina. È previsto. L’indice della doppia pagina viene ripristinato quando è possibile.

**L’app si comporta diversamente dopo l’evoluzione.**  
L’evoluzione modifica la copia locale installata di AIBook. Tieni i sorgenti in Git e usa la **Aggiornamento auto** solo quando lo vuoi davvero.

**Questo manuale e l’interfaccia non coincidono.**  
Fa fede la **versione di AIBook installata**. Passa il puntatore su un pulsante per l’indicazione attuale.

---

## 18. Versione e documenti

- Questo manuale è distribuito dentro l’app e si apre dal menu **Aiuto**.
- Il repository contiene anche note di progetto (modalità lettura, aspetto, evoluzione) per lo sviluppo.
- Il README del progetto ha la breve installazione di Ollama e Cursor.

---

**Grazie per usare AIBook.**
