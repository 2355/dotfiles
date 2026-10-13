#!/usr/bin/env bash
# 指定日の Claude Code セッションから「ユーザ発言（AskUserQuestion への回答を含む）」と
# 「assistant のテキスト応答」だけを抜き出し、セッションごとの markdown として OUT_DIR に書き出す。
# JSONL の大半は tool_result（差分・ファイル内容など）で、そのまま読ませるとコンテキストを圧迫するため。
#
# usage: extract.sh [YYYY-MM-DD] [OUT_DIR]
#   日付省略時は今日（ローカルタイム）。OUT_DIR 省略時は mktemp で作成する。
#   標準出力に OUT_DIR と各セッションのサマリ（ファイル名・サイズ・発言数・タイトル）を出す。
#   読み込めずにスキップしたファイルは stderr に出す。
set -eu

DATE="${1:-$(date +%Y-%m-%d)}"
OUT_DIR="${2:-$(mktemp -d -t extract-learnings)}"
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
NIPPO_DIR="${NIPPO_DIR:-$HOME/work/nippo}"
NIPPO_DIR="${NIPPO_DIR%/}"
# 1 発言が長すぎると全体の分量が膨らむため上限を設ける。学びの抽出には冒頭で十分なことが多い
MAX_AI_CHARS="${MAX_AI_CHARS:-3000}"
MAX_USER_CHARS="${MAX_USER_CHARS:-2000}"

