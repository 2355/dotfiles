#!/usr/bin/env node
// 日報の「💡 学びと気づき」を Anki に登録するための補助コマンド。
//
//   pending  <out.json>                    未処理の学びを書き出す
//   decks                                  日報のカードを入れてよいデッキの一覧を出す
//   register <cards.json> <pending.json>   カードを登録し、pending の全件を処理済みにする
//   seed     <YYYY-MM-DD>                  指定日以前の学びを処理済みとして記録する（state を作り直すとき用）
//
// 処理済みかどうかは日付ではなく学び 1 件ごとのハッシュで判定する。
// 日付で区切ると、書きかけの日報を処理したあとに追記された学びが漏れるため。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const NIPPO_DIR = process.env.NIPPO_DIR ?? path.join(os.homedir(), 'work/nippo');
const STATE_FILE = process.env.NIPPO_ANKI_STATE ?? path.join(os.homedir(), '.local/state/nippo-anki/processed.json');
// Anki の標準ノートタイプ名は UI 言語で変わるので、既知の名前から探す。それ以外の言語では env で指定する
const MODEL_CANDIDATES = process.env.NIPPO_ANKI_MODEL ? [process.env.NIPPO_ANKI_MODEL] : ['基本', 'Basic'];
// Anki が最初から持つ既定デッキの id。名前は UI 言語で変わるので id で見分ける。分野別に振り分けるので使わない
const DEFAULT_DECK_ID = 1;

const sha = (s) => crypto.createHash('sha1').update(s).digest('hex');

