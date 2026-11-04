# Manuel AIBook

> **AIBook** (identifiant `ai-book`) est une application native de lecture assistée pour macOS : la **page de gauche** lit et modifie un texte local, la **page de droite** utilise l’IA pour l’explication, la traduction, la lecture à voix haute et, si vous le voulez, la mise à jour de l’application elle-même.  
> **Système** : macOS 13 ou plus récent.  
> **Rôle** : aider à comprendre le sens littéral, le contexte et une traduction à côté du texte, et lire sans distraction. Ce n’est pas un lecteur de livres numériques complet.

Le manuel dans l’application suit la langue de l’interface. Ce fichier est l’édition française. Le chinois simplifié est `功能说明书.md` ; les autres éditions sont, dans le même dossier, `功能说明书-en.md`, `功能说明书-ja.md`, `功能说明书-de.md`, `功能说明书-it.md`, `功能说明书-la.md` et `功能说明书-el.md`. Après une modification, copiez le fichier du même nom dans `Sources/AIBook/Resources/` avant d’empaqueter.

---

## Comment l’ouvrir dans l’application

- Barre des menus **Aide → Manuel AIBook** (fenêtre dans l’application ; le texte peut être sélectionné et copié)
- **Aide → Afficher le manuel dans le Finder** (sélectionne le fichier du manuel de la langue actuelle)
- **Ouvrir avec l’app par défaut** dans la barre de titre de la fenêtre du manuel
- Le bouton **Manuel** dans la barre de titre des **Réglages book** et des **Réglages évolution**

---

## 1. Aperçu

### 1.1 Ce que vous pouvez faire

- Lire et modifier un `.txt` local sur la page de gauche.
- Demander l’explication d’une sélection ou du texte entier, puis poursuivre dans la même conversation.
- Traduire mot à mot ou paragraphe par paragraphe, et voir un tableau texte–traduction.
- Faire lire le texte, la traduction ou une explication.
- Entrer en mode lecture et tourner les pages comme dans un livre ouvert.
- Utiliser, si vous le voulez, l’évolution par IA : analyser le projet, appliquer une entrée de la file, puis reconstruire l’application.

### 1.2 Le bureau

La fenêtre est un bureau. À gauche, le texte ; à droite, l’assistant. Le mode lecture cache l’assistant et montre un livre que l’on feuillette.

### 1.3 Deux modes de premier niveau

| Mode | Usage |
|------|--------|
| **Mode étude** | Texte à gauche ; explication, traduction et lecture à droite |
| **Mode lecture** | Feuilletage immersif. Pas d’explication ni de traduction tant que vous n’êtes pas revenu |

Bascule dans la barre de titre : **Mode lecture** (⌘⇧P) et **Mode étude**.

---

## 2. Fenêtre principale (mode étude)

La barre de titre réunit le document, l’explication, la traduction, la lecture, la disposition et les réglages. La page de gauche est le texte. La page de droite est l’assistant de lecture, ou **évolution par IA** lorsque cet onglet est choisi.

### 2.1 Disposition

| Disposition | Sens |
|-------------|------|
| **Double page** | Page de gauche et page de droite côte à côte |
| **Original en plein écran** | ⌘⌥2. Le texte occupe le bureau |
| **Plein écran droit** | ⌘⌥3. L’assistant occupe le bureau |

**Esc** rétablit la double page.

### 2.2 Volets de l’assistant

| Volet | Contenu |
|-------|---------|
| **Explication** | Conversation en plusieurs tours, sortie en flux, enregistrer / ouvrir / effacer |
| **Traduction** | JSON de traduction ou tableau comparatif, modifiable, avec alignement et verrouillage |

Les capsules **Explication** / **Traduction** de la barre de titre changent de volet. Une action de traduction bascule vers le volet traduction.

### 2.3 Concentration

Les zones d’explication et de traduction peuvent masquer la barre et la saisie. On les retrouve avec **Lecture focus**, **Afficher la barre** et **Afficher la saisie**.

---

## 3. Mode lecture

### 3.1 Entrer et sortir

