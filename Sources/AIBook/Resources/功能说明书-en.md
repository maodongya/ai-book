# AIBook User Manual

> **AIBook** (project id `ai-book`) is a native macOS reading assistant: the **left page** reads and edits local text, and the **right page** uses AI for explanation, translation, reading aloud, and (optionally) upgrading the app itself.  
> **System**: macOS 13 or later.  
> **Purpose**: help you understand wording, context, and a translation beside the source, and read without distraction. It does not replace a full ebook reader.

The in-app manual follows the interface language. This file is the English edition. Simplified Chinese is `功能说明书.md`; the other editions are `功能说明书-ja.md`, `功能说明书-de.md`, `功能说明书-fr.md`, `功能说明书-it.md`, `功能说明书-la.md`, and `功能说明书-el.md` in the same folder. After editing, copy the file of the same name into `Sources/AIBook/Resources/` before packaging.

---

## How to open it in the app

- Menu bar **Help → AIBook User Manual** (an in-app window; you can select and copy the text)
- **Help → Reveal Manual in Finder** (selects the manual file for the current language)
- **Open in Default App** in the manual window’s title bar
- The **Manual** button in the title bar of **Book Settings** and **Evolution Settings**

---

## 1. Overview

### 1.1 What you can do

- Read and edit a local `.txt` on the left page.
- Ask for an explanation of a selection or the whole text, then follow up in the same conversation.
- Translate word by word or paragraph by paragraph, and view a source–translation table.
- Read the source, the translation, or an explanation aloud.
- Enter reading mode and turn pages as a two-page book.
- Optionally use AI evolution to analyze the project and apply a queued change, then rebuild the app.

### 1.2 The desk

The window is a desk: the left page is the source, the right page is the assistant. Reading mode hides the assistant and shows a book you can turn.

### 1.3 Two top-level modes

| Mode | What it is for |
|------|----------------|
| **Study mode** | Source on the left; explanation, translation, and speech on the right |
| **Reading mode** | Immersive page turning. No explanation or translation until you return |

Switch from the title bar: **Reading Mode** (⌘⇧P) and **Study mode**.

---

## 2. Main window (study mode)

The title bar holds document actions, explanation, translation, speech, layout, and settings. The left page is the source. The right page is the reading assistant, or **AI evolution** when that tab is selected.

### 2.1 Layout

| Layout | Meaning |
|--------|---------|
| **Spread** | ⌘⌥1. Left page and right page side by side |
| **Source full screen** | ⌘⌥2. The source fills the desk |
| **Right Full Screen** | ⌘⌥3. The assistant fills the desk |

**Esc** restores the spread from a focused page.

### 2.2 Panes inside the reading assistant

| Pane | Contents |
|------|----------|
| **Explanation** | A multi-turn conversation, streamed output, save / open / clear |
| **Translation** | Translation JSON or a comparison table, editable, with align and lock |

The pane buttons are **Explain** and **Translate**. The menus above them are **Explanation** and **Translation**. A translation action switches to **Translate**. **Show explanation** and **Show translation** switch results that already exist.

### 2.3 Focus

The explanation and translation areas can hide the toolbar and the input. Restore them with **Focus reading**, **Show toolbar**, and **Show input**.

---

## 3. Reading mode

### 3.1 Enter and leave

| Action | How |
|--------|-----|
| Enter | Title bar **Reading mode**, shortcut **⌘⇧P** (a non-empty source must be open) |
| Leave | Title bar **Study Mode**, or **Esc** |

Reading mode does not explain or translate. Return to study mode when you need AI.

### 3.2 Layout

| Option | Meaning |
|--------|---------|
| **Spread** | Page N on the left, page N+1 on the right. The **spine stays fixed** |
| **Full Screen** | One page fills the window |
| Switch | **Spread** / **Full Screen**, or **⌘⌥1 / ⌘⌥2** |

### 3.3 Turning pages

| Gesture | Behavior |
|---------|----------|
| **← / →** | Previous spread / next spread |
| **Click the left / right page** | Forward / back in the spread layout |
| **Horizontal drag** | Follows the finger. Past about one third, the page finishes the turn; otherwise it springs back |
| **Previous Page** / **Next Page** | Same as the keyboard |

The animation curls **one sheet**. The spine does not bend.

### 3.4 Pages and progress

- Pagination uses the same **size, font, line spacing, and margins** as the left page (**Book Settings → appearance**).
- Resizing the window or changing type **repaginates** and tries to keep your place.
- Each file remembers its **spread index**. Entering reading mode again restores it.
- The footer reads like **Pages 3–4 of 128** (spread) or **Page N of M** (full screen).