mkdir -p "$OUT_DIR"
# 同じ OUT_DIR で再実行したとき、今回は対象外になったセッションの md が残って混ざらないようにする
rm -f "$OUT_DIR"/*.md

# 書きかけの最終行（実行中のセッション）や想定外の形の行で全体が落ちないよう、1 行ずつ fromjson? で読む
read -r -d '' JQ_BODY <<'JQ' || true
def epoch: try (sub("\\.[0-9]+"; "") | fromdateiso8601) catch null;
def clip($n): if length > $n then .[0:$n] + "\n…(truncated)" else . end;

# スラッシュコマンド呼び出しは XML 風のラッパーで記録されるので、人が打った形に戻す
def unwrap_command:
  if test("^\\s*<command-(message|name)>") then
    ((capture("<command-name>(?<n>[^<]*)</command-name>").n) // "") + " " +
    ((capture("<command-args>(?<a>[\\s\\S]*?)</command-args>").a) // "")
  else . end;

def user_text:
  (.message.content // "")
  | if type == "string" then .
    elif type == "array" then map(select(.type? == "text") | .text // "") | join("\n")
    else "" end;

# AskUserQuestion への回答は tool_result として記録されるが、設計判断などユーザの意思表示そのものなので拾う
def answer_text:
  (.message.content // "")
  | if type == "array" then
      map(select(.type? == "tool_result")
          | (.content // "")
          | if type == "string" then .
            elif type == "array" then map(select(.type? == "text") | .text // "") | join("\n")
            else "" end
          | select(startswith("The user answered:"))
          | sub("\\s*Read the answers carefully[\\s\\S]*$"; ""))
      | join("\n")
    else "" end;

def ai_text:
  (.message.content // "")
  | if type == "array" then map(select(.type? == "text") | .text // "") | join("\n") else "" end;

# このスキル自身の実行以降を材料に含めると、自己言及的な「学び」が混ざる。
# セッション全体ではなく、起動した時点より後だけを落とす（同じセッションで先に行った作業は残す）
def is_self_invocation:
  (.type == "user" and ((user_text) | test("<command-name>/?extract-learnings</command-name>")))
  or (.type == "assistant"
      and (((.message.content // []) | if type == "array" then . else [] end)
           | any(.type? == "tool_use" and .name == "Skill" and ((.input.skill // "") | test("extract-learnings")))));

# 組み込みのローカルコマンドは操作であって会話ではない。これだけのセッションを「発言あり」と数えないために除く
def is_builtin_command:
  test("^/(model|clear|compact|config|status|cost|usage|mcp|permissions|resume|exit|fast|effort|context|memory|help|login|logout|doctor|rewind|export|ide|theme|vim|hooks|agents|plugin|statusline|add-dir|init|terminal-setup|upgrade|release-notes|bashes|todos|output-style)(\\s|$)");

[inputs | fromjson? | select(type == "object")] as $all
| ([$all | to_entries[] | select(.value | is_self_invocation) | .key] | first // ($all | length)) as $end
| $all[0:$end][]
| select(.isSidechain | not)
| (.timestamp // "" | epoch) as $t
| select($t != null and ($t | strflocaltime("%Y-%m-%d")) == $date)
| ($t | strflocaltime("%H:%M")) as $hm
| if .type == "user" and (.isMeta | not) and (.isCompactSummary | not) and (.isVisibleInTranscriptOnly | not) then
    ((user_text | unwrap_command) as $u
     # ハーネスが差し込む通知やローカルコマンド出力は会話ではないので除く
     | select($u != ""
         and ($u | test("^\\s*<(task-notification|local-command-stdout|local-command-stderr|local-command-caveat|bash-input|bash-stdout|bash-stderr|system-reminder)") | not)
         and ($u | startswith("[Request interrupted") | not)
         and ($u | is_builtin_command | not))
     | "### [\($hm)] USER\n\($u | clip($max_user))\n"),
    ((answer_text) as $a
     | select($a != "")
     | "### [\($hm)] USER (AskUserQuestion への回答)\n\($a | clip($max_user))\n")
  elif .type == "assistant" then
    (ai_text) as $a
    | select($a != "")
    | "### [\($hm)] CLAUDE\n\($a | clip($max_ai))\n"
  else empty end
JQ

# cwd・ブランチ・Claude Code が付けたタイトル。タイトルは内容とずれることがあるので参考情報として出す
read -r -d '' JQ_META <<'JQ' || true
[inputs | fromjson? | select(type == "object")]
| (map(select(.type == "user" and .cwd)) | first) as $u
| (map(select(.type == "ai-title")) | last | .aiTitle // "") as $title
| "cwd: \($u.cwd // "")\nbranch: \($u.gitBranch // "")\ntitle: \($title)"
JQ

# セッションは日をまたぐことがあるので、ファイルの mtime ではなくメッセージの timestamp で日付を判定する。
# ただし DATE より前に最終更新されたファイルには DATE のメッセージが存在し得ないので、候補の絞り込みにだけ mtime を使う。
# subagents/ 配下はサブエージェントの内部会話で、ユーザとのやりとりではないので対象外にする。
# 読めないディレクトリが 1 つあっても全体を止めないよう、find の失敗は無視する
{ find "$PROJECTS_DIR" -name '*.jsonl' -not -path '*/subagents/*' -newermt "$DATE" -print0 2>/dev/null || true; } |
  while IFS= read -r -d '' f; do
    sid="$(basename "$f" .jsonl)"
    out="$OUT_DIR/$sid.md"

    if ! meta="$(jq -Rnr "$JQ_META" "$f" 2>&1)"; then
      echo "skip: $f: $meta" >&2
      continue
    fi

    # 日報そのものを編集するセッション（nippo-add / nippo-finalize 等）は、書き起こし先と材料が循環するので除く
    cwd="$(printf '%s\n' "$meta" | sed -n 's/^cwd: //p')"
    case "${cwd%/}" in
      "$NIPPO_DIR" | "$NIPPO_DIR"/*) continue ;;
    esac

    if ! body="$(jq -Rnr --arg date "$DATE" --argjson max_ai "$MAX_AI_CHARS" --argjson max_user "$MAX_USER_CHARS" "$JQ_BODY" "$f" 2>&1)"; then
      echo "skip: $f: $body" >&2
      continue
    fi

    # 当日のユーザ発言がないセッション（自動実行や resume しただけのもの）は学びの材料にならない
    printf '%s\n' "$body" | grep -q '^### \[..:..\] USER' || continue

    {
      echo "# session $sid"
      echo
      echo "$meta"
      echo
      printf '%s\n' "$body"
    } > "$out"
  done

echo "OUT_DIR=$OUT_DIR"
for md in "$OUT_DIR"/*.md; do
  [ -e "$md" ] || continue
  printf '%s\t%s bytes\tuser=%s\t%s\n' \
    "$(basename "$md")" \
    "$(wc -c < "$md" | tr -d ' ')" \
    "$(grep -c '^### \[..:..\] USER' "$md")" \
    "$(sed -n 's/^title: //p' "$md")"
done