| Action | Comment |
|--------|---------|
| Entrer | Barre de titre **Mode lecture**, raccourci **⌘⇧P** (un texte non vide doit être ouvert) |
| Sortir | **Quitter le mode lecture**, ou **Esc** |

Le mode lecture n’explique pas et ne traduit pas. Revenez au mode étude pour l’IA.

### 3.2 Disposition

| Option | Sens |
|--------|------|
| **Double page** | Page N à gauche, page N+1 à droite. Le **dos reste fixe** |
| **Plein écran** | Une page occupe la fenêtre |
| Bascule | **Double page / Plein écran** dans la barre de lecture, ou **⌘⌥1 / ⌘⌥2** |

### 3.3 Tourner les pages

| Geste | Comportement |
|-------|----------------|
| **← / →** | Double page précédente / suivante |
| **Clic sur la page gauche / droite** | Avancer / reculer en double page |
| **Glissement horizontal** | Suit le doigt. Au-delà d’environ un tiers, la page finit de tourner ; sinon elle revient |
| **Flèches de la barre de titre** | Comme le clavier |

L’animation courbe **une feuille**. Le dos ne se déforme pas.

### 3.4 Pages et progression

- La pagination utilise les mêmes **corps, police, interligne et marges** que la page de gauche (**Réglages book → apparence**).
- Un changement de fenêtre ou de composition **repagine** et tente de garder l’endroit.
- Chaque fichier retient son **index de double page**. Le mode lecture le restaure.
- Le pied de page affiche par exemple **pages 3–4 sur 128** (double page) ou **page N sur M** (plein écran).

---

## 4. Documents et fichiers

### 4.1 Types de documents

- Le format principal est le **texte brut UTF-8 `.txt`**.
- La page de gauche est **librement modifiable**. Vous pouvez sélectionner, copier et déposer un fichier sur la fenêtre.

### 4.2 Menu Fichier et texte

| Action | Raccourci | Note |
|--------|-----------|------|
| **Nouvel original** | ⌘N | Vider la page de gauche et commencer un document |
| **Ouvrir l’original…** | ⌘O | Choisir un `.txt` local. Dans la barre : **Ouvrir l’original** |
| **Ouvrir le dossier de l’original…** | | Voir 4.4. Dans la barre : **Ouvrir le dossier de l’original** |
| **Enregistrer l’original** | ⌘S | Enregistrer au chemin actuel |
| **Enregistrer l’original sous…** | ⌘⇧S | Enregistrer la page de gauche dans un nouveau fichier |
| **Enregistrer l’original comme AIBook…** | | Original et traductions et explications déjà là, un fichier `.aibook` |
| **Exporter la sélection de l’original…** | ⌘⌥S | Exporter seulement la sélection actuelle |
| **Tout sélectionner (original)** | ⌘⌃A | |
| **Compléter l’original** | ⌘⇧C | Voir la section 9 |

Sans fichier externe, la page de gauche charge les **notes de commandes** (voir 4.3).

### 4.3 Notes de commandes (page de gauche par défaut)

- Au premier lancement, ou sans fichier ouvert, la page de gauche montre des notes pour vos remarques ou un ancien texte d’évolution.
- Enregistrées dans `~/Library/Application Support/AIBook/readme-notes.txt`.
- Sans copie locale, l’application revient au modèle intégré ou au `readme.txt` du projet.
- **⌘S** enregistre les notes dans Application Support.

> La **file d’optimisation** est désormais `optimization-queue.json`. Les notes ne sont plus la source des commandes d’évolution, mais elles restent un brouillon personnel.

### 4.4 Navigateur de dossiers (bibliothèque)

**Entrée** : **Ouvrir le dossier de l’original…**. Le titre de la fenêtre est **Navigateur dossiers**. La barre latérale s’appelle **Dossiers ouverts**.

| Étape | Effet |
|-------|--------|
| Ajouter un dossier | **+** dans la barre latérale, puis choisir la racine des livres |
| Changer de dossier | Le choisir dans la liste des dossiers ouverts |
| Parcourir | Déplier les sous-dossiers dans l’arbre central |
| Choisir la cible | **Ouvrir dans l’original de la page gauche**, **Ouvrir dans la traduction de la page droite**, **Ouvrir dans l’explication de la page droite** |
| Ouvrir | Double-clic, ou confirmer en bas |