---

## 4. Documents and files

### 4.1 Document types

- The main format is **UTF-8 plain text `.txt`**.
- The left page is **freely editable**. You can select, copy, and drag a file onto the window.

### 4.2 File menu and source actions

| Name on the menu | Shortcut | Notes |
|--------|----------|-------|
| **New source** | ⌘N | Clear the left page and start a new document |
| **Open source…** | ⌘O | Choose a local `.txt`. The toolbar item is **Open source** |
| **Open source folder…** | | Opens the folder browser (see 4.4). The toolbar item is **Open source folder** |
| **Save source** | ⌘S | Save to the current path |
| **Save source as…** | ⌘⇧S | Save the left page as a new file |
| **Save source as AIBook…** | | Source plus existing translations and explanations, one `.aibook` file |
| **Export source selection…** | ⌘⌥S | Export only the current selection |
| **Select all source** | ⌘⌃A | The menu item is **Select all source** |
| **Classic supplement** | ⌘⇧C | See section 9 |

When no external file is open, the left page loads the **command notes** (see 4.3).

### 4.3 Command notes (default left page)

- On first launch, or when no file is open, the left page shows command notes for your own remarks or older evolution text.
- Saved at `~/Library/Application Support/AIBook/readme-notes.txt`.
- If there is no local copy, the app falls back to the built-in or project `readme.txt` template.
- **⌘S** saves the command notes into Application Support.

> The **optimization queue** is now `optimization-queue.json`. Command notes are no longer the command source for evolution, but they remain a personal scratch pad.

### 4.4 Folder browser (library)

**Entry**: **Open source folder…**. The window title is **Folder Browser**.

| Step | What happens |
|------|----------------|
| Add a folder | **+** in the sidebar, then choose a book root |
| Switch folder | Select it under **Open Folders** |
| Browse | Expand subfolders in the middle tree |
| Choose the target | **Open on the source page**, **Open on the translation page**, or **Open on the explanation page** |
| Open | Double-click, or confirm at the bottom |

Added folders and their expanded state are **saved** and return at the next launch. Use this to move among `.txt` files, `-翻译.txt` translations, and explanation drafts in one library.

---

## 5. AI backends and settings

Explanation, translation, and classic supplement share the book model in **Book Settings**. AI evolution always uses Cursor, configured in **Evolution Settings**. There is no title-bar switch between them.

### 5.1 Book model for reading, Cursor for evolution

| Use | Control |
|-----|---------|
| Explain, translate, classic supplement | **Book Settings** → **AI Models** → **Active provider** |
| Analyze and evolve | **Cursor model** in **Evolution Settings**, plus the Cursor API key and cursor-bridge |

The title-bar pill shows the file name and **Unsaved**. If the book model is missing, it says **Book LLM not set**. If Cursor is not ready, it says **Cursor not ready**.

### 5.2 Book Settings

**Entry**: the **Book Settings** button in the title bar.

#### Model

- API address, key, and default model are stored **per provider**.
- Built-in examples:

| Provider | Typical use |
|----------|-------------|
| OpenAI | Cloud GPT models |
| DeepSeek | Lower-cost Chinese |
| Ollama | **Free on this Mac** (recommended for daily reading) |
| Moonshot / Qwen / Zhipu | Cloud models in China |
| Custom | Any OpenAI-compatible endpoint |

**Ollama quick start**:

```bash
ollama serve
ollama pull llama3.2
```

Choose Ollama in Book Settings, then **scan models installed on this Mac**. If Ollama requires an API key, enter it there.

- **Translation languages** and **explanation languages**: you can select more than one of Simplified Chinese, English, Japanese, German, French, Italian, Latin, or Greek. The next run produces them in the checked order. Existing results stay on the right page and can be switched. Saving an `.aibook` file keeps all of them.
- **Source excerpt ratio**: how much of the left-page source is sent with each request, so the prompt stays inside the model window.

#### Speech

See section 8.

#### Appearance

See section 11.

### 5.3 Evolution Settings

**Entry**: menu **AIBook → Settings** (the evolution tab).

| Setting | Meaning |
|---------|---------|
| Cursor API key | Or the environment variable `CURSOR_API_KEY` |
| Cursor model | For example a Composer model |
| cursor-bridge path | The `cursor-bridge` directory in the project |
| **Auto Upgrade** | After you click **Evolve**, remaining queue items can run one after another (see section 10) |

**Local Cursor dependency**:

```bash
cd ai-book/cursor-bridge
npm install
```

**Node.js 18+** is required.

---

## 6. Explanation

### 6.1 Basic flow

