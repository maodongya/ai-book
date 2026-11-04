# Manualis AIBook

> **AIBook** (nota `ai-book`) est programma macOS nativum ad legendum adiuvandum: **pagina sinistra** textum localem legit et emendat, **pagina dextra** intellegentia artificiali utitur ad explicationem, translationem, recitationem et, si vis, ad ipsam applicationem renovandam.  
> **Systema**: macOS 13 aut recentius.  
> **Finis**: adiuvat ut sensum litteralem, contextum et translationem iuxta textum intellegas, et sine interpellatione legas. Non est lector plenus librorum electronicorum.

Manualis in applicatione linguam interfaciei sequitur. Hic fasciculus est editio Latina. Sinica simplicior est `功能说明书.md`; ceterae editiones in eadem capsa sunt `功能说明书-en.md`, `功能说明书-ja.md`, `功能说明书-de.md`, `功能说明书-fr.md`, `功能说明书-it.md` et `功能说明书-el.md`. Post emendationem fasciculum eiusdem nominis in `Sources/AIBook/Resources/` transcribe antequam applicationem componis.

---

## Quomodo in applicatione aperitur

- E linea menuium **Auxilium → Manualis AIBook** (fenestra in applicatione; textus seligi et copiari potest)
- **Auxilium → Ostende manualem in Finder** (fasciculum manualis linguae praesentis seligit)
- **Aperi in app systematis** in linea tituli fenestrae manualis
- Pygula **Manualis** in linea tituli **Configurationis book** et **Configurationis evolutionis**

---

## 1. Summarium

### 1.1 Quid facere potes

- `.txt` localem in pagina sinistra legere et emendare.
- Explicationem selectionis aut totius textus petere, deinde in eodem colloquio interrogare.
- Verbum pro verbo aut per paragraphos transferre, et tabulam textus et translationis videre.
- Textum, translationem aut explicationem recitari.
- In modum legendi intrare et paginas sicut librum apertum vertere.
- Si vis, evolutione uti: proiectum inspicere, unam rem e serie applicare, et applicationem rursus aedificare.

### 1.2 Mensa

Fenestra est mensa. Sinistra est textus, dextra adiutor. Modus legendi adiutorem occultat et librum vertendum ostendit.

### 1.3 Duo modi summi

| Modus | Usus |
|-------|------|
| **Modus discendi** | Textus ad sinistram; explicatio, translatio et recitatio ad dextram |
| **Modus legendi** | Paginae sine interpellatione. Nulla explicatio neque translatio, donec redeas |

Mutatio e linea tituli: **Modus legendi** (⌘⇧P) et **Modus discendi**.

---

## 2. Fenestra princeps (modus studii)

Linea tituli documentum, explicationem, translationem, recitationem, dispositionem et configurationem continet. Pagina sinistra est textus. Pagina dextra est adiutor legendi, aut **evolutio**, cum illa tabula electa est.

### 2.1 Dispositio

| Dispositio | Sensus |
|------------|--------|
| **Paginae geminae** | Pagina sinistra et dextra iuxta se |
| **Originale in pleno schermo** | ⌘⌥2. Textus mensam implet |
| **Dextra plena** | ⌘⌥3. Adiutor mensam implet |

**Esc** paginas geminas restituit.

### 2.2 Partes adiutoris

| Pars | Contentum |
|------|-----------|
| **Explicatio** | Colloquium plurium vicium, exitus fluens, serva / aperi / dele |
| **Translatio** | JSON translationis aut tabula comparationis, emendabilis, cum alignatione et claustro |

Capsulae **Explicatio** / **Translatio** in linea tituli partem mutant. Actio translationis ad partem translationis transit.

### 2.3 Intentio

Areae explicationis et translationis toolbar et intrantum occultare possunt. Restituuntur per **Lectio intenta**, **Ostende toolbar** et **Ostende intrantum**.

---

## 3. Modus legendi

### 3.1 Intrare et exire

