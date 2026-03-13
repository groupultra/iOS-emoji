# Emoji 多语言搜索关键词 — 实施计划

## 一、现状分析

### 1.1 当前搜索机制

- 每个 `MCEmoji` 有一个 `searchKey: String`，是英文 camelCase 格式（如 `"grinningFace"`、`"rollingOnTheFloorLaughing"`）
- 搜索逻辑在 `MCEmojiPickerViewModel.rebuildFilteredCategories()` 中，使用简单的 `emoji.searchKey.lowercased().contains(query)` 做子串匹配
- 不支持任何非英文搜索

### 1.2 数据规模

| 指标 | 数值 |
|------|------|
| Emoji 总数 | 1,870 |
| 唯一 searchKey | 1,869 |
| 8 个分类 | emotionsAndPeople(529), animalsAndNature(152), foodAndDrinks(133), activities(85), travellingAndPlaces(218), items(261), symbols(223), flags(269) |
| 当前 JSON 数据总体积 | 216 KB |
| 现有本地化语言 | 40 个（但仅翻译了 9 个分类名称字符串，不含搜索关键词） |

### 1.3 数据存储方式

- emoji 定义硬编码在 `MCEmojiDefinitions.swift`（11,284 行），通过 `MCEmojiPickerJSON` target 编译生成 8 个 JSON 文件到 `Resources/EmojiDefinitions/` 目录
- 运行时通过 `MCUnicodeManager.emojis(for:)` 从 JSON 加载，并按 iOS 版本过滤

---

## 二、数据源选择：Unicode CLDR 官方数据

### 2.1 为什么选 CLDR 官方数据

| 对比项 | emojibase-data | CLDR 官方 (cldr-annotations-full) |
|--------|---------------|----------------------------------|
| 来源权威性 | 社区维护，基于 CLDR 二次加工 | **Unicode 官方维护**，权威标准 |
| 语言覆盖 | 27 种语言 | **150+ 种语言/地区**（完全覆盖我们的 40 种） |
| 数据一致性 | 社区额外添加的 tags 可能不稳定 | 与 Apple 键盘 emoji 搜索数据同源 |
| 安装方式 | `npm install emojibase-data` | `npm install cldr-annotations-full` |
| 最新版本 | v17.0.0 | **v48.1.0**（2026-01-08） |
| 我们 40 种语言的覆盖率 | ~50%（约 20 种有数据，15 种缺失） | **100%（全部 40 种都有数据）** |

**结论：CLDR 官方数据完胜**，尤其是语言覆盖率 100%，不需要任何 fallback 逻辑。

### 2.2 CLDR 由两个 npm 包组成

| 包名 | 内容 | 我们是否需要 |
|------|------|-------------|
| `cldr-annotations-full` | 基础 emoji 注释（😀、🎉、🐱等） | ✅ **需要** |
| `cldr-annotations-derived-full` | 派生注释（肤色变体 👋🏻、性别变体 👩‍⚕️ 等） | ❌ 不需要（我们的肤色通过 `MCEmojiSkinTone` 动态处理） |

**只需安装 `cldr-annotations-full`，数据量更小更干净。**

### 2.3 CLDR annotations JSON 数据结构

`cldr-annotations-full` 中每个语言的 `annotations.json`：

```json
{
  "annotations": {
    "identity": { "language": "en" },
    "annotations": {
      "😀": {
        "default": ["face", "grin", "grinning"],
        "tts": ["grinning face"]
      },
      "😶‍🌫️": {
        "default": ["absentminded", "clouds", "face", "fog", "head"],
        "tts": ["face in clouds"]
      }
    }
  }
}
```

- **key** = emoji 字符本身（如 `"😀"`、`"😶‍🌫️"`）
- **`default`** = 搜索关键词数组（**这就是我们要的核心数据**）
- **`tts`** = text-to-speech 名称（可拆词后也纳入搜索）

### 2.4 emoji 字符 ↔ emojiKeys 映射

当前 MCEmoji 的 `emojiKeys` 是整数数组，如 `[0x1F600]`。

映射规则：将 `emojiKeys` 转为 emoji 字符串来匹配 CLDR 的 key：
```swift
let emojiString = emojiKeys.map { String(UnicodeScalar($0)!) }.joined()
// [0x1F600] → "😀"
// [0x1F636, 0x200D, 0x1F32B, 0xFE0F] → "😶‍🌫️"
```

**优势**：CLDR 直接用 emoji 字符做 key，比 hexcode 映射更简单直接。

### 2.5 语言覆盖情况

CLDR 完全覆盖我们当前的 40 种语言：