1. **Select** a passage on the left page, or leave the selection empty to use the whole text as context.
2. Click **Explain Selection** (⌘R) or **Explain All** (⌘⇧R), or use the explanation menu in the title bar.
3. The model writes each explanation language into the **Explanation** pane. When several languages are running, the sheet title shows the language name and the index.
4. When explanation finishes, the app can **read aloud** the last successful language (you can stop it; see section 8).

The explanation is written in the language you chose. When the target is Simplified Chinese, classical Chinese is explained in modern written Chinese. The right page shows one language at a time. **Show explanation** and the explanation menu switch among explanations already produced, without calling the model again. Opening or saving an `.aibook` file keeps every language. Opening an explanation `.txt` writes only the language you are looking at. New and Clear remove only that language.

### 6.2 Follow-up questions

- The **input field** at the bottom of the right page continues the conversation, using the current file and earlier turns.
- A book’s conversation is **restored when possible** after a restart, keyed by the file path.

### 6.3 Explanation documents

| Action | Meaning |
|--------|---------|
| New | Clear the explanation in the language you are viewing; other languages stay in the package |
| Open | Load an explanation `.txt` into the language you are viewing |
| Save | Save the current explanation as UTF-8 text |
| Select all | Select all text in the explanation area |
| Clear explanation | Delete the explanation in the current language |
| Read explanation | Read the whole explanation, or stop |

### 6.4 One message

**Right-click** a bubble to copy it, delete it, or read **that AI reply** aloud (the menu follows the current version).

### 6.5 Selection

Clicking a title-bar button can clear the left-page highlight for a moment. The app **keeps the last non-empty selection**, so **Explain Selection** still uses the text you just selected.

---

## 7. Translation

### 7.1 Two modes

| Mode | Entry | Result |
|------|-------|--------|
| **Word-by-Word** | **Translation** → **Word-by-Word** | Breaks the source into characters or words, with a short note. Useful for close reading |
| **Full Paragraph** | **Translation** → **Full Paragraph** | Keeps paragraph structure in a continuous translation. Useful for reading a chapter |

**Source text**: the **current selection** on the left page, or the **whole left page** if nothing is selected.

**Translation Target Language**: select more than one under **Book Settings → AI Models → Translation Target Language**, or check them in the **Translation** menu. The explanation side is **Explanation language**. Generation follows that order. The right page shows one language at a time; **Show translation** and **Show explanation** switch among results already produced. An `.aibook` file keeps every language. Classical Chinese aimed at Simplified Chinese becomes modern written Chinese.

The result is structured **JSON** (with alignment blocks) in the translation area. You can **edit** the text or the table directly.

### 7.2 Translation files

| Action | Meaning |
|--------|---------|
| Open translation | Load an existing translation JSON or text file |
| Save translation | A common name is `original-name-翻译.txt` |
| Clear translation | Delete the current translation and its alignment |
| Select all translation | ⌘⌃⇧A |
| **Read translation** | The toolbar and the **Translation** menu. **Read All Translation** is ⌘⌥T |

### 7.3 Table and alignment

When the JSON contains valid **alignment blocks** (character, word, or paragraph):

| Control | Meaning |
|---------|---------|
| **Translation table** | The right page shows a **source–translation table**, one row at a time |
| **Align translation** | After the left page changes, recompute how the translation lines up |
| **Lock translation** | Stops an accidental full realignment. Editing a single row usually still works |
| **Unlock translation** | Allows a full realignment again |

The explanation toolbar uses the matching names **Explanation table**, **Align explanation**, **Lock explanation**, and **Unlock explanation**.

If the left page changes a lot, the toolbar says: **Alignment stale; tap Align translation or Align explanation**.

### 7.4 Scrolling with the left page

In the study-mode **spread**, with the **translation table** on and alignment still valid, scrolling the left page can **highlight the matching row**, so you can read the two sides together. The current version decides the exact highlight.

---

## 8. Reading aloud

### 8.1 Where to start

| What | Usual entry |
|------|-------------|
| Left-page selection | **Speech** → **Read source selection**. ⌘⌥R is **Read source (selection/all)** |
| Full left page | **Speech** → **Read all source** |
| Translation | Toolbar and **Translation** menu: **Read translation**. ⌘⌥T is **Read All Translation** |
| Explanation | **Explanation** → **Read explanation**. Right-click a bubble: **Read this message** |
| Preview | **Book Settings** → **Voice** |

### 8.2 Title-bar controls

While speech is playing, the middle of the title bar shows **Pause**, **Resume**, and **Stop**.

### 8.3 Pace (Book Settings → Voice)