| Actio | Quomodo |
|-------|---------|
| Intrare | Linea tituli **Modus legendi**, brevis **⌘⇧P** (textus non vacuus apertus esse debet) |
| Exire | **Exi modum legendi**, aut **Esc** |

Modus legendi non explicat neque transfert. Ad modum studii redi cum intellegentia artificiali opus est.

### 3.2 Dispositio

| Optio | Sensus |
|-------|--------|
| **Paginae geminae** | Pagina N ad sinistram, pagina N+1 ad dextram. **Dorsum fixum manet** |
| **Plenum schermum** | Una pagina fenestram implet |
| Mutatio | **Paginae geminae / Plenum schermum** in linea legendi, aut **⌘⌥1 / ⌘⌥2** |

### 3.3 Paginas vertere

| Gestus | Actus |
|--------|-------|
| **← / →** | Paginae geminae priores / posteriores |
| **Clic in paginam sinistram / dextram** | Porro / retro in paginis geminis |
| **Tractus horizontalis** | Manum sequitur. Ultra circiter tertiam partem pagina vertitur; aliter resilit |
| **Sagittae lineae tituli** | Sicut claviatura |

Animatio **unam chartam** flectit. Dorsum non mutatur.

### 3.4 Paginae et progressus

- Divisio paginarum eisdem **magnitudine, typo, spatio linearum et marginibus** utitur atque pagina sinistra (**Configuratio book → species**).
- Si fenestra aut compositio mutatur, textus **rursus dividitur** et locus, quantum potest, servatur.
- Quisque fasciculus **indicem paginarum geminarum** meminit. Modus legendi eum restituit.
- Pes ostendit fere **paginas 3–4 ex 128** (geminae) aut **paginam N ex M** (plenum schermum).

---

## 4. Documenta et fasciculi

### 4.1 Genera

- Forma princeps est **textus planus UTF-8 `.txt`**.
- Pagina sinistra **libere emendatur**. Seligere, copiare et fasciculum in fenestram trahere potes.

### 4.2 Menu fasciculorum et textus

| Actio | Brevis | Nota |
|-------|--------|------|
| **Novum originale** | ⌘N | Paginam sinistram vacuum facit et documentum novum incipit |
| **Aperi originale…** | ⌘O | `.txt` localem elige. In linea: **Aperi originale** |
| **Aperi folder originalis…** | | Vide 4.4. In linea: **Aperi folder originalis** |
| **Serva originale** | ⌘S | In via praesenti servat |
| **Serva originale ut…** | ⌘⇧S | Paginam sinistram in fasciculum novum servat |
| **Serva originale ut AIBook…** | | Originale et translationes explicationesque iam factae, unus fasciculus `.aibook` |
| **Exporta selectum originalis…** | ⌘⌥S | Solam selectionem praesentem |
| **Elige totum originale** | ⌘⌃A | |
| **Supple originale** | ⌘⇧C | Vide sectionem 9 |

Sine fasciculo externo pagina sinistra **notas mandatorum** legit (vide 4.3).

### 4.3 Notae mandatorum (pagina sinistra praedefinita)

- Primo usu, aut sine fasciculo aperto, pagina sinistra notas ostendit ad tuas annotationes aut textum evolutionis veterem.
- Servantur in `~/Library/Application Support/AIBook/readme-notes.txt`.
- Si copia localis deest, applicatio ad exemplum insitum aut `readme.txt` proiecti redit.
- **⌘S** notas in Application Support servat.

> **Series optimizationis** nunc est `optimization-queue.json`. Notae non iam fons mandatorum evolutionis sunt, sed manent scheda personalis.

### 4.4 Scrutator capsarum (bibliotheca)

**Aditus**: **Aperi folder originalis…**. Titulus fenestrae est **Navigator folder**. Latus vocatur **Folder aperta**. Menu documenti vocatur **Documentum**.

