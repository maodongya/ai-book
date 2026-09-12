#!/usr/bin/env python3
"""Generate Sources/AIBook/Resources/Localizable.xcstrings from STRING_TABLE."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "l10n"))
from string_table_extended import EXTENDED  # noqa: E402
from viewmodel_l10n import VIEWMODEL_STRINGS  # noqa: E402
from app_ui_strings import APP_UI_STRINGS  # noqa: E402

LANGS = ["zh-Hans", "en", "ja", "de", "fr", "it", "la", "el"]

# zh-Hans is source; each key maps locale -> value
STRING_TABLE: dict[str, dict[str, str]] = {
    "app.tagline": {
        "zh-Hans": "辅助读书",
        "en": "Reading companion",
        "ja": "読書アシスタント",
        "de": "Lesebegleiter",
        "fr": "Compagnon de lecture",
        "it": "Compagno di lettura",
        "la": "Adiutor legendi",
        "el": "Βοηθός ανάγνωσης",
    },
    "language.system": {
        "zh-Hans": "跟随系统",
        "en": "Follow System",
        "ja": "システムに従う",
        "de": "System folgen",
        "fr": "Suivre le système",
        "it": "Segui sistema",
        "la": "Sequere systema",
        "el": "Ακολούθηση συστήματος",
    },
    "language.zhHans": {"zh-Hans": "简体中文", "en": "Chinese (Simplified)", "ja": "簡体字中国語", "de": "Chinesisch (vereinfacht)", "fr": "Chinois (simplifié)", "it": "Cinese (semplificato)", "la": "Sinica (simplicata)", "el": "Κινεζικά (απλοποιημένα)"},
    "language.en": {"zh-Hans": "英语", "en": "English", "ja": "英語", "de": "Englisch", "fr": "Anglais", "it": "Inglese", "la": "Anglica", "el": "Αγγλικά"},
    "language.ja": {"zh-Hans": "日语", "en": "Japanese", "ja": "日本語", "de": "Japanisch", "fr": "Japonais", "it": "Giapponese", "la": "Iaponica", "el": "Ιαπωνικά"},
    "language.de": {"zh-Hans": "德语", "en": "German", "ja": "ドイツ語", "de": "Deutsch", "fr": "Allemand", "it": "Tedesco", "la": "Germanica", "el": "Γερμανικά"},
    "language.fr": {"zh-Hans": "法语", "en": "French", "ja": "フランス語", "de": "Französisch", "fr": "Français", "it": "Francese", "la": "Gallica", "el": "Γαλλικά"},
    "language.it": {"zh-Hans": "意大利语", "en": "Italian", "ja": "イタリア語", "de": "Italienisch", "fr": "Italien", "it": "Italiano", "la": "Italica", "el": "Ιταλικά"},
    "language.la": {"zh-Hans": "拉丁语", "en": "Latin", "ja": "ラテン語", "de": "Latein", "fr": "Latin", "it": "Latino", "la": "Latina", "el": "Λατινικά"},
    "language.el": {"zh-Hans": "希腊语", "en": "Greek", "ja": "ギリシャ語", "de": "Griechisch", "fr": "Grec", "it": "Greco", "la": "Graeca", "el": "Ελληνικά"},
    "settings.language": {"zh-Hans": "界面语言", "en": "Interface Language", "ja": "表示言語", "de": "Oberflächensprache", "fr": "Langue de l’interface", "it": "Lingua interfaccia", "la": "Lingua interfaciei", "el": "Γλώσσα διεπαφής"},
    "settings.language.hint": {"zh-Hans": "更改后立即生效", "en": "Applies immediately", "ja": "すぐに反映されます", "de": "Gilt sofort", "fr": "Effet immédiat", "it": "Effetto immediato", "la": "Statim valet", "el": "Ισχύει αμέσως"},
    "translation.target.title": {
        "zh-Hans": "翻译目标语言",
        "en": "Translation Target Language",
        "ja": "翻訳先の言語",
        "de": "Zielsprache der Übersetzung",
        "fr": "Langue cible de traduction",
        "it": "Lingua di destinazione",
        "la": "Lingua translationis",
        "el": "Γλώσσα-στόχος μετάφρασης",
    },
    "translation.target.followApp": {
        "zh-Hans": "跟随界面语言",
        "en": "Follow Interface Language",
        "ja": "表示言語に従う",
        "de": "Oberflächensprache folgen",
        "fr": "Suivre la langue de l’interface",
        "it": "Segui la lingua dell’interfaccia",
        "la": "Sequere linguam interfaciei",
        "el": "Ακολούθηση γλώσσας διεπαφής",
    },
    "translation.target.hint": {
        "zh-Hans": "仅影响之后发起的翻译，不会更改当前译文",
        "en": "Applies to future translations without changing the current translation",
        "ja": "今後の翻訳にのみ適用され、現在の訳文は変更されません",
        "de": "Gilt nur für neue Übersetzungen; die aktuelle bleibt unverändert",
        "fr": "S’applique aux prochaines traductions sans modifier la traduction actuelle",
        "it": "Vale per le traduzioni future senza modificare quella corrente",
        "la": "Translationibus futuris tantum valet; praesentem non mutat",
        "el": "Ισχύει μόνο για νέες μεταφράσεις χωρίς αλλαγή της τρέχουσας",
    },
    "tab.readingAssistant": {"zh-Hans": "读书助手", "en": "Reading Assistant", "ja": "読書アシスタント", "de": "Lese-Assistent", "fr": "Assistant de lecture", "it": "Assistente lettura", "la": "Adiutor legendi", "el": "Βοηθός ανάγνωσης"},
    "tab.aiEvolution": {"zh-Hans": "AI进化", "en": "AI Evolution", "ja": "AI進化", "de": "KI-Evolution", "fr": "Évolution IA", "it": "Evoluzione IA", "la": "Evolutio IA", "el": "Εξέλιξη AI"},
    "panel.explanation": {"zh-Hans": "讲解", "en": "Explain", "ja": "解説", "de": "Erklärung", "fr": "Explication", "it": "Spiegazione", "la": "Explicatio", "el": "Εξήγηση"},
    "panel.translation": {"zh-Hans": "翻译", "en": "Translate", "ja": "翻訳", "de": "Übersetzung", "fr": "Traduction", "it": "Traduzione", "la": "Translatio", "el": "Μετάφραση"},
    "page.source": {"zh-Hans": "原文", "en": "Source", "ja": "原文", "de": "Original", "fr": "Original", "it": "Originale", "la": "Originalis", "el": "Πρωτότυπο"},
    "mode.reading": {"zh-Hans": "阅读模式", "en": "Reading Mode", "ja": "読書モード", "de": "Lesemodus", "fr": "Mode lecture", "it": "Modalità lettura", "la": "Modus legendi", "el": "Λειτουργία ανάγνωσης"},
    "mode.learning": {"zh-Hans": "学习模式", "en": "Study Mode", "ja": "学習モード", "de": "Lernmodus", "fr": "Mode étude", "it": "Modalità studio", "la": "Modus discendi", "el": "Λειτουργία μελέτης"},
    "layout.spread": {"zh-Hans": "双页", "en": "Spread", "ja": "見開き", "de": "Doppelseite", "fr": "Double page", "it": "Doppia pagina", "la": "Paginae geminae", "el": "Διπλή σελίδα"},
    "layout.fullscreen": {"zh-Hans": "全屏", "en": "Full Screen", "ja": "全画面", "de": "Vollbild", "fr": "Plein écran", "it": "Schermo intero", "la": "Plenum schermum", "el": "Πλήρης οθόνη"},
    "action.new": {"zh-Hans": "新建", "en": "New", "ja": "新規", "de": "Neu", "fr": "Nouveau", "it": "Nuovo", "la": "Novum", "el": "Νέο"},
    "action.open": {"zh-Hans": "打开", "en": "Open", "ja": "開く", "de": "Öffnen", "fr": "Ouvrir", "it": "Apri", "la": "Aperi", "el": "Άνοιγμα"},
    "action.openFile": {"zh-Hans": "打开文本文件…", "en": "Open Text File…", "ja": "テキストを開く…", "de": "Textdatei öffnen…", "fr": "Ouvrir un fichier texte…", "it": "Apri file di testo…", "la": "Aperi fasciculum textus…", "el": "Άνοιγμα αρχείου κειμένου…"},
    "action.openDirectory": {"zh-Hans": "打开目录…", "en": "Open Folder…", "ja": "フォルダを開く…", "de": "Ordner öffnen…", "fr": "Ouvrir un dossier…", "it": "Apri cartella…", "la": "Aperi folder…", "el": "Άνοιγμα φακέλου…"},
    "action.save": {"zh-Hans": "保存", "en": "Save", "ja": "保存", "de": "Sichern", "fr": "Enregistrer", "it": "Salva", "la": "Serva", "el": "Αποθήκευση"},
    "action.saveAs": {"zh-Hans": "另存为…", "en": "Save As…", "ja": "別名で保存…", "de": "Sichern unter…", "fr": "Enregistrer sous…", "it": "Salva con nome…", "la": "Serva ut…", "el": "Αποθήκευση ως…"},
    "action.exportSelection": {"zh-Hans": "导出选中为…", "en": "Export Selection…", "ja": "選択範囲を書き出し…", "de": "Auswahl exportieren…", "fr": "Exporter la sélection…", "it": "Esporta selezione…", "la": "Exporta selectum…", "el": "Εξαγωγή επιλογής…"},
    "action.done": {"zh-Hans": "完成", "en": "Done", "ja": "完了", "de": "Fertig", "fr": "Terminé", "it": "Fine", "la": "Factum", "el": "Τέλος"},
    "action.stop": {"zh-Hans": "停止", "en": "Stop", "ja": "停止", "de": "Stopp", "fr": "Arrêter", "it": "Stop", "la": "Desine", "el": "Διακοπή"},
    "action.pause": {"zh-Hans": "暂停", "en": "Pause", "ja": "一時停止", "de": "Pause", "fr": "Pause", "it": "Pausa", "la": "Subsiste", "el": "Παύση"},
    "action.resume": {"zh-Hans": "继续", "en": "Resume", "ja": "再開", "de": "Fortsetzen", "fr": "Reprendre", "it": "Riprendi", "la": "Perge", "el": "Συνέχεια"},
    "action.selectAll": {"zh-Hans": "全选", "en": "Select All", "ja": "すべて選択", "de": "Alles auswählen", "fr": "Tout sélectionner", "it": "Seleziona tutto", "la": "Elige omnia", "el": "Επιλογή όλων"},
    "action.clear": {"zh-Hans": "清空", "en": "Clear", "ja": "クリア", "de": "Leeren", "fr": "Effacer", "it": "Svuota", "la": "Vacua", "el": "Εκκαθάριση"},
    "action.readAloud": {"zh-Hans": "朗读", "en": "Read Aloud", "ja": "読み上げ", "de": "Vorlesen", "fr": "Lire à voix haute", "it": "Leggi ad alta voce", "la": "Lege voce", "el": "Ανάγνωση"},
    "action.explainSelection": {"zh-Hans": "选择讲解", "en": "Explain Selection", "ja": "選択部分を解説", "de": "Auswahl erklären", "fr": "Expliquer la sélection", "it": "Spiega selezione", "la": "Explica selectum", "el": "Εξήγηση επιλογής"},
    "action.explainFull": {"zh-Hans": "全文讲解", "en": "Explain All", "ja": "全文を解説", "de": "Gesamten Text erklären", "fr": "Expliquer tout", "it": "Spiega tutto", "la": "Explica totum", "el": "Εξήγηση όλου"},
    "action.evolution": {"zh-Hans": "自我进化", "en": "Self Evolution", "ja": "自己進化", "de": "Selbst-Evolution", "fr": "Auto-évolution", "it": "Auto-evoluzione", "la": "Evolutio sui", "el": "Αυτο-εξέλιξη"},
    "action.classicSupplement": {"zh-Hans": "名著补充", "en": "Classic Supplement", "ja": "名著補完", "de": "Klassiker ergänzen", "fr": "Compléter le classique", "it": "Integra classico", "la": "Supple classicum", "el": "Συμπλήρωση κλασικού"},
    "action.manual": {"zh-Hans": "说明书", "en": "Manual", "ja": "説明書", "de": "Handbuch", "fr": "Manuel", "it": "Manuale", "la": "Manualis", "el": "Εγχειρίδιο"},
    "action.manual.openSystem": {"zh-Hans": "用系统应用打开", "en": "Open in Default App", "ja": "デフォルトアプリで開く", "de": "In Standard-App öffnen", "fr": "Ouvrir avec l’app par défaut", "it": "Apri con app predefinita", "la": "Aperi in app systematis", "el": "Άνοιγμα στην προεπιλεγμένη εφαρμογή"},
    "help.manual": {"zh-Hans": "AIBook 功能说明书", "en": "AIBook User Manual", "ja": "AIBook 機能説明書", "de": "AIBook Benutzerhandbuch", "fr": "Manuel AIBook", "it": "Manuale AIBook", "la": "Manualis AIBook", "el": "Εγχειρίδιο AIBook"},
    "help.manual.reveal": {"zh-Hans": "在访达中显示说明书", "en": "Reveal Manual in Finder", "ja": "Finderで説明書を表示", "de": "Handbuch im Finder zeigen", "fr": "Afficher le manuel dans le Finder", "it": "Mostra manuale nel Finder", "la": "Ostende manualem in Finder", "el": "Εμφάνιση εγχειριδίου στο Finder"},
    "manual.title": {"zh-Hans": "功能说明书", "en": "User Manual", "ja": "機能説明書", "de": "Benutzerhandbuch", "fr": "Manuel", "it": "Manuale", "la": "Manualis functionum", "el": "Εγχειρίδιο"},
    "settings.book": {"zh-Hans": "book 设置", "en": "Book Settings", "ja": "book 設定", "de": "Book-Einstellungen", "fr": "Réglages book", "it": "Impostazioni book", "la": "Configuratio book", "el": "Ρυθμίσεις book"},
    "settings.evolution": {"zh-Hans": "进化设置", "en": "Evolution Settings", "ja": "進化設定", "de": "Evolutions-Einstellungen", "fr": "Réglages évolution", "it": "Impostazioni evoluzione", "la": "Configuratio evolutionis", "el": "Ρυθμίσεις εξέλιξης"},
    "settings.tab.ai": {"zh-Hans": "AI模型设置", "en": "AI Models", "ja": "AIモデル", "de": "KI-Modelle", "fr": "Modèles IA", "it": "Modelli IA", "la": "Modelli IA", "el": "Μοντέλα AI"},
    "settings.tab.voice": {"zh-Hans": "语音设置", "en": "Voice", "ja": "音声", "de": "Stimme", "fr": "Voix", "it": "Voce", "la": "Vox", "el": "Φωνή"},
    "settings.tab.appearance": {"zh-Hans": "外观风格", "en": "Appearance", "ja": "外観", "de": "Erscheinungsbild", "fr": "Apparence", "it": "Aspetto", "la": "Species", "el": "Εμφάνιση"},
    "settings.contextPercent": {"zh-Hans": "左页节选占比", "en": "Source excerpt ratio", "ja": "左ページ抜粋比率", "de": "Auszugsanteil links", "fr": "Part d’extrait (page gauche)", "it": "Quota estratto sinistra", "la": "Portio excerpta sinistra", "el": "Αναλογία αποσπάσματος"},
    "settings.autoUpgrade": {"zh-Hans": "自动升级", "en": "Auto Upgrade", "ja": "自動アップグレード", "de": "Auto-Upgrade", "fr": "Mise à niveau auto", "it": "Aggiornamento auto", "la": "Auto renovatio", "el": "Αυτόματη αναβάθμιση"},
    "settings.themePresets": {"zh-Hans": "预设主题", "en": "Theme Presets", "ja": "テーマ", "de": "Design-Vorlagen", "fr": "Thèmes", "it": "Temi predefiniti", "la": "Themata praefixa", "el": "Προεπιλεγμένα θέματα"},
    "status.unsaved": {"zh-Hans": "未保存", "en": "Unsaved", "ja": "未保存", "de": "Ungesichert", "fr": "Non enregistré", "it": "Non salvato", "la": "Non servatum", "el": "Μη αποθηκευμένο"},
    "status.bookLLM.unconfigured": {"zh-Hans": "book 未配置", "en": "Book LLM not set", "ja": "book 未設定", "de": "Book-LLM fehlt", "fr": "LLM book non configuré", "it": "LLM book non configurato", "la": "Book LLM non configuratum", "el": "Book LLM μη ρυθμισμένο"},
    "status.cursor.notReady": {"zh-Hans": "Cursor 未就绪", "en": "Cursor not ready", "ja": "Cursor 未準備", "de": "Cursor nicht bereit", "fr": "Cursor non prêt", "it": "Cursor non pronto", "la": "Cursor non paratus", "el": "Cursor μη έτοιμο"},
    "status.speaking": {"zh-Hans": "朗读中", "en": "Speaking", "ja": "読み上げ中", "de": "Spricht", "fr": "Lecture en cours", "it": "In lettura", "la": "Legens", "el": "Ανάγνωση"},
    "banner.bookLLM": {"zh-Hans": "未配置 book 大模型", "en": "Book LLM not configured", "ja": "book 大モデル未設定", "de": "Book-LLM nicht konfiguriert", "fr": "LLM book non configuré", "it": "LLM book non configurato", "la": "Magnum model book non configuratum", "el": "Μεγάλο μοντέλο book μη ρυθμισμένο"},
    "translation.tableCompare": {"zh-Hans": "表格对照", "en": "Table view", "ja": "対照表", "de": "Tabellenansicht", "fr": "Vue tableau", "it": "Vista tabella", "la": "Tabula comparativa", "el": "Πίνακας σύγκρισης"},
    "translation.alignSource": {"zh-Hans": "对齐原文", "en": "Align to source", "ja": "原文に合わせる", "de": "Mit Original ausrichten", "fr": "Aligner sur l’original", "it": "Allinea all’originale", "la": "Aligna ad originale", "el": "Ευθυγράμμιση με πρωτότυπο"},
    "translation.lock": {"zh-Hans": "锁定对照", "en": "Lock alignment", "ja": "対照を固定", "de": "Ausrichtung sperren", "fr": "Verrouiller l’alignement", "it": "Blocca allineamento", "la": "Claude alignmentem", "el": "Κλείδωμα ευθυγράμμισης"},
    "translation.unlock": {"zh-Hans": "解锁对照", "en": "Unlock alignment", "ja": "固定解除", "de": "Ausrichtung entsperren", "fr": "Déverrouiller", "it": "Sblocca", "la": "Reserare", "el": "Ξεκλείδωμα"},
    "translation.generating": {"zh-Hans": "正在生成翻译…", "en": "Generating translation…", "ja": "翻訳を生成中…", "de": "Übersetzung wird erstellt…", "fr": "Traduction en cours…", "it": "Generazione traduzione…", "la": "Translatio generatur…", "el": "Δημιουργία μετάφρασης…"},
    "llm.generating": {"zh-Hans": "大模型生成中…", "en": "Generating…", "ja": "生成中…", "de": "Generierung…", "fr": "Génération…", "it": "Generazione…", "la": "Generatio…", "el": "Δημιουργία…"},
    "menu.readOriginalSelectionOrFull": {"zh-Hans": "朗读原文（选中/全文）", "en": "Read Source (Selection/All)", "ja": "原文を読み上げ（選択/全文）", "de": "Original vorlesen (Auswahl/Alles)", "fr": "Lire l’original (sélection/tout)", "it": "Leggi originale (selezione/tutto)", "la": "Lege originale (selectum/totum)", "el": "Ανάγνωση πρωτοτύπου (επιλογή/όλο)"},
    "menu.readOriginalFull": {"zh-Hans": "朗读原文全文", "en": "Read All Source", "ja": "原文全文を読み上げ", "de": "Ganzes Original vorlesen", "fr": "Lire tout l’original", "it": "Leggi tutto l’originale", "la": "Lege totum originale", "el": "Ανάγνωση όλου του πρωτοτύπου"},
    "menu.readOriginalSelection": {"zh-Hans": "朗读原文选中", "en": "Read Source Selection", "ja": "選択した原文を読み上げ", "de": "Auswahl im Original vorlesen", "fr": "Lire la sélection originale", "it": "Leggi selezione originale", "la": "Lege selectum originale", "el": "Ανάγνωση επιλογής πρωτοτύπου"},
    "menu.readTranslationFull": {"zh-Hans": "朗读翻译全文", "en": "Read All Translation", "ja": "翻訳全文を読み上げ", "de": "Gesamte Übersetzung vorlesen", "fr": "Lire toute la traduction", "it": "Leggi tutta la traduzione", "la": "Lege totam translationem", "el": "Ανάγνωση όλης της μετάφρασης"},
    "menu.readTranslationSelection": {"zh-Hans": "朗读翻译选择", "en": "Read Translation Selection", "ja": "選択した翻訳を読み上げ", "de": "Übersetzungsauswahl vorlesen", "fr": "Lire la sélection traduite", "it": "Leggi selezione traduzione", "la": "Lege selectam translationem", "el": "Ανάγνωση επιλογής μετάφρασης"},
    "menu.readExplanationFull": {"zh-Hans": "朗读讲解全文", "en": "Read All Explanation", "ja": "解説全文を読み上げ", "de": "Gesamte Erklärung vorlesen", "fr": "Lire toute l’explication", "it": "Leggi tutta la spiegazione", "la": "Lege totam explicationem", "el": "Ανάγνωση όλης της εξήγησης"},
    "menu.readExplanationSelection": {"zh-Hans": "朗读讲解选中", "en": "Read Explanation Selection", "ja": "選択した解説を読み上げ", "de": "Erklärungsauswahl vorlesen", "fr": "Lire la sélection d’explication", "it": "Leggi selezione spiegazione", "la": "Lege selectam explicationem", "el": "Ανάγνωση επιλογής εξήγησης"},
    "menu.selectAllLeft": {"zh-Hans": "全选左页", "en": "Select All (Left Page)", "ja": "左ページをすべて選択", "de": "Alles links auswählen", "fr": "Tout sélectionner (page gauche)", "it": "Seleziona tutto (pagina sinistra)", "la": "Elige omnia pagina sinistra", "el": "Επιλογή όλων (αριστερή σελίδα)"},
    "menu.selectAllTranslation": {"zh-Hans": "全选翻译", "en": "Select All Translation", "ja": "翻訳をすべて選択", "de": "Gesamte Übersetzung auswählen", "fr": "Tout sélectionner (traduction)", "it": "Seleziona tutta la traduzione", "la": "Elige omnem translationem", "el": "Επιλογή όλης της μετάφρασης"},
    "menu.stopSpeaking": {"zh-Hans": "停止朗读", "en": "Stop Speaking", "ja": "読み上げ停止", "de": "Vorlesen stoppen", "fr": "Arrêter la lecture", "it": "Stop lettura", "la": "Desine legere", "el": "Διακοπή ανάγνωσης"},
    "footer.characters": {"zh-Hans": "%lld 字", "en": "%lld chars", "ja": "%lld 文字", "de": "%lld Zeichen", "fr": "%lld caractères", "it": "%lld caratteri", "la": "%lld notae", "el": "%lld χαρακτήρες"},
    "footer.selected": {"zh-Hans": "已选 %lld 字", "en": "%lld selected", "ja": "%lld 文字選択", "de": "%lld ausgewählt", "fr": "%lld sélectionnés", "it": "%lld selezionati", "la": "%lld selecta", "el": "%lld επιλεγμένα"},
    "focus.reading": {"zh-Hans": "专注阅读", "en": "Focus reading", "ja": "集中読書", "de": "Fokus Lesen", "fr": "Lecture focus", "it": "Lettura focus", "la": "Lectio intenta", "el": "Εστιασμένη ανάγνωση"},
    "toolbar.showInput": {"zh-Hans": "显示输入", "en": "Show input", "ja": "入力を表示", "de": "Eingabe anzeigen", "fr": "Afficher la saisie", "it": "Mostra input", "la": "Ostende intrantum", "el": "Εμφάνιση εισόδου"},
    "toolbar.showChrome": {"zh-Hans": "显示工具栏", "en": "Show toolbar", "ja": "ツールバーを表示", "de": "Symbolleiste anzeigen", "fr": "Afficher la barre", "it": "Mostra barra", "la": "Ostende toolbar", "el": "Εμφάνιση γραμμής εργαλείων"},
    "toolbar.hideInput": {"zh-Hans": "隐藏输入", "en": "Hide input", "ja": "入力を隠す", "de": "Eingabe ausblenden", "fr": "Masquer la saisie", "it": "Nascondi input", "la": "Celare intrantum", "el": "Απόκρυψη εισόδου"},
    "evolution.operations": {"zh-Hans": "进化操作", "en": "Evolution Actions", "ja": "進化操作", "de": "Evolutions-Aktionen", "fr": "Actions évolution", "it": "Azioni evoluzione", "la": "Actiones evolutionis", "el": "Ενέργειες εξέλιξης"},
    "mode.exitReading": {"zh-Hans": "退出阅读模式", "en": "Exit Reading Mode", "ja": "読書モードを終了", "de": "Lesemodus beenden", "fr": "Quitter le mode lecture", "it": "Esci da lettura", "la": "Exi modum legendi", "el": "Έξοδος λειτουργίας ανάγνωσης"},
    "status.saved": {"zh-Hans": "已保存", "en": "Saved", "ja": "保存済み", "de": "Gesichert", "fr": "Enregistré", "it": "Salvato", "la": "Servatum", "el": "Αποθηκεύτηκε"},
}


def main() -> None:
    merged = {**STRING_TABLE, **EXTENDED, **VIEWMODEL_STRINGS, **APP_UI_STRINGS}
    strings: dict = {}
    for key, locs in merged.items():
        entry: dict = {"localizations": {}}
        for lang in LANGS:
            value = locs.get(lang) or locs["zh-Hans"]
            entry["localizations"][lang] = {
                "stringUnit": {"state": "translated", "value": value}
            }
        strings[key] = entry

    catalog = {
        "sourceLanguage": "zh-Hans",
        "strings": strings,
        "version": "1.0",
    }
    out = Path(__file__).resolve().parents[1] / "Sources/AIBook/Resources/Localizable.xcstrings"
    out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(strings)} keys to {out}")


if __name__ == "__main__":
    main()