The segmented control is titled **Pace**. The options and the line under the control are:

| Option | Text under the control |
|--------|------------------------|
| **Fast** | Fast: quicker pace for skimming. |
| **Balanced** | Balanced: default pace and pauses. |
| **Natural** | Natural: clearer articulation for explain. |
| **Relaxed** | Relaxed: slower, longer pauses. |

### 8.4 Language Processing

The segmented control is titled **Language Processing**.

| Option | Text under the control |
|--------|------------------------|
| **Efficient** | Language · Efficient: longer chunks, faster. |
| **Balanced** | Language · Balanced: default. |
| **Deep** | Language · Deep: shorter clauses, clearer speech. |

### 8.5 Voice

The voice menu is titled **Voice**.

- **System Chinese voice**: a Chinese voice built into macOS.
- **Online neural female voices** (Edge TTS): Xiaoyi, Xiaoxiao, and regional voices.
- Download the **sample** in settings before relying on an online voice. Samples are cached locally.

Before playback, Markdown and similar markup are **cleaned and split into sentences**.

### 8.6 Voice commands

Hold the title-bar microphone, speak, and release to run. In reading mode, where that button is hidden, **hold Option+Space** while the app is in front. The app turns speech into text, then uses the same book model as translation and explanation to map the sentence onto an existing action: explain, translate, read aloud, change layout, open, save, export, and similar actions run immediately. Starting evolution or analyzing optimizations asks for confirmation first. If the phrase was unclear or matches no action, nothing runs; the app only shows the text it heard.

---

## 9. Classic supplement

| Item | Meaning |
|------|---------|
| Entry | **Classic supplement** in the **Document** menu, ⌘⇧C |
| Input | A selection on the left page, or the whole page |
| Behavior | The model identifies the work and **completes it as a continuous passage**, keeping the original style where it can |
| Output | Written back to the **left page** (replacing the selection or the whole text) and **saved automatically** when possible |

This is for restoring context around a textbook excerpt or a fragment. Do not use it to copy a work you do not have the right to use.

---

## 10. AI evolution (advanced)

> **Warning**: evolution edits the AIBook source and reinstalls the app. Use it only if you understand Git and backups. Do not turn on the auto-upgrade chain on a machine you cannot afford to change.

### 10.1 What it does

- **Analyze**: the model **reads** the project and writes suggestions into the **optimization queue**. It does not edit code.
- **Evolve**: takes one **pending** item, **edits the code**, builds and installs, then **restarts the app**.

### 10.2 A typical run

1. Open the **AI evolution** tab on the right.
2. Click **Analyze** and wait for suggestions to enter the queue.
3. Read the queue (title, number, status).
4. Click **Evolve** (⌘E) to run the **next pending** item.
5. Watch the **reasoning** and the **tool steps**.
6. The app may restart when the item finishes. If the **auto-upgrade chain** is on and you already started evolution in this session, later pending items may **run in sequence**.

### 10.3 Commands and the queue file

- Queue file: `~/Library/Application Support/AIBook/optimization-queue.json`
- Inside the evolution tab you can **save and open** an evolution-command document (UTF-8).
- Analysis **drops duplicates** by a normalized title. One analysis suggests a limited number of items (about 8).

### 10.4 Channel

**Analyze** and **Evolve** both use the local Cursor agent. There is no switch that falls back to the book model. Analysis only reads the project. **Evolve** edits code, builds, and installs. If Cursor is not ready, the buttons stay disabled and the pill says **Cursor not ready**.

### 10.5 Tokens and status

- Evolution and long conversations stay inside a **token budget**. The interface shows usage and refuses to send when the budget is spent.
- The title-bar capsule can show the **pending count** and the number of the next item.

---

## 11. Appearance (Book Settings → appearance)

| Item | What it affects |
|------|-----------------|
| **Theme Presets** | Leather, paper, buttons, and ornaments |
| **Size** | The first item is **Follow Theme**. The rest are point sizes. Affects the left page, reading-mode pagination, and the page-turn snapshot |
| **Font** | **Follow theme**, **Songti**, **Kaiti**, **Heiti**, **PingFang**, **System default** |

The ornament switches are **Bookmark ribbon**, **Corner fold**, **Paper texture**, and **Header ornament**.

**Reading mode repaginates** after a change. The study-mode left page updates immediately. The page texture in the turn animation follows the current preset.

---

## 12. Menus

Besides the title-bar buttons, the **File / Edit** menus collect the same shortcuts as the source and explanation actions.  
**Help** opens this manual and reveals it in Finder.