| Gradus | Quid fit |
|--------|----------|
| Adde capsam | **+** in latere, deinde radicem librorum elige |
| Muta capsam | Eam in indice capsarum apertarum selige |
| Scrutare | Subcapsas in arbore media expande |
| Elige destinatum | **Aperi in area originalis paginae sinistrae**, **Aperi in area translationis paginae dextrae**, **Aperi in area explicationis paginae dextrae** |
| Aperi | Duplex clic, aut in imo confirma |

Capsae additae et status expansus **servantur**. Ita in una bibliotheca inter `.txt`, `-翻译.txt` et schemata explicationis transis.

---

## 5. Instrumenta intellegentiae et configuratio

Explicatio, translatio et **Supple originale** exemplari legendi in **Configuratione book** utuntur. Evolutio semper Cursor utitur, in **Configuratione evolutionis**. In linea tituli nullus commutator est.

### 5.1 Exemplar legendi, Cursor pro evolutione

| Usus | Gubernaculum |
|------|--------------|
| Explicare, transferre, originale supplere | **Configuratio book** → **Modelli IA** → **Praebitor activus** |
| **Analyse** et **Evolue** | **Modellus Cursor** in **Configuratione evolutionis** |

Capsula lineae tituli nomen fasciculi et **Non servatum** ostendit. Sine exemplari legendi dicit **Book LLM non configuratum**. Si Cursor non paratus est: **Cursor non paratus**.

### 5.2 Configuratio book

**Aditus**: pygula **Configuratio book** in linea tituli.

#### Exemplar

- Inscriptio, clavis et exemplar praedefinitum **per praebitorem** servantur.
- Exempla insita:

| Praebitor | Usus typicus |
|-----------|--------------|
| OpenAI | Exemplaria GPT in nube |
| DeepSeek | Sinica minoris pretii |
| Ollama | **Gratis in hoc Mac** (ad lectionem cotidianam commendatum) |
| Moonshot / Qwen / Zhipu | Exemplaria nubis in Sina |
| Proprium | Quilibet terminus cum OpenAI compatibilis |

**Ollama, initium breve**:

```bash
ollama serve
ollama pull llama3.2
```

Ollama in Configuratione book elige, deinde **exemplaria in hoc Mac installata scrutare**. Si Ollama clavem API postulat, eam ibi scribe.

- **Linguae translationis** et **linguae explicationis**: plures ex Sinica simpliciore, Anglica, Iaponica, Germanica, Gallica, Italica, Latina aut Graeca seligere potes. Proxima generatio eas ordine notato producit. Effectus iam praesentes in pagina dextra manent et mutari possunt. Fasciculus `.aibook` omnes servat.
- **Portio excerpta sinistra**: quanta pars textus sinistri cum unaquaque petitione mittitur, ne fenestra exemplaris excedatur.

#### Vox

Vide sectionem 8.

#### Species

Vide sectionem 11.

### 5.3 Configuratio evolutionis

**Aditus**: menu **AIBook → Configurationes** (tabula evolutionis).

| Configuratio | Sensus |
|--------------|--------|
| Clavis API Cursor | Aut variabilis ambitus `CURSOR_API_KEY` |
| Exemplar Cursor | Exempli gratia exemplar Composer |
| Via cursor-bridge | Capsa `cursor-bridge` in proiecto |
| **Auto renovatio** | Post unum clic in **Evolue**, res reliquae continua serie currere possunt (vide sectionem 10) |

**Dependentia Cursor localis**:

```bash
cd ai-book/cursor-bridge
npm install
```

**Node.js 18+** necessarium est.

---

## 6. Explicatio

### 6.1 Cursus

1. Locum in pagina sinistra **selige**, aut selectionem vacuum relinque ut totus textus contextus sit.
2. Clic in **Explica selectum** (⌘R) aut **Explica totum** (⌘⇧R), aut menu explicationis utere.
3. Exemplar unamquamque linguam explicationis in partem **Explicationis** scribit. Pluribus linguis titulus nomen linguae et numerum ostendit.
4. Finita explicatione, applicatio ultimam linguam felicem **recitare** potest (sistere potes; vide sectionem 8).