Les dossiers ajoutés et leur état déplié sont **conservés**. Cela sert à passer, dans une même bibliothèque, entre des `.txt`, des `-翻译.txt` et des brouillons d’explication.

---

## 5. Moteurs d’IA et réglages

L’explication, la traduction et **Compléter l’original** utilisent le modèle de lecture dans **Réglages book**. L’évolution par IA utilise toujours Cursor, dans **Réglages évolution**. La barre de titre ne propose pas de bascule.

### 5.1 Modèle de lecture, Cursor pour l’évolution

| Usage | Commande |
|-------|----------|
| Expliquer, traduire, compléter l’original | **Réglages book** → **Modèles IA** → **Fournisseur actif** |
| **Analyser** et **Évoluer** | **Modèle Cursor** dans **Réglages évolution** |

La pastille de la barre de titre montre le nom du fichier et **Non enregistré**. Sans modèle de lecture, elle dit **LLM book non configuré**. Si Cursor n’est pas prêt : **Cursor non prêt**.

### 5.2 Réglages book

**Entrée** : le bouton **Réglages book** de la barre de titre.

#### Modèle

- L’adresse, la clé et le modèle par défaut sont enregistrés **par fournisseur**.
- Exemples intégrés :

| Fournisseur | Usage typique |
|-------------|---------------|
| OpenAI | Modèles GPT dans le nuage |
| DeepSeek | Chinois à moindre coût |
| Ollama | **Gratuit sur ce Mac** (recommandé pour la lecture quotidienne) |
| Moonshot / Qwen / Zhipu | Modèles dans le nuage en Chine |
| Personnalisé | Tout point d’accès compatible OpenAI |

**Démarrage rapide d’Ollama** :

```bash
ollama serve
ollama pull llama3.2
```

Choisissez Ollama dans les Réglages book, puis **cherchez les modèles installés sur ce Mac**. Si Ollama exige une clé API, saisissez-la là.

- **Langues de traduction** et **langues d’explication** : vous pouvez en choisir plusieurs parmi le chinois simplifié, l’anglais, le japonais, l’allemand, le français, l’italien, le latin et le grec. La prochaine génération les produit dans l’ordre coché. Les résultats déjà présents restent sur la page de droite et se changent. Un fichier `.aibook` les conserve tous.
- **Part d’extrait (page gauche)** : quelle portion du texte de gauche accompagne chaque demande, pour rester dans la fenêtre du modèle.

#### Voix

Voir la section 8.

#### Apparence

Voir la section 11.

### 5.3 Réglages évolution

**Entrée** : menu **AIBook → Réglages** (onglet évolution).

| Réglage | Sens |
|---------|------|
| Clé API Cursor | Ou la variable d’environnement `CURSOR_API_KEY` |
| Modèle Cursor | Par exemple un modèle Composer |
| Chemin de cursor-bridge | Le dossier `cursor-bridge` du projet |
| **Mise à niveau auto** | Après un clic sur **Évoluer**, les entrées restantes peuvent s’enchaîner (voir la section 10) |

**Dépendance Cursor locale** :

```bash
cd ai-book/cursor-bridge
npm install
```

**Node.js 18 ou plus** est requis.

---

## 6. Explication

### 6.1 Déroulement

1. **Sélectionnez** un passage à gauche, ou laissez la sélection vide pour prendre tout le texte comme contexte.
2. Cliquez **Expliquer la sélection** (⌘R) ou **Expliquer tout** (⌘⇧R), ou utilisez le menu d’explication.
3. Le modèle écrit chaque langue d’explication dans le volet **Explication**. Avec plusieurs langues, le titre de la feuille indique le nom de la langue et le numéro.
4. À la fin, l’application peut **lire** la dernière langue réussie (vous pouvez l’arrêter ; voir la section 8).