**AIBook → Settings** is for evolution.  
**Book Settings** in the title bar is for reading, translation, speech, and appearance.

---

## 13. Shortcuts

| Name on the menu | Shortcut |
|--------|----------|
| **New source** | ⌘N |
| **Open source…** | ⌘O |
| **Save source** | ⌘S |
| **Save source as…** | ⌘⇧S |
| **Export source selection…** | ⌘⌥S |
| **Explain Selection** | ⌘R |
| **Explain All** | ⌘⇧R |
| **Read source (selection/all)** | ⌘⌥R |
| **Read All Translation** | ⌘⌥T |
| **Classic supplement** | ⌘⇧C |
| **Self Evolution** (menu) / **Evolve** (title bar) | ⌘E |
| **Reading mode** | ⌘⇧P |
| Voice command | Hold Option+Space |
| Reading: **Previous Page** / **Next Page** | ← / → |
| Reading: **Spread** / **Full Screen** | ⌘⌥1 / ⌘⌥2 |
| Study: **Spread** / **Source full screen** / **Right Full Screen** | ⌘⌥1 / ⌘⌥2 / ⌘⌥3 |
| **Exit Reading Mode**, or restore **Spread** | Esc |
| **Select all source** | ⌘⌃A |
| **Select All Translation** | ⌘⌃⇧A |

> Some layout shortcuts follow the in-app **View** menu. Hover a title-bar button to see its full hint.

---

## 14. Data and privacy

### 14.1 Local storage (Application Support)

Root: `~/Library/Application Support/AIBook/`

| What | Path |
|------|------|
| Command notes | `readme-notes.txt` |
| Optimization queue | `optimization-queue.json` |
| Conversations | Cached by book path |
| Folder browser | Open roots and expanded state |
| Online voice samples | `voices/` |
| Auto-upgrade chain | `auto-evolution-active` and related files |

### 14.2 Network and keys

- **Model / Cursor** requests go to the API or Cursor service you configured. Keys stay in local preferences. Do not share the machine.
- **Edge TTS** needs a network. System voices work offline.
- **Voice commands** use the microphone and system speech recognition. When the system language supports on-device recognition, the audio stays on this Mac. The recognized text is sent to the same book model used for translation and explanation.

---

## 15. Install and update

### 15.1 Install into Applications

```bash
cd ai-book
./scripts/build-and-install.sh
```

### 15.2 Run from source

```bash
swift run
```

### 15.3 Sample text

`Sources/AIBook/Resources/sample.txt` is a short file for a first open and explanation.

---

## 16. Suggested workflows

### 16.1 Daily reading and questions

1. ⌘O opens a chapter `.txt`.
2. Select a difficult passage → ⌘R to explain it.
3. Ask a follow-up in the field at the bottom.
4. ⌘⇧P enters reading mode when you want only the page.

### 16.2 A foreign language or a classic

1. Load the source on the left page.
2. Run a **paragraph** translation or a **word-by-word** translation.
3. Turn on the **translation table** and **lock** a stable version.
4. ⌘⌥T reads the translation; ⌘⌥R reads the source.

### 16.3 A folder of many files

1. **File → Open Folder…** and add the library root.
2. Choose `chapter-01.txt` → open as **source**.
3. Choose `chapter-01-翻译.txt` → open as **translation**.
4. Switch the explanation and translation panes in the same window.

### 16.4 Completing an excerpt

1. Paste a textbook excerpt on the left page.
2. ⌘⇧C runs classic supplement.
3. Check the result, then ⌘S to save.

---

## 17. Questions

**The explanation button says the model is not configured.**  
Open **Book Settings → model**, pick a provider, and enter an API key. Ollama is the usual choice on this Mac.

**Cursor local is unavailable.**  
Check Node.js, `npm install` inside cursor-bridge, the Cursor API key, and the path in Evolution Settings.

**The translation table is disabled.**  
Finish a word-by-word or paragraph translation first, and the JSON must contain valid alignment blocks. If alignment is stale, use **Align translation**.

**Page numbers changed in reading mode.**  
Changing the type size or the window repaginates. That is expected. The spread index is restored when it can be.

**The app behaves differently after evolution.**  
Evolution changes the local installed copy of AIBook. Keep the source in Git, and use the auto-upgrade chain only when you mean to.

**This manual and the interface disagree.**  
Trust the **AIBook build you installed**. Hover a button for the current hint.

---

## 18. Version and documents

- This manual is shipped inside the app and opens from the **Help** menu.
- The repository also has design notes (reading mode, visual style, evolution) for development.
- The project README has the short Ollama and Cursor setup.

---

**Thank you for using AIBook.**