Explicatio lingua electa scribitur. Si finis est Sinica simplicior, Sinica antiqua Sinica scripta moderna explicatur. Pagina dextra unam linguam simul ostendit. **Ostende explicationem** et menu explicationis inter explicationes iam factas transeunt, sine nova vocatione exemplaris. Fasciculus `.aibook` apertus aut servatus omnes linguas tenet. `.txt` explicationis solam linguam quam nunc vides scribit. Novum et Dele solam illam linguam auferunt.

### 6.2 Interrogationes ulteriores

- **Campus** in imo paginae dextrae colloquium pergit, cum fasciculo praesenti et vicibus prioribus.
- Colloquium libri post initium novum **quantum potest restituitur**, secundum viam fasciculi.

### 6.3 Documenta explicationis

| Actio | Sensus |
|-------|--------|
| Novum | Explicationem linguae visae vacuum facit; ceterae in fasciculo manent |
| Aperi | `.txt` explicationis in linguam visam legit |
| Serva | Explicationem praesentem ut textum UTF-8 servat |
| Selige omnia | Totum textum areae explicationis seligit |
| Dele explicationem | Explicationem linguae praesentis delet |
| Recita explicationem | Totam explicationem recitat, aut sistit |

### 6.4 Unum nuntium

**Clic dextrum** in bullam eam copiat, delet, aut **illam responsionem** recitat (menu versionem installatam sequitur).

### 6.5 Selectio

Pygula lineae tituli lucem paginae sinistrae paulisper delere potest. Applicatio **ultimam selectionem non vacuam tenet**, itaque **Explica selectum** textum modo electum adhuc utitur.

---

## 7. Translatio

### 7.1 Duo modi

| Modus | Aditus | Effectus |
|-------|--------|----------|
| **Verbum pro verbo** | **Translatio** → **Verbum pro verbo** | Textum in litteras aut verba dividit, cum nota brevi. Ad lectionem accuratam |
| **Totus paragraphus** | **Translatio** → **Totus paragraphus** | Formam paragraphorum in translatione continua servat. Ad capitulum |

**Textus fons**: **selectio praesens** in pagina sinistra, aut **tota pagina sinistra** si nihil selectum est.

**Linguae translationis**: plures sub **Configuratio book → exemplar → linguae translationis**, aut in **menu translationis**. Generatio illum ordinem sequitur. Pagina dextra unam linguam simul ostendit; **Ostende translationem** inter effectus iam factos transit. Fasciculus `.aibook` omnes linguas tenet. Sinica antiqua ad Sinicam simpliciorem versa Sinica scripta moderna fit.

Effectus est **JSON** structum (cum blocis alignationis). Textum aut tabulam **directe emendare** potes.

### 7.2 Fasciculi translationis

| Actio | Sensus |
|-------|--------|
| Aperi translationem | JSON aut textum translationis iam factum legit |
| Serva translationem | Nomen usitatum est `nomen-originale-翻译.txt` |
| Dele translationem | Translationem praesentem et alignationem delet |
| Selige totam translationem | ⌘⌃⇧A |
| Recita translationem | ⌘⌥T, aut **Recita** in linea translationis |

### 7.3 Tabula et alignatio

Cum JSON **blocos alignationis** validos continet (littera, verbum aut paragraphus):

| Gubernaculum | Sensus |
|--------------|--------|
| **Comparatio translationis** | Pagina dextra **tabulam textus et translationis** ostendit |
| **Aligna translationem** | Post mutationem sinistram correspondentiam rursus computat |
| **Claude translationem** | Alignatiem totam fortuitam prohibet. Una linea plerumque adhuc emendari potest |
| **Resera translationem** | Alignatiem totam rursus sinit |

Si pagina sinistra multum mutatur, linea dicit: **Alignmentum obsoletum est. Tange «Aligna translationem» vel «Aligna explicationem».** Pygulae explicationis sunt **Comparatio explicationis**, **Aligna explicationem**, **Claude explicationem** et **Resera explicationem**.