| emojipicker 语言 | CLDR 对应目录 |
|-----------------|--------------|
| ar | `ar/` |
| ca | `ca/` |
| cs | `cs/` |
| da | `da/` |
| de | `de/` |
| el | `el/` |
| en | `en/` |
| en-AU | `en-AU/` |
| en-GB | `en-GB/` |
| en-IN | `en-IN/` |
| es | `es/` |
| es-419 | `es-419/` |
| fi | `fi/` |
| fr | `fr/` |
| fr-CA | `fr-CA/` |
| he | `he/` |
| hi | `hi/` |
| hr | `hr/` |
| hu | `hu/` |
| id | `id/` |
| it | `it/` |
| ja | `ja/` |
| ko | `ko/` |
| ms | `ms/` |
| nb | `no/`（CLDR 中挪威语书面语用 `no`） |
| nl | `nl/` |
| pl | `pl/` |
| pt-BR | `pt/`（CLDR 中 pt 默认为巴西葡语） |
| pt-PT | `pt-PT/` |
| ro | `ro/` |
| ru | `ru/` |
| sk | `sk/` |
| sv | `sv/` |
| th | `th/` |
| tr | `tr/` |
| uk | `uk/` |
| vi | `vi/` |
| zh-HK | `zh-Hant-HK/` |
| zh-Hans | `zh/`（CLDR 中 zh 默认简体） |
| zh-Hant | `zh-Hant/` |

**✅ 40/40 全覆盖，无需 fallback。**

---

## 三、目标产出物

生成一组 **按语言分隔的搜索关键词 JSON 文件**，每个文件结构为：

```json
{
  "😀": ["face", "grin", "grinning", "grinning face"],
  "😶‍🌫️": ["absentminded", "clouds", "face", "fog", "head", "face in clouds"],
  ...
}
```

- key = emoji 字符（与 `MCEmoji.emojiKeys` 可通过 `emojiKeys.emoji()` 转换得到）
- value = 该语言下的搜索关键词数组（`default` + `tts` 拆词合并去重）

文件命名：`searchKeywords_en.json`、`searchKeywords_zh.json`、`searchKeywords_ja.json` 等。

### 3.1 数据规模预估

| 指标 | 数值 |
|------|------|
| 需要提取的 emoji 数量 | ~1,870（只取我们用到的） |
| 平均每个 emoji 关键词数 | ~5 个（CLDR `default` 数组） |
| 单语言 JSON 文件大小 | ~60-100 KB |
| 运行时只加载 1 个语言文件 | 内存增量 ~60-100 KB，可忽略 |
| 全部 40 种语言打包 | 原始 ~2.4-4 MB → App Store 压缩后 ~1-1.5 MB |

---

## 四、实施步骤

### Phase 1：构建数据提取脚本（build-time，一次性）

**目标**：从 CLDR 官方数据提取我们需要的搜索关键词，生成精简的 JSON 文件。

1. 在 `emojipicker/` 根目录创建 `scripts/` 文件夹
2. 创建 Node.js 脚本 `scripts/extract-search-keywords.js`：
   - `npm install cldr-annotations-full@48.1.0`
   - 读取当前 emoji 定义文件（`Resources/EmojiDefinitions/*.json`），将每个 emoji 的 `emojiKeys` 转为 emoji 字符串，形成"我们需要的 emoji 集合"
   - 定义 40 种语言的映射表（emojipicker locale → CLDR 目录名）
   - 遍历每种语言的 `annotations.json`
   - 对于我们的每个 emoji 字符，提取 `default` 关键词 + `tts` 名称拆词，合并去重
   - 输出 `Resources/SearchKeywords/searchKeywords_{locale}.json`
3. 脚本输出匹配率报告（匹配到的 emoji / 我们需要的 emoji）

**预估工作量**：脚本约 80-120 行。

### Phase 2：修改 MCEmoji 模型

**目标**：让 MCEmoji 支持多关键词搜索。

当前：
```swift
private(set) public var searchKey: String   // "grinningFace"
```

改为：
```swift
private(set) public var searchKey: String           // 保留，用于向后兼容
public var searchTags: [String] = []                // 运行时从 JSON 加载填充
```

- `searchKey` 保持不变（不动现有 JSON 和 Codable 结构）
- `searchTags` 不参与 Codable，作为运行时注入的属性

### Phase 3：添加搜索关键词加载器

**目标**：在 `MCUnicodeManager` 中，加载当前语言的关键词 JSON，并注入到每个 MCEmoji 中。

新增文件 `Services/MCSearchKeywordsLoader.swift`：

```swift
struct MCSearchKeywordsLoader {
    /// 加载当前 APP 语言对应的搜索关键词文件
    /// 返回 [emoji字符: [keyword]] 字典
    static func loadKeywords() -> [String: [String]]
}
```

在 `MCUnicodeManager.getEmojisForCurrentIOSVersion()` 中：
1. 调用 `MCSearchKeywordsLoader.loadKeywords()` 获取当前语言的关键词字典
2. 遍历所有 emoji，通过 `emoji.string`（即 emoji 字符）匹配，将 `searchTags` 注入
3. 对于匹配不上的 emoji，将原有 `searchKey` 按 camelCase 拆词后作为 `searchTags` 的 fallback