function extractAll() {
  const out = [];
  const files = fs.readdirSync(NIPPO_DIR).filter((f) => /^\d{4}-\d{2}-\d{2}\.md$/.test(f)).sort();
  for (const f of files) {
    const date = f.slice(0, 10);
    let inSection = false;
    let inFence = false;
    let cur = null;
    const flush = () => { if (cur) out.push(cur); cur = null; };
    for (const line of fs.readFileSync(path.join(NIPPO_DIR, f), 'utf8').split('\n')) {
      // コードブロック内の `- ` や `## ` を学びの区切りと誤認しないよう、フェンスの中は本文として扱う
      if (/^\s*```/.test(line)) inFence = !inFence;
      if (!inFence && /^#{1,2} /.test(line)) { flush(); inSection = line.includes('学びと気づき'); continue; }
      if (!inSection) continue;
      if (!inFence && /^- /.test(line)) { flush(); cur = { date, text: line.slice(2).trim() }; }
      // 子要素は親の学びの補足なので、親と一緒にカード化の材料にする
      else if (cur && line.trim()) cur.text += '\n' + line.trim();
    }
    flush();
  }
  return out.map((x) => ({ ...x, hash: sha(`${x.date}\n${x.text}`) }));
}

const loadState = () => (fs.existsSync(STATE_FILE) ? new Set(JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'))) : new Set());
function saveState(set) {
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  // 書き込み途中で落ちて JSON が壊れると以後すべての実行が失敗するので、rename で置き換える
  const tmp = `${STATE_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify([...set].sort(), null, 1));
  fs.renameSync(tmp, STATE_FILE);
}

async function anki(action, params = {}) {
  let res;
  try {
    res = await fetch('http://localhost:8765', { method: 'POST', body: JSON.stringify({ action, version: 6, params }) });
  } catch {
    throw new Error('AnkiConnect に接続できない。Anki.app が起動しているか確認する');
  }
  const { result, error } = await res.json();
  if (error) throw new Error(`${action}: ${error}`);
  return result;
}

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
// Markdown のまま入れると ` や ** が記号として表示されるので、最低限だけ HTML にする
const toHtml = (s) => esc(s).replace(/`([^`]+)`/g, '<code>$1</code>').replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>').replace(/\n/g, '<br>');

// 日報のカードを入れてよいデッキ = nippo タグのカードが既に入っているデッキ。
// Anki 全体のデッキを候補にすると、英単語など日報と無関係なデッキに振り分けかねないため
async function nippoDecks() {
  const cardIds = await anki('findCards', { query: 'tag:nippo' });
  return cardIds.length ? Object.keys(await anki('getDecks', { cards: cardIds })).sort() : [];
}

async function register(cardsFile, pendingFile) {
  const cards = JSON.parse(fs.readFileSync(cardsFile, 'utf8'));
  const pending = JSON.parse(fs.readFileSync(pendingFile, 'utf8'));
  const bad = cards.filter((c) => !c.question?.trim() || !c.answer?.trim() || !c.date || !c.deck?.trim());
  if (bad.length) throw new Error(`不正なカード: ${JSON.stringify(bad, null, 1)}`);

  const allDecks = await anki('deckNamesAndIds');
  const defaultDeck = Object.keys(allDecks).find((d) => allDecks[d] === DEFAULT_DECK_ID);
  // Anki のデッキ名は大文字小文字を区別しないので、既存デッキの正式な表記に揃える
  const canonical = new Map(Object.keys(allDecks).map((d) => [d.toLowerCase(), d]));
  cards.forEach((c) => (c.deck = canonical.get(c.deck.toLowerCase()) ?? c.deck));
  if (cards.some((c) => c.deck === defaultDeck)) throw new Error(`既定デッキ（${defaultDeck}）には登録しない`);

  // 選別のたびに分類がぶれてデッキが増えていかないよう、nippo 用でないデッキはユーザが認めたもの（newDeck: true）に限る
  const allowed = new Set(await nippoDecks());
  const approved = new Set(cards.filter((c) => c.newDeck).map((c) => c.deck));
  const unknown = [...new Set(cards.map((c) => c.deck).filter((d) => !allowed.has(d) && !approved.has(d)))];
  if (unknown.length) throw new Error(`日報用でないデッキ（ユーザに確認して newDeck: true を付ける）: ${unknown.join(', ')}`);
  // デッキは分野ごとにトップレベルに置く方針なので、階層を作る名前は受け付けない
  const nested = [...approved].filter((d) => !allowed.has(d) && d.includes('::'));
  if (nested.length) throw new Error(`新しいデッキ名に :: は使わない: ${nested.join(', ')}`);
  const seen = new Set();
  const dupInBatch = cards.filter((c) => seen.has(`${c.deck}\n${c.question}`) || !seen.add(`${c.deck}\n${c.question}`));
  if (dupInBatch.length) throw new Error(`同じデッキに同じ問いが複数ある: ${dupInBatch.map((c) => c.question).join(' / ')}`);

  const models = await anki('modelNames');
  const MODEL = MODEL_CANDIDATES.find((m) => models.includes(m));
  if (!MODEL) throw new Error(`ノートタイプ ${MODEL_CANDIDATES.join(' / ')} が無い。NIPPO_ANKI_MODEL で表面・裏面の 2 フィールドを持つノートタイプを指定する`);
  const [front, back] = await anki('modelFieldNames', { modelName: MODEL });
  const notes = cards.map((c) => ({
    deckName: c.deck,
    modelName: MODEL,
    fields: {
      [front]: toHtml(c.question),
      [back]: `${toHtml(c.answer)}<br><br><small>出典: ${c.date} の日報</small>`,
    },
    tags: [...(c.unsure ? ['要確認'] : []), 'nippo', `nippo::${c.date}`],
    // 同じ問いの二重登録を防ぐ（Anki はデッキ内で表面の一致を重複とみなす）
    options: { allowDuplicate: false, duplicateScope: 'deck' },
  }));

  // 存在しないデッキは canAddNotes で「追加不可」になり重複と区別できないので、判定前に作っておく
  const created = [...new Set(notes.map((n) => n.deckName))].filter((d) => !(d in allDecks));
  for (const d of created) await anki('createDeck', { deck: d });
  let checks, ids;
  try {
    checks = await anki('canAddNotesWithErrorDetail', { notes });
    const other = checks.map((c, i) => [c, i]).filter(([c]) => !c.canAdd && !/duplicate/i.test(c.error ?? ''));
    // 重複以外の理由で登録できないカードを黙って捨てると、元の学びだけ処理済みになって二度と拾えない
    if (other.length) throw new Error(`登録できないカード: ${other.map(([c, i]) => `${cards[i].question} (${c.error})`).join(' / ')}`);
    const addable = notes.filter((_, i) => checks[i].canAdd);
    ids = addable.length ? await anki('addNotes', { notes: addable }) : [];
    // AnkiConnect の版によっては、失敗した分を例外でなく null で返す
    if (ids.includes(null)) throw new Error(`登録失敗 ${ids.filter((x) => x === null).length} 件`);
  } catch (e) {
    // 空の新規デッキが残ると、次回から承認なしで使えるデッキに見えてしまうので消す。カードが入ったものは消さない
    const empty = [];
    for (const d of created) if (!(await anki('findCards', { query: `"deck:${d}"` })).length) empty.push(d);
    if (empty.length) await anki('deleteDecks', { decks: empty, cardsToo: true });
    throw new Error(`${e.message}（何も処理済みにしていない）`);
  }
  const addable = notes.filter((_, i) => checks[i].canAdd);
  const skippedDuplicate = cards.filter((_, i) => !checks[i].canAdd).map((c) => c.question);

  const state = loadState();
  pending.forEach((p) => state.add(p.hash));
  saveState(state);

  const byDeck = {};
  addable.forEach((n) => (byDeck[n.deckName] = (byDeck[n.deckName] ?? 0) + 1));
  console.log(JSON.stringify({ added: ids.length, skippedDuplicate, byDeck, markedProcessed: pending.length }, null, 1));
}

function usage() {
  console.error('usage: nippo-anki.mjs pending <out.json> | decks | register <cards.json> <pending.json> | seed <YYYY-MM-DD>');
  process.exit(1);
}

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'pending' && args[0]) {
  const state = loadState();
  const all = extractAll();
  const processedDates = new Set(all.filter((x) => state.has(x.hash)).map((x) => x.date));
  const items = all
    .filter((x) => !state.has(x.hash))
    // 同じ日の学びが既に処理済みなら、この学びは後から直した・追記したものの可能性がある
    .map((x, i) => ({ id: i, ...x, dateHasProcessed: processedDates.has(x.date) }));
  fs.writeFileSync(args[0], JSON.stringify(items, null, 1));
  const dates = [...new Set(items.map((x) => x.date))];
  console.log(`pending=${items.length} dates=${dates.join(',') || '-'} dateHasProcessed=${items.filter((x) => x.dateHasProcessed).length}`);
} else if (cmd === 'decks') {
  console.log(JSON.stringify(await nippoDecks()));
} else if (cmd === 'register' && args[0] && args[1]) {
  await register(args[0], args[1]);
} else if (cmd === 'seed' && /^\d{4}-\d{2}-\d{2}$/.test(args[0] ?? '')) {
  // 誤って全件を処理済みにしないよう、日付の指定を必須にしている
  const state = loadState();
  extractAll().filter((x) => x.date <= args[0]).forEach((x) => state.add(x.hash));
  saveState(state);
  console.log(`processed=${state.size}`);
} else {
  usage();
}