L’explication est écrite dans la langue choisie. Si la cible est le chinois simplifié, le chinois classique est expliqué en chinois écrit moderne. La page de droite montre une langue à la fois. **Afficher l’explication** et le menu d’explication passent d’une explication déjà produite à une autre, sans rappeler le modèle. Ouvrir ou enregistrer un `.aibook` conserve chaque langue. Ouvrir une `.txt` d’explication n’écrit que dans la langue affichée. Nouveau et Effacer ne retirent que cette langue.

### 6.2 Questions suivantes

- Le **champ** en bas de la page de droite poursuit la conversation, avec le fichier actuel et les tours précédents.
- La conversation d’un livre est **rétablie autant que possible** après un redémarrage, selon le chemin du fichier.

### 6.3 Documents d’explication

| Action | Sens |
|--------|------|
| Nouveau | Effacer l’explication de la langue affichée ; les autres restent dans le paquet |
| Ouvrir | Charger une `.txt` d’explication dans la langue affichée |
| Enregistrer | Enregistrer l’explication actuelle en texte UTF-8 |
| Tout sélectionner | Sélectionner tout le texte de la zone d’explication |
| Effacer l’explication | Supprimer l’explication de la langue actuelle |
| Lire l’explication | Lire toute l’explication, ou arrêter |

### 6.4 Un message

Un **clic droit** sur une bulle la copie, la supprime, ou lit **cette réponse de l’IA** (le menu suit la version installée).

### 6.5 Sélection

Un bouton de la barre de titre peut effacer un instant la surbrillance à gauche. L’application **garde la dernière sélection non vide**, donc **Expliquer la sélection** utilise encore le texte que vous venez de choisir.

---

## 7. Traduction

### 7.1 Deux modes

| Mode | Entrée | Résultat |
|------|--------|----------|
| **Mot à mot** | **Traduction** → **Mot à mot** | Découpe le texte en caractères ou en mots, avec une courte note. Pour une lecture serrée |
| **Paragraphe entier** | **Traduction** → **Paragraphe entier** | Garde la structure des paragraphes dans une traduction suivie. Pour un chapitre |

**Texte source** : la **sélection actuelle** à gauche, ou **toute la page de gauche** si rien n’est sélectionné.

**Langues de traduction** : plusieurs sous **Réglages book → modèle → langues de traduction**, ou dans le **menu traduction**. La génération suit cet ordre. La page de droite montre une langue à la fois ; **Afficher la traduction** passe d’un résultat déjà produit à un autre. Un `.aibook` conserve chaque langue. Le chinois classique visé vers le chinois simplifié devient du chinois écrit moderne.

Le résultat est un **JSON** structuré (avec des blocs d’alignement). Vous pouvez **modifier** le texte ou le tableau directement.

### 7.2 Fichiers de traduction

| Action | Sens |
|--------|------|
| Ouvrir une traduction | Charger un JSON ou un texte de traduction existant |
| Enregistrer la traduction | Un nom courant est `nom-d-origine-翻译.txt` |
| Effacer la traduction | Supprimer la traduction actuelle et son alignement |
| Tout sélectionner | ⌘⌃⇧A |
| Lire la traduction | ⌘⌥T, ou **Lire** dans la barre de traduction |

### 7.3 Tableau et alignement

Lorsque le JSON contient des **blocs d’alignement** valides (caractère, mot ou paragraphe) :

| Commande | Sens |
|----------|------|
| **Comparaison de traduction** | La page de droite montre un **tableau texte–traduction** |
| **Aligner la traduction** | Après un changement à gauche, recalculer la correspondance |
| **Verrouiller la traduction** | Empêche un réalignement complet accidentel. L’édition d’une ligne reste en général possible |
| **Déverrouiller la traduction** | Autorise de nouveau un réalignement complet |

Si la page de gauche change beaucoup, la barre dit : **Alignement obsolète. Touchez « Aligner la traduction » ou « Aligner l’explication ».** Les boutons de l’explication sont **Comparaison d’explication**, **Aligner l’explication**, **Verrouiller l’explication** et **Déverrouiller l’explication**.

### 7.4 Défilement avec la page de gauche

En **double page** du mode étude, avec la **comparaison** activée et un alignement encore valide, le défilement à gauche peut **surligner la ligne correspondante**. Le détail suit la version installée.

---

