1、已完成：产品定位「ai-book」——AIBookProduct 模块统一品牌名/项目标识，顶栏 ai-book 胶囊与设置「关于」展示定位，ReadingAssistant 引用统一品牌常量。
2、已完成：Swift + SwiftUI 原生 macOS 实现；SwiftPlatform 模块统一技术栈标识，顶栏与设置「关于」展示。
3、已完成：OpenAI/DeepSeek/Moonshot/通义/智谱/Ollama 等多模型连接；LLMConnector 统一提供商目录，右页连接面板与顶栏「多模型」标识，支持测试连接。
4、可以打开本地.txt文件。
5、整个窗口分为两部分，左边为原文，右边为文章的讲解。其解释部分和左边的文字有关系。
6、已完成：双页书籍界面——BookInterface 装帧外框、纸张纹理、书脊丝带、页角折页、页眉金饰与台灯暖光，空页「翻开书页」引导。
7、左边的对话框是可以编辑的。
8、右侧也可以也可以调用本地的corsur的对话框，进行内容的解析
9、本界面程序是/Users/maodongya/Documents/java/game/snake/ai-book生成的，请学习ai-book下的程序代码，准备修改该程序
10、左边的输入法不正确。输入乱码。请帮排查原因。修改程序后，重启本程序。并把上面的内容写入到readme.txt
11、请按左边第8条进行学习。学习后，为右的ai功能添加功能，重启本程序的时候，ai模块能记住提示词上下文，可以在再此打开的时候使用上次的提示词上下文。
12、按照corsur的对话框，改造右边的corsor对话模块。增加发送，执行暂停，模型选择，上下文长度被百分比等
13、已完成：AppGuard 统一校验、未保存提示、左页拖入 .txt、命令笔记自动保存、⌘R 讲解快捷键。
14、请为本程序添加book的图标，并打包成可运行的mac程序，安装到本地应用程序。并把本条命令移动到左侧，并进行保存。
15、已完成：书籍图标、/Applications/AIBook.app 安装包，第14条命令已加载到左页并可通过 ⌘S 保存到本地笔记。
16、已完成：自我进化闭环——SelfEvolution 解析左页命令驱动 Cursor 改源码；修正安装包运行时源码目录解析（Package.swift），进化后自动标记 readme 并打包重启。
17、已完成：自我进化模块（顶部「进化」按钮）、上下文节选围绕选中内容、思考过程流式显示增强；源码见 ai-book/Sources/AIBook。
18、已完成：第 1 条进化——新增 ReadingAssistant.swift，界面顶栏「辅助读书」标签，讲解/追问统一读书助手角色（进化任务除外）。
19、已完成：第 2 条进化——新增 SwiftPlatform.swift，顶栏「Swift · SwiftUI」标签，设置页「关于」展示技术栈说明。
20、已完成：第 3 条进化——LLMConnector/LLMConfigPanel 多模型连接，右页「测试连接」验证提供商可用性。
21、已完成：进化对话结束后自动执行 build-and-install 并重启 AIBook（AppRelauncher 模块）。
22、已完成：进化时跳过结尾带「（已经完成）」及「已完成」等标记的命令行（EvolutionPlanner.isCommandCompleted）。
23、已完成：第 6 条进化——BookInterface 模块：皮革装帧、纸张纹理、丝带书签、页角折页、页眉装饰与书桌暖光。
24、已完成：第 13 条进化——AppGuard 模块、未保存放弃确认、拖拽打开 txt、命令笔记 2 秒自动保存、⌘R 讲解。
25、已完成：第 16 条进化——SelfEvolution + CursorAuthBootstrap，进化自动标记 readme，Cursor settingSources 自动授权。
26、已完成：第 16 条进化——修正 defaultProjectDirectory 优先解析 ai-book 源码树（非 .app Resources），进化 prompt 指向 Sources/AIBook。
27、已完成：第 1 条进化——AIBookProduct 模块固化 ai-book 产品定位，顶栏 slug 标签与设置「关于」展示。
28、已完成：另存为进化——DocumentExporter 模块：记住上次目录、覆盖确认、页脚保存提示；支持 ⌘⇧S 另存为与 ⌘⌥S 导出选中文字。
25、已完成：仿照 Cursor 右页完善大模型 API——LLMComposerView 提供商/模型选择、原文节选占比、上下文占用统计、发送/停止（⌘↩）、流式 SSE 输出；独立 llmContextPercent。
29、已完成：第 25 条进化——LLMComposerView 对标 CursorComposerView，LLMService 流式 chat 与停止，右页读书助手流式气泡。
30、已完成：第 26 条进化——设置页 LLMProfilesSettingsView 同时配置多家大模型 API（LLMProfileStore 按提供商独立存储 Key/地址/模型），右页提供商列表显示已配置数量。
