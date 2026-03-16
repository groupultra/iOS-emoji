/**
 * extract-search-keywords.js
 *
 * 从 CLDR 官方数据中提取 40 种语言的 emoji 搜索关键词，
 * 输出到 Sources/MCEmojiPicker/Resources/SearchKeywords/searchKeywords_{locale}.json
 *
 * 运行方式：
 *   cd emojipicker/scripts
 *   npm install
 *   node extract-search-keywords.js
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// ── 路径配置 ──────────────────────────────────────────────────────────────────

const EMOJI_DEFINITIONS_DIR = resolve(
  __dirname,
  '../Sources/MCEmojiPicker/Resources/EmojiDefinitions'
);
const OUTPUT_DIR = resolve(
  __dirname,
  '../Sources/MCEmojiPicker/Resources/SearchKeywords'
);
const CLDR_ANNOTATIONS_DIR = resolve(
  __dirname,
  'node_modules/cldr-annotations-full/annotations'
);
// 派生注释：包含性别变体、家庭组合、国旗等 ZWJ 序列
const CLDR_DERIVED_ANNOTATIONS_DIR = resolve(
  __dirname,
  'node_modules/cldr-annotations-derived-full/annotationsDerived'
);

const EMOJI_DEFINITION_FILES = [
  'emotionsAndPeople.json',
  'animalsAndNature.json',
  'foodAndDrinks.json',
  'activities.json',
  'travellingAndPlaces.json',
  'items.json',
  'symbols.json',
  'flags.json',
];

// ── 语言映射表：emojipicker locale → CLDR 目录名 ──────────────────────────────
// 格式：[appLocale, cldrBase, cldrRegional?]
// cldrBase: 先加载该基础语言作为全量数据
// cldrRegional: 再用此区域变体覆盖差异项（可选）

const LOCALE_MAP = [
  ['ar',      'ar'],
  ['ca',      'ca'],
  ['cs',      'cs'],
  ['da',      'da'],
  ['de',      'de'],
  ['el',      'el'],
  ['en',      'en'],
  ['en-AU',   'en', 'en-AU'],
  ['en-GB',   'en', 'en-GB'],
  ['en-IN',   'en', 'en-IN'],
  ['es',      'es'],
  ['es-419',  'es', 'es-419'],
  ['fi',      'fi'],
  ['fr',      'fr'],
  ['fr-CA',   'fr', 'fr-CA'],
  ['he',      'he'],
  ['hi',      'hi'],
  ['hr',      'hr'],
  ['hu',      'hu'],
  ['id',      'id'],
  ['it',      'it'],
  ['ja',      'ja'],
  ['ko',      'ko'],
  ['ms',      'ms'],
  ['nb',      'no'],        // Norwegian Bokmål → CLDR `no`
  ['nl',      'nl'],
  ['pl',      'pl'],
  ['pt-BR',   'pt'],        // CLDR `pt` 默认是巴西葡语
  ['pt-PT',   'pt', 'pt-PT'],
  ['ro',      'ro'],
  ['ru',      'ru'],
  ['sk',      'sk'],
  ['sv',      'sv'],
  ['th',      'th'],
  ['tr',      'tr'],
  ['uk',      'uk'],
  ['vi',      'vi'],
  ['fil',     'fil'],
  ['pt',      'pt'],
  ['zh-HK',   'zh-Hant', 'zh-Hant-HK'],
  ['zh-Hans', 'zh'],
  ['zh-Hant', 'zh-Hant'],
];

// ── 工具函数 ──────────────────────────────────────────────────────────────────

/** 加载单个 CLDR annotations.json，返回 annotations 对象（emoji → {default, tts}） */
function loadCldrAnnotations(locale) {
  const filePath = resolve(CLDR_ANNOTATIONS_DIR, locale, 'annotations.json');
  if (!existsSync(filePath)) {
    console.warn(`  ⚠ CLDR 文件不存在: ${filePath}`);
    return {};
  }
  const raw = JSON.parse(readFileSync(filePath, 'utf-8'));
  return raw.annotations?.annotations ?? {};
}