## 8. Lecture à voix haute

### 8.1 Points d’entrée

| Quoi | Entrée habituelle |
|------|-------------------|
| Sélection à gauche | Menu lecture → lire la sélection du texte ; ⌘⌥R (sélection ou texte entier, selon le menu) |
| Page de gauche entière | Menu lecture → lire tout le texte |
| Traduction | ⌘⌥T, la barre de traduction ou le menu traduction |
| Explication | Menu explication → lire l’explication ; ou clic droit sur un message |
| Essai | Réglages book → Voix → écouter la voix actuelle |

### 8.2 Commandes de la barre de titre

Pendant la lecture, le milieu de la barre de titre montre **Pause**, **Reprendre** et **Arrêter**. Le menu s’appelle **Parole**. Aucun sous-menu n’est nécessaire.

### 8.3 Rythme (Réglages book → Voix)

Le contrôle segmenté s’appelle **Rythme**.

| Option | Texte sous le contrôle |
|--------|------------------------|
| **Rapide** | Rapide : rythme vif. |
| **Équilibré** | Équilibré : rythme par défaut. |
| **Naturel** | Naturel : articulation claire. |
| **Détendu** | Détendu : plus lent. |

### 8.4 Traitement langue

Le contrôle s’appelle **Traitement langue**.

| Option | Texte sous le contrôle |
|--------|------------------------|
| **Efficace** | Langue · Efficace. |
| **Équilibré** | Langue · Équilibré. |
| **Profond** | Langue · Profond. |

### 8.5 Voix de l’explication

- **Voix chinoise du système** : une voix chinoise intégrée à macOS.
- **Voix féminines neuronales en ligne** (Edge TTS) : Xiaoyi, Xiaoxiao et des voix régionales.
- Téléchargez l’**échantillon** dans les réglages avant de compter sur une voix en ligne. Les échantillons sont mis en cache localement.

Avant la lecture, le Markdown et les balises semblables sont **nettoyés et coupés en phrases**.

### 8.6 Commandes vocales

Maintenez le microphone de la barre de titre, parlez, puis relâchez pour exécuter. En mode lecture, où ce bouton est absent, **maintenez Option+espace** tant que l’application est au premier plan. L’application transforme la parole en texte, puis utilise le même modèle de lecture que la traduction et l’explication pour rattacher la phrase à une action existante. Expliquer, traduire, lire, changer la disposition, ouvrir, enregistrer et exporter s’exécutent tout de suite. Lancer l’évolution ou analyser les optimisations demande d’abord une confirmation. Si la phrase est peu claire ou ne correspond à aucune action, rien ne s’exécute ; l’application montre seulement le texte entendu.

---

## 9. Compléter le texte

| Élément | Sens |
|---------|------|
| Entrée | Barre de titre **Compléter le texte**, menu du texte, ⌘⇧C |
| Entrée de texte | Une sélection à gauche, ou toute la page |
| Comportement | Le modèle reconnaît l’œuvre et **la complète en un passage continu**, en gardant le style autant que possible |
| Sortie | Réécrite sur la **page de gauche** (remplace la sélection ou tout le texte) et **enregistrée automatiquement** si c’est possible |

Cela sert à retrouver le contexte d’un extrait de manuel ou d’un fragment. Ne l’utilisez pas pour copier une œuvre que vous n’avez pas le droit d’utiliser.

---

## 10. Évolution par IA (avancé)

> **Avertissement** : l’évolution modifie le code source d’AIBook et réinstalle l’application. Ne l’utilisez que si vous connaissez Git et les sauvegardes. N’activez pas la **Mise à niveau auto** sur une machine que vous ne pouvez pas modifier.

### 10.1 Ce qu’elle fait

- **Analyser** : le modèle **lit** le projet et écrit des suggestions dans la **file d’optimisation**. Il ne modifie pas le code.
- **Évoluer** : prend une entrée **en attente**, **modifie le code**, construit et installe, puis **relance l’application**.

### 10.2 Un parcours typique