### 7.4 Cum volutatione paginae sinistrae

In **paginis geminis** modi studii, comparatione activa et alignatione valida, volutatio sinistra **lineam respondentem lucere** potest. Singula versionem installatam sequuntur.

---

## 8. Recitatio

### 8.1 Aditus

| Quid | Aditus usitatus |
|------|-----------------|
| Selectio sinistra | Menu vocis → selectionem textus recita; ⌘⌥R (selectio aut totus textus, ut menu definit) |
| Tota pagina sinistra | Menu vocis → totum textum recita |
| Translatio | ⌘⌥T, linea translationis aut menu translationis |
| Explicatio | Menu explicationis → recita explicationem; aut clic dextrum in nuntium |
| Specimen | Configuratio book → Vox → vocem praesentem audi |

### 8.2 Gubernacula lineae tituli

Dum recitatur, medium lineae tituli **Subsiste**, **Perge** et **Desine** ostendit ei quod nunc sonat. Submenu non opus est.

### 8.3 Ritmus (Configuratio book → Vox)

Gubernaculum segmentatum **Ritmus** vocatur.

| Optio | Textus sub gubernaculo |
|-------|------------------------|
| **Celer** | Celer: ritmus citus. |
| **Aequilibrium** | Aequilibrium: ritmus default. |
| **Naturalis** | Naturalis: articulatio clara. |
| **Remissus** | Remissus: tardius. |

### 8.4 Processus linguae

Gubernaculum **Processus linguae** vocatur.

| Optio | Textus sub gubernaculo |
|-------|------------------------|
| **Efficiens** | Lingua · Efficiens. |
| **Aequilibrium** | Lingua · Aequilibrium. |
| **Profundum** | Lingua · Profundum. |

### 8.5 Voces explicationis

- **Vox Sinica systematis**: vox Sinica in macOS insita.
- **Voces femineae neurales in rete** (Edge TTS): Xiaoyi, Xiaoxiao et voces regionum.
- **Specimen** in configuratione prius depone, antequam voci in rete confidas. Specimina localiter conduntur.

Ante recitationem Markdown et similia **purgantur et in sententias dividuntur**.

### 8.6 Mandata vocis

Microphonum lineae tituli tene, loquere, et solve ut exsequatur. In modo legendi, ubi illa pygula deest, **Optionem et spatium tene** dum applicatio ante est. Applicatio vocem in textum vertit, deinde eodem exemplari legendi quo translatio et explicatio sententiam actioni iam praesenti attribuit. Explicare, transferre, recitare, dispositionem mutare, aperire, servare et exportare statim currunt. Evolutionem incipere aut optimizationes inspicere prius confirmationem petit. Si sententia obscura est aut nulli actioni congruit, nihil currit; applicatio solum textum auditum ostendit.

---

## 9. Textum complere

| Res | Sensus |
|-----|--------|
| Aditus | Linea tituli **Comple textum**, menu textus, ⌘⇧C |
| Initium | Selectio in pagina sinistra, aut tota pagina |
| Actus | Exemplar opus agnoscit et **id in locum continuum complet**, stilum quantum potest servans |
| Exitus | In **paginam sinistram** rescribitur (selectionem aut totum textum substituit) et, si potest, **automatice servatur** |

Ad contextum excerpti libri scholastici aut fragmenti restituendum. Noli eo uti ad opus describendum cuius ius non habes.

---

## 10. Evolutio (provectis)

> **Monitum**: evolutio fontem AIBook mutat et applicationem denuo instituit. Ea utere solum si Git et exempla servata intellegis. **Auto renovatio** in machina quam mutare non potes ne accendas.

### 10.1 Quid facit

- **Inspice**: exemplar proiectum **legit** et consilia in **seriem optimizationis** scribit. Codicem non mutat.
- **Evolue**: unam rem **expectantem** capit, **codicem mutat**, aedificat et instituit, deinde **applicationem rursus incipit**.