/** 加载单个 CLDR annotationsDerived/annotations.json（派生：ZWJ序列、国旗等） */
function loadCldrDerivedAnnotations(locale) {
  const filePath = resolve(CLDR_DERIVED_ANNOTATIONS_DIR, locale, 'annotations.json');
  if (!existsSync(filePath)) return {};
  const raw = JSON.parse(readFileSync(filePath, 'utf-8'));
  // derived-full 顶层 key 是 "annotationsDerived"，不是 "annotations"
  return raw.annotationsDerived?.annotations ?? {};
}

/**
 * 合并 base + regional CLDR 数据，regional 覆盖 base 的差异项
 * 对于区域变体文件，CLDR 只包含与 base 不同的项
 */
function mergeAnnotations(base, regional) {
  if (!regional) return base;
  return { ...base, ...regional };
}

/** 去除 emoji 字符串中所有 FE0F (variation selector-16) */
function stripFE0F(str) {
  return str.replace(/\uFE0F/g, '');
}

/**
 * 从 CLDR annotations 中查找 emoji 对应的关键词
 * 策略：
 *   1. 严格匹配（含 FE0F 的 key）
 *   2. 去除我们 emoji 的 FE0F 后直接查（CLDR 可能不带 FE0F）
 *   3. 在 stripped CLDR key 映射表中查（CLDR 带 FE0F 但我们没带）
 */
function findCldrEntry(emojiStr, annotations, strippedKeyMap) {
  if (annotations[emojiStr]) return annotations[emojiStr];
  const stripped = stripFE0F(emojiStr);
  // 最常见的 FE0F 差异：我们带 FE0F，CLDR key 不带
  if (stripped !== emojiStr && annotations[stripped]) return annotations[stripped];
  // 另一种差异：CLDR key 带 FE0F，但我们不带（较少见）
  if (strippedKeyMap[stripped]) return annotations[strippedKeyMap[stripped]];
  return null;
}

/**
 * 从 CLDR entry 提取关键词：
 * - default 数组直接使用
 * - tts 字段（单字符串）按空格拆词追加
 * 全部小写，去重，排序
 */
function extractKeywords(entry) {
  const words = new Set();
  if (entry.default) {
    for (const kw of entry.default) {
      words.add(kw.toLowerCase().trim());
    }
  }
  if (entry.tts) {
    // tts 可能是数组或字符串（CLDR 实际为数组）
    const ttsList = Array.isArray(entry.tts) ? entry.tts : [entry.tts];
    for (const ttsItem of ttsList) {
      const tts = ttsItem.toLowerCase().trim();
      // 整体名称（用于前缀匹配，如 "grinning face"）
      words.add(tts);
      // 拆词，让单词也能独立匹配
      for (const w of tts.split(/\s+/)) {
        if (w) words.add(w);
      }
    }
  }
  return [...words].sort();
}

// ── 主流程 ────────────────────────────────────────────────────────────────────

console.log('📂 加载 EmojiDefinitions JSON 文件...');

// 收集所有 emoji 字符串（去重）
const allEmojiStrings = new Set();
for (const filename of EMOJI_DEFINITION_FILES) {
  const filePath = resolve(EMOJI_DEFINITIONS_DIR, filename);
  const raw = JSON.parse(readFileSync(filePath, 'utf-8'));
  for (const emoji of raw.emojis) {
    allEmojiStrings.add(emoji.string);
  }
}

const emojiList = [...allEmojiStrings];
console.log(`✅ 共加载 ${emojiList.length} 个唯一 emoji 字符\n`);

// 确保输出目录存在
mkdirSync(OUTPUT_DIR, { recursive: true });

// 预先构建英语 annotations，用于 fallback（其他语言未翻译时使用英语关键词）
console.log('🔤 预加载英语数据作为 fallback...');
const enFull = mergeAnnotations(loadCldrAnnotations('en'), null);
const enDerived = mergeAnnotations(loadCldrDerivedAnnotations('en'), null);
const enAnnotations = { ...enDerived, ...enFull };
const enStrippedKeyMap = {};
for (const key of Object.keys(enAnnotations)) {
  const stripped = stripFE0F(key);
  if (stripped !== key && !enStrippedKeyMap[stripped]) {
    enStrippedKeyMap[stripped] = key;
  }
}
console.log(`✅ 英语 fallback 准备完毕（${Object.keys(enAnnotations).length} 条）\n`);