1. Ouvrez l’onglet **Évolution par IA** à droite.
2. Cliquez **Analyser** et attendez que les suggestions entrent dans la file.
3. Lisez les entrées (titre, numéro, état).
4. Cliquez **Évoluer** (⌘E) pour exécuter la **prochaine entrée en attente**.
5. Suivez le **raisonnement** et les **étapes d’outils**.
6. L’application peut redémarrer à la fin. Si la **Mise à niveau auto** est active et que vous avez déjà lancé une évolution à la main dans cette session, les entrées suivantes peuvent **s’enchaîner**.

### 10.3 Commandes et fichier de file

- Fichier : `~/Library/Application Support/AIBook/optimization-queue.json`
- Dans l’onglet évolution, vous pouvez **enregistrer et ouvrir** un document de commandes (UTF-8).
- L’analyse **retire les doublons** selon un titre normalisé. Une analyse propose un nombre limité d’entrées (environ 8).

### 10.4 Canal

**Analyser** et **Évoluer** passent tous deux par l’agent Cursor local. Il n’y a pas de repli vers le modèle de lecture. L’analyse ne fait que lire. **Évoluer** modifie le code, construit et installe. Si Cursor n’est pas prêt, les boutons restent inactifs et la pastille dit **Cursor non prêt**.

### 10.5 Jetons et état

- L’évolution et les longues conversations restent dans un **budget de jetons**. L’interface montre l’usage et refuse l’envoi lorsque le budget est épuisé.
- La capsule de la barre de titre peut montrer le **nombre d’entrées en attente** et le numéro de la suivante.

---

## 11. Apparence (Réglages book → apparence)

| Élément | Effet |
|---------|--------|
| **Thèmes** | Cuir, papier, boutons et ornements |
| **Taille** | Le premier élément est **Suivre le thème**. Les autres sont des corps. Ils agissent sur la page de gauche, la pagination du mode lecture et l’instantané du feuilletage |
| **Police** | **Suivre le thème**, **Police Songti**, **Police Kaiti**, **Police Heiti**, **Police PingFang**, **Valeur par défaut du système** |

**Le mode lecture repagine** après un changement. La page de gauche du mode étude se met à jour tout de suite. La texture du papier dans l’animation suit le préréglage actuel. Les interrupteurs d’ornement s’appellent **Ruban marque-page**, **Coin plié**, **Texture papier** et **Ornement d’en-tête**.

---

## 12. Menus

Outre les boutons de la barre de titre, les menus **Fichier / Édition** réunissent les mêmes raccourcis que les actions du texte et de l’explication.  
**Aide** ouvre ce manuel et le montre dans le Finder.

**AIBook → Réglages** concerne l’évolution.  
**Réglages book** dans la barre de titre concerne la lecture, la traduction, la voix et l’apparence.

---

## 13. Raccourcis

| Action | Raccourci |
|--------|-----------|
| Nouveau | ⌘N |
| Ouvrir | ⌘O |
| Enregistrer | ⌘S |
| Enregistrer sous | ⌘⇧S |
| Exporter la sélection de gauche | ⌘⌥S |
| Expliquer la sélection | ⌘R |
| Expliquer tout le texte | ⌘⇧R |
| Lire le texte (sélection ou tout, selon le menu) | ⌘⌥R |
| Lire toute la traduction | ⌘⌥T |
| Compléter le texte | ⌘⇧C |
| **Auto-évolution** (menu) / **Évoluer** (barre de titre) | ⌘E |
| Entrer en mode lecture | ⌘⇧P |
| Commande vocale | Maintenir Option+espace |
| Lecture : **Page précédente** / **Page suivante** | ← / → |
| Lecture : double page / plein écran | ⌘⌥1 / ⌘⌥2 |
| **Quitter le mode lecture**, ou rétablir **Double page** | Esc |
| Tout sélectionner à gauche | ⌘⌃A |
| Tout sélectionner dans la traduction | ⌘⌃⇧A |

> Certains raccourcis de disposition suivent le menu **Présentation**. Survolez un bouton de la barre de titre pour voir l’indication complète.

---

## 14. Données et confidentialité

### 14.1 Stockage local (Application Support)

Racine : `~/Library/Application Support/AIBook/`