### 10.2 Cursus typicus

1. Tabulam **Evolutionis** ad dextram aperi.
2. **Inspice** preme et exspecta donec consilia in seriem intrent.
3. Res lege (titulum, numerum, statum).
4. **Evolue** (⌘E) preme ut **proximam rem expectantem** exsequaris.
5. **Ratiocinationem** et **gradus instrumentorum** observa.
6. Finita re applicatio rursus incipere potest. Si **Auto renovatio** accensa est et in hac sessione evolutionem iam manu incipisti, res posteriores **continua serie** currere possunt.

### 10.3 Mandata et fasciculus seriei

- Fasciculus: `~/Library/Application Support/AIBook/optimization-queue.json`
- In tabula evolutionis documentum mandatorum (UTF-8) **servare et aperire** potes.
- Inspectio **duplicia removet** secundum titulum ordinatum. Una inspectio numerum finitum proponit (circiter 8).

### 10.4 Canalis

**Analyse** et **Evolue** ambo agente Cursor locali utuntur. Nullus reditus ad exemplar legendi est. Analysis tantum legit. **Evolue** codicem mutat, aedificat et instituit. Si Cursor non paratus est, pygulae manent clausae et capsula dicit **Cursor non paratus**.

### 10.5 Tesserae et status

- Evolutio et colloquia longa intra **budgetum tesserarum** manent. Interfacies usum ostendit et missionem negat cum budgetum exhaustum est.
- Capsula lineae tituli **numerum rerum expectantium** et numerum proximae ostendere potest.

---

## 11. Species (Configuratio book → species)

| Res | Quid afficit |
|-----|--------------|
| **Themata praefixa** | Corium, charta, pygulae et ornamenta |
| **Magnitudo** | Prima optio est **Sequere thema**. Ceterae sunt magnitudines. Paginae sinistrae, divisioni modi legendi et imagini vertendae paginae valent |
| **Typus** | **Sequere thema**, **Litterae Songti**, **Litterae Kaiti**, **Litterae Heiti**, **Litterae PingFang**, **Default systematis** |

**Modus legendi rursus dividit** post mutationem. Pagina sinistra modi studii statim mutatur. Textura chartae in animatione praescriptum praesens sequitur. Pygulae ornamentorum sunt **Fascia libri**, **Angulus flexus**, **Textura chartae** et **Ornamentum capitis**.

---

## 12. Menua

Praeter pygulas lineae tituli, menua **Fasciculus / Emenda** easdem breves habent atque actiones textus et explicationis.  
**Auxilium** hunc manualem aperit et eum in Finder ostendit.

**AIBook → Configurationes** evolutioni est.  
**Configuratio book** in linea tituli lectioni, translationi, voci et speciei est.

---

## 13. Breves

| Actio | Brevis |
|-------|--------|
| Novum | ⌘N |
| Aperi | ⌘O |
| Serva | ⌘S |
| Serva sub nomine | ⌘⇧S |
| Exporta selectionem sinistram | ⌘⌥S |
| Explica selectionem | ⌘R |
| Explica totum textum | ⌘⇧R |
| Recita textum (selectionem aut totum, ut menu definit) | ⌘⌥R |
| Recita totam translationem | ⌘⌥T |
| Comple textum | ⌘⇧C |
| **Evolutio sui** (menu) / **Evolue** (linea tituli) | ⌘E |
| Intra modum legendi | ⌘⇧P |
| Mandatum vocis | Tene Optionem et spatium |
| Lectio: **Pagina prior** / **Pagina sequens** | ← / → |
| Lectio: geminae / plenum schermum | ⌘⌥1 / ⌘⌥2 |
| **Exi modum legendi**, aut restitue **Paginae geminae** | Esc |
| Selige totam paginam sinistram | ⌘⌃A |
| Selige totam translationem | ⌘⌃⇧A |

> Quaedam breves dispositionis menu **Visus** sequuntur. Super pygulam lineae tituli morare ut indicium plenum videas.

---