// 统计汇总
const summaryRows = [];

for (const [appLocale, cldrBase, cldrRegional] of LOCALE_MAP) {
  process.stdout.write(`处理 ${appLocale.padEnd(10)}`);

  // 加载 full 基础注释（~1,200 个常见 emoji）
  const baseAnnotations = loadCldrAnnotations(cldrBase);
  const regionalAnnotations = cldrRegional ? loadCldrAnnotations(cldrRegional) : null;
  const fullAnnotations = mergeAnnotations(baseAnnotations, regionalAnnotations);

  // 加载 derived 派生注释（ZWJ 序列、国旗、性别/家庭变体等）
  // derived 文件较大但只包含我们没有的 emoji
  const baseDerived = loadCldrDerivedAnnotations(cldrBase);
  const regionalDerived = cldrRegional ? loadCldrDerivedAnnotations(cldrRegional) : null;
  const derivedAnnotations = mergeAnnotations(baseDerived, regionalDerived);

  // 合并：full 优先，derived 作为补充（full 已有的不覆盖）
  const annotations = { ...derivedAnnotations, ...fullAnnotations };

  // 预构建"去除 FE0F 的 key → 原始 key"映射（用于 fallback 匹配）
  const strippedKeyMap = {};
  for (const key of Object.keys(annotations)) {
    const stripped = stripFE0F(key);
    if (stripped !== key && !strippedKeyMap[stripped]) {
      strippedKeyMap[stripped] = key;
    }
  }

  // 对每个 emoji 提取关键词
  const output = {};
  let matched = 0;
  const unmatched = [];

  for (const emojiStr of emojiList) {
    const entry = findCldrEntry(emojiStr, annotations, strippedKeyMap);
    if (entry) {
      output[emojiStr] = extractKeywords(entry);
      matched++;
    } else {
      // 当前语言无 CLDR 数据，尝试英语 fallback（主要针对国旗和 Keycap）
      const enEntry = findCldrEntry(emojiStr, enAnnotations, enStrippedKeyMap);
      if (enEntry) {
        output[emojiStr] = extractKeywords(enEntry);
        matched++;
      } else {
        unmatched.push(emojiStr);
      }
    }
  }

  const matchRate = ((matched / emojiList.length) * 100).toFixed(1);
  process.stdout.write(`→ 匹配 ${matched}/${emojiList.length} (${matchRate}%)\n`);

  // 写入输出文件
  const outputPath = resolve(OUTPUT_DIR, `searchKeywords_${appLocale}.json`);
  writeFileSync(outputPath, JSON.stringify(output, null, 0), 'utf-8');

  summaryRows.push({ locale: appLocale, matched, total: emojiList.length, matchRate, unmatched });
}

// ── 汇总报告 ──────────────────────────────────────────────────────────────────

console.log('\n══════════════════════════════════════════════');
console.log('                  汇总报告');
console.log('══════════════════════════════════════════════');

const allPassed = summaryRows.every(r => r.matched / r.total >= 0.95);
const avgRate = (summaryRows.reduce((s, r) => s + parseFloat(r.matchRate), 0) / summaryRows.length).toFixed(1);
console.log(`平均匹配率: ${avgRate}%`);
console.log(`验收标准 (>=95%): ${allPassed ? '✅ 全部通过' : '❌ 部分未通过'}`);

const failedLocales = summaryRows.filter(r => r.matched / r.total < 0.95);
if (failedLocales.length > 0) {
  console.log('\n❌ 未达标语言:');
  for (const r of failedLocales) {
    console.log(`  ${r.locale}: ${r.matchRate}%`);
  }
}

// 输出未匹配的 emoji（取第一个语言 `en` 的作为代表）
const enReport = summaryRows.find(r => r.locale === 'en');
if (enReport && enReport.unmatched.length > 0) {
  console.log(`\n未匹配 emoji（en 语言，共 ${enReport.unmatched.length} 个）:`);
  console.log(enReport.unmatched.join(' '));
}

console.log(`\n📁 输出目录: ${OUTPUT_DIR}`);
console.log(`📝 生成文件数: ${summaryRows.length}`);