| Quoi | Chemin |
|------|--------|
| Notes de commandes | `readme-notes.txt` |
| File d’optimisation | `optimization-queue.json` |
| Conversations | Cache selon le chemin du livre |
| Navigateur de dossiers | Racines ouvertes et état déplié |
| Échantillons de voix en ligne | `voices/` |
| **Mise à niveau auto** | `auto-evolution-active` et fichiers liés |

### 14.2 Réseau et clés

- Les demandes **modèle / Cursor** partent vers l’API ou le service Cursor que vous avez configuré. Les clés restent dans les préférences locales. Ne partagez pas la machine.
- **Edge TTS** a besoin du réseau. Les voix système fonctionnent hors ligne.
- Les **commandes vocales** utilisent le microphone et la reconnaissance vocale du système. Lorsque la langue du système permet la reconnaissance sur l’appareil, l’audio reste sur ce Mac. Le texte reconnu est envoyé au même modèle de lecture que la traduction et l’explication.

---

## 15. Installation et mise à jour

### 15.1 Installer dans le dossier Applications

```bash
cd ai-book
./scripts/build-and-install.sh
```

### 15.2 Lancer depuis les sources

```bash
swift run
```

### 15.3 Texte d’exemple

`Sources/AIBook/Resources/sample.txt` est un court texte pour un premier essai d’ouverture et d’explication.

---

## 16. Parcours suggérés

### 16.1 Lecture quotidienne et questions

1. ⌘O ouvre un chapitre `.txt`.
2. Sélectionnez un passage difficile → ⌘R pour l’expliquer.
3. Posez une suite dans le champ du bas.
4. ⌘⇧P entre en mode lecture lorsque vous ne voulez que la page.

### 16.2 Une langue étrangère ou un classique

1. Chargez le texte sur la page de gauche.
2. Lancez une traduction **par paragraphe** ou **mot à mot**.
3. Activez la **comparaison** et **verrouillez** une version stable.
4. ⌘⌥T lit la traduction ; ⌘⌥R lit le texte.

### 16.3 Un dossier de nombreux fichiers

1. **Fichier → Ouvrir un dossier…** et ajoutez la racine de la bibliothèque.
2. Choisissez `chapter-01.txt` → ouvrez-le comme **texte**.
3. Choisissez `chapter-01-翻译.txt` → ouvrez-le comme **traduction**.
4. Changez les volets explication et traduction dans la même fenêtre.

### 16.4 Compléter un extrait

1. Collez un extrait de manuel à gauche.
2. ⌘⇧C complète le texte.
3. Vérifiez le résultat, puis ⌘S pour enregistrer.

---

## 17. Questions

**Le bouton d’explication dit que le modèle n’est pas configuré.**  
Ouvrez **Réglages book → modèle**, choisissez un fournisseur et saisissez une clé API. Sur ce Mac, Ollama est le choix habituel.

**Cursor local n’est pas disponible.**  
Vérifiez Node.js, `npm install` dans cursor-bridge, la clé API Cursor et le chemin dans les Réglages évolution.

**Le tableau de traduction est grisé.**  
Terminez d’abord une traduction mot à mot ou par paragraphe, et le JSON doit contenir des blocs d’alignement valides. Si l’alignement est périmé, utilisez **Aligner la traduction**.

**Les numéros de page ont changé en mode lecture.**  
Changer le corps ou la fenêtre repagine. C’est attendu. L’index de double page est rétabli lorsque c’est possible.

**L’application se comporte autrement après une évolution.**  
L’évolution modifie la copie locale installée d’AIBook. Gardez les sources dans Git, et n’utilisez la **Mise à niveau auto** que si vous le voulez vraiment.

**Ce manuel et l’interface ne concordent pas.**  
Fiez-vous à la **version d’AIBook installée**. Survolez un bouton pour l’indication actuelle.

---

## 18. Version et documents

- Ce manuel est livré dans l’application et s’ouvre depuis le menu **Aide**.
- Le dépôt contient aussi des notes de conception (mode lecture, apparence, évolution) pour le développement.
- Le README du projet donne la courte installation d’Ollama et de Cursor.

---

**Merci d’utiliser AIBook.**