## 14. Data et secretum

### 14.1 Conditorium locale (Application Support)

Radix: `~/Library/Application Support/AIBook/`

| Quid | Via |
|------|-----|
| Notae mandatorum | `readme-notes.txt` |
| Series optimizationis | `optimization-queue.json` |
| Colloquia | Condita secundum viam libri |
| Scrutator capsarum | Radices apertae et status expansus |
| Specimina vocum in rete | `voices/` |
| **Auto renovatio** | `auto-evolution-active` et fasciculi cognati |

### 14.2 Rete et claves

- Petitiones **exemplaris / Cursor** ad API aut servitium Cursor a te constitutum eunt. Claves in praeferentiis localibus manent. Machinam ne communices.
- **Edge TTS** rete requirit. Voces systematis sine rete laborant.
- **Mandata vocis** microphono et agnitione vocis systematis utuntur. Cum lingua systematis agnitionem in ipso instrumento sinit, sonus in hoc Mac manet. Textus agnitus ad idem exemplar legendi mittitur quo translatio et explicatio.

---

## 15. Institutio et renovatio

### 15.1 In capsam Applicationum

```bash
cd ai-book
./scripts/build-and-install.sh
```

### 15.2 E fonte currere

```bash
swift run
```

### 15.3 Textus exempli

`Sources/AIBook/Resources/sample.txt` est textus brevis ad primam apertionem et explicationem.

---

## 16. Cursus commendati

### 16.1 Lectio cotidiana et quaestiones

1. ⌘O capitulum `.txt` aperit.
2. Locum difficilem selige → ⌘R eum explicat.
3. In campo imo ulterius interroga.
4. ⌘⇧P modum legendi intrat cum solam paginam vis.

### 16.2 Lingua aliena aut classicum

1. Textum in paginam sinistram pone.
2. Translationem **per paragraphos** aut **verbum pro verbo** incipe.
3. **Comparationem** accende et versionem stabilem **claude**.
4. ⌘⌥T translationem recitat; ⌘⌥R textum recitat.

### 16.3 Capsa multorum fasciculorum

1. **Fasciculus → Aperi capsam…** et radicem bibliothecae adde.
2. `chapter-01.txt` ut **textum** aperi.
3. `chapter-01-翻译.txt` ut **translationem** aperi.
4. Partes explicationis et translationis in eadem fenestra muta.

### 16.4 Excerptum complere

1. Excerptum libri scholastici ad sinistram appone.
2. ⌘⇧C textum complet.
3. Effectum inspice, deinde ⌘S serva.

---

## 17. Quaestiones

**Pygula explicationis dicit exemplar non constitutum esse.**  
**Configurationem book → exemplar** aperi, praebitorem elige et clavem API scribe. In hoc Mac Ollama electio usitata est.

**Cursor locale non adest.**  
Node.js, `npm install` in cursor-bridge, clavem API Cursor et viam in Configuratione evolutionis inspice.

**Tabula translationis cineracea est.**  
Prius translationem verbum pro verbo aut per paragraphos fini, et JSON blocos alignationis validos continere debet. Si alignatio evanuit, **Aligna translationem** utere.

**Numeri paginarum in modo legendi mutati sunt.**  
Magnitudo typi aut fenestra rursus dividit. Id exspectatur. Index paginarum geminarum restituitur cum potest.

**Applicatio post evolutionem aliter agit.**  
Evolutio copiam localem installatam AIBook mutat. Fontem in Git tene, et **Auto renovatio** solum data opera utere.

**Hic manualis et interfacies dissentiunt.**  
**Versioni AIBook installatae** crede. Super pygulam morare ut indicium recens videas.

---

## 18. Versio et documenta

- Hic manualis in applicatione distribuitur et e menu **Auxilium** aperitur.
- Repositorium etiam notas consilii habet (modus legendi, species, evolutio) ad evolutionem programmatis.
- README proiecti institutionem brevem Ollama et Cursor continet.

---

**Gratias quod AIBook uteris.**