**语言匹配逻辑**（按优先级）：
```
APP 语言 zh-Hans → 尝试 searchKeywords_zh-Hans.json
                  → fallback searchKeywords_zh.json
                  → fallback searchKeywords_en.json
```

### Phase 4：修改搜索逻辑

**目标**：用关键词前缀匹配替代当前的子串匹配。

当前 `MCEmojiPickerViewModel.rebuildFilteredCategories()`：
```swift
emoji.searchKey.lowercased().contains(query)
```

改为：
```swift
emoji.searchTags.contains { tag in
    tag.hasPrefix(query)
}
```

**为什么用前缀匹配（hasPrefix）而不是子串匹配（contains）**：
- 关键词已经是拆好的独立词了，不再是 camelCase 拼接
- 前缀匹配更符合用户搜索习惯（输入 "grin" 应该匹配 "grinning"，但不应匹配某个中间包含 "grin" 的词）
- 前缀匹配性能更优
- 对 CJK 语言（中日韩），前缀匹配也能正确工作（如输入 "笑" 匹配 "笑脸"）

**搜索示例**：
- 用户输入 "笑" → 匹配 searchTags 中包含 "笑脸"、"大笑" 等的 emoji（中文 CLDR 数据）
- 用户输入 "smile" → 匹配 tags 中包含 "smile"、"smiling" 的 emoji
- 用户输入 "顔" → 匹配日文关键词中的笑脸 emoji

### Phase 5：将关键词 JSON 集成到 Xcode 项目

1. 将生成的 `searchKeywords_*.json` 文件放入 `Resources/SearchKeywords/` 目录
2. 在 `Package.swift` 的 resources 中注册该目录
3. 确保 `Bundle.module` 能正确加载这些文件

---

## 五、需要修改的文件清单

| 文件 | 修改类型 | 说明 |
|------|---------|------|
| `scripts/extract-search-keywords.js` | **新建** | 数据提取脚本（一次性工具） |
| `scripts/package.json` | **新建** | `cldr-annotations-full` 依赖声明 |
| `Resources/SearchKeywords/*.json` | **新建** | 40 个语言的关键词 JSON 文件 |
| `Model/MCEmoji.swift` | 修改 | 添加 `searchTags: [String]` 属性 |
| `Services/MCUnicodeManager.swift` | 修改 | 加载关键词并注入到 emoji |
| `Services/MCSearchKeywordsLoader.swift` | **新建** | 关键词加载与语言匹配逻辑 |
| `ViewModel/MCEmojiPickerViewModel.swift` | 修改 | 搜索逻辑改为 `searchTags` 前缀匹配 |
| `Package.swift` | 修改 | 注册 SearchKeywords 资源目录 |

---

## 六、风险与注意事项

### 6.1 emoji 字符匹配率

CLDR 用 emoji 字符做 key，我们也用 emoji 字符做匹配，理论上应该高度一致。但需注意：
- **变体选择符 `FE0F`（VS16）差异**：有些 emoji 带或不带 `FE0F` 都合法，CLDR 中的 key 可能与我们的 `emojiKeys` 生成的字符串存在差异
- **提取脚本中的处理**：先严格匹配；失败后尝试去掉/添加 `FE0F` 再匹配
- 输出未匹配的 emoji 列表供人工检查

### 6.2 CLDR 区域变体文件的内容

部分区域变体文件（如 `en-AU`、`fr-CA`）可能只包含差异项，不包含全量数据。提取脚本中应：
1. 先加载基础语言文件（如 `en`）
2. 再加载区域变体文件（如 `en-AU`）覆盖差异项
3. 合并后输出

### 6.3 包体积影响

- 40 个语言的关键词 JSON，原始总量约 2.4-4 MB
- App Store 自动 asset 压缩后约 1-1.5 MB 增量
- 完全可以接受

### 6.4 运行时性能

- 加载 1 个语言的 JSON（60-100 KB）：< 10ms
- 搜索 1,870 个 emoji 的 tags 数组：< 1ms
- 对用户体验无感知

### 6.5 后续 CLDR 版本升级

当 Unicode 发布新 emoji 版本时，只需：
1. 升级 `cldr-annotations-full` 包版本
2. 重新运行提取脚本
3. 将新生成的 JSON 文件替换旧文件

---

## 七、执行顺序建议

```
Phase 1  →  跑脚本，验证匹配率和数据质量
Phase 2  →  Phase 3  →  Phase 4（可串行，改动量不大）
Phase 5  →  集成测试
```

建议先执行 Phase 1 的脚本，确认 emoji 字符匹配率达到 95% 以上再继续后续步骤。
