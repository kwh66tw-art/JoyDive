#!/usr/bin/env bash
# commit_gate.sh — JD2-Logbook 提交前閘門（P6，2026-11-14；前身為 session scratchpad 內的 gate_1111.sh）
#
# 用法：
#   bash scripts/commit_gate.sh <路徑> [<路徑> …]   # 檢查這些路徑的未提交改動（含已暫存、未暫存、未追蹤）
#   bash scripts/commit_gate.sh --selftest           # 只跑量具自測（假值注入），不碰本 repo
#
# 檢查項目：
#   1. 機敏字串掃描：已追蹤檔案取 `git diff HEAD` 的新增行，未追蹤檔案取全文（略過二進位檔）。
#      每次執行前先用假值確認 regex 還抓得到（量具自我驗證）。
#   2. `_JD2-family/scripts/check_doc_version_sync.sh`：JD2-Logbook 列不得有 ❌
#      （整體結果可能因其他 App 落後而紅，只看本 repo 的列）。
#   3. `_JD2-family/scripts/check_trimix_boundary.sh`：必須回傳 0。
#
# 輸出與回傳碼：
#   GATE_OK          rc=0   全部通過
#   GATE_FAIL        rc=1   有檢查沒過（訊息說明哪一項）
#   (用法)           rc=2   參數錯誤
#   INVALID          rc=3   量具本身失效（自測沒抓到假值、找不到家族腳本）——不是「通過」
#   SELFTEST_CAUGHT  rc=0   --selftest：假值兩種情境都被抓到
#
# ⚠️ 本 repo（JoyDive）是公開 repo：本檔只放 regex，不放任何真實值。
#    自測用的假 token 在執行時才組字串，檔案裡不會出現完整的 token 樣式（否則閘門會攔到自己）。
# ⚠️ 未接 hook——要改成自動執行需另行裁示（設定變更）。

set -euo pipefail

PAT='(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|ca-app-pub-[0-9]{16}[~/][0-9]{10}|password *[:=] *[^ ]+)'

fake_token() { printf 'gh%s_%s' p "$(printf 'A%.0s' $(seq 1 28))"; }

# 掃描指定 repo 中指定路徑的未提交改動，印出命中數。
scan_hits() {
  local repo="$1"; shift
  local tracked untracked
  tracked=$(git -C "$repo" diff HEAD -- "$@" | grep '^+' | grep -v '^+++' | { grep -cE "$PAT" || true; })
  untracked=0
  while IFS= read -r -d '' f; do
    local n
    n=$( { grep -IcE "$PAT" "$repo/$f" 2>/dev/null || true; } )
    untracked=$((untracked + ${n:-0}))
  done < <(git -C "$repo" ls-files -z --others --exclude-standard -- "$@")
  echo $((tracked + untracked))
}

selftest() {
  local tmp rc=0
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN
  git -C "$tmp" init -q
  git -C "$tmp" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
  printf 'clean\n' > "$tmp/tracked.txt"
  git -C "$tmp" add tracked.txt
  git -C "$tmp" -c user.name=t -c user.email=t@example.invalid commit -q -m add

  # 情境 0：乾淨 ⇒ 0
  local h0; h0=$(scan_hits "$tmp" .)
  # 情境 1：已追蹤檔案新增一行假 token ⇒ ≥1
  printf 'x %s\n' "$(fake_token)" >> "$tmp/tracked.txt"
  local h1; h1=$(scan_hits "$tmp" tracked.txt)
  git -C "$tmp" checkout -q -- tracked.txt
  # 情境 2：未追蹤的新檔案含假 token ⇒ ≥1
  mkdir -p "$tmp/docs"; printf 'y %s\n' "$(fake_token)" > "$tmp/docs/new.md"
  local h2; h2=$(scan_hits "$tmp" docs)
  # 情境 3：路徑過濾有效——假 token 在 docs/，只掃 tracked.txt ⇒ 0
  local h3; h3=$(scan_hits "$tmp" tracked.txt)

  echo "selftest: clean=$h0 tracked_fake=$h1 untracked_fake=$h2 out_of_scope=$h3"
  if [ "$h0" -eq 0 ] && [ "$h1" -ge 1 ] && [ "$h2" -ge 1 ] && [ "$h3" -eq 0 ]; then
    echo SELFTEST_CAUGHT
  else
    echo "INVALID：量具自測失敗"; rc=3
  fi
  return $rc
}

if [ $# -eq 0 ]; then
  sed -n '3,6p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

if [ "$1" = "--selftest" ]; then
  selftest; exit $?
fi

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
FAMILY_SCRIPTS="$ROOT/../_JD2-family/scripts"
cd "$ROOT"

# 0. 量具自測（每次都跑；沒過就不往下）
if ! selftest >/dev/null; then echo "INVALID：量具自測失敗（regex 或 git 掃描路徑壞了）"; exit 3; fi

# 1. 機敏字串
hits=$(scan_hits "$ROOT" "$@")
echo "[1] 機敏掃描：命中 $hits（範圍：$*）"
if [ "$hits" -ne 0 ]; then echo "GATE_FAIL：機敏樣式命中，跑 git diff HEAD -- $* | grep -nE '<pattern>' 定位"; exit 1; fi

# 2. 版本同步
for s in check_doc_version_sync.sh check_trimix_boundary.sh; do
  [ -f "$FAMILY_SCRIPTS/$s" ] || { echo "INVALID：找不到 $FAMILY_SCRIPTS/$s"; exit 3; }
done
sync_out=$(bash "$FAMILY_SCRIPTS/check_doc_version_sync.sh" 2>&1 || true)
lb_rows=$(echo "$sync_out" | grep 'JD2-Logbook' || true)
if [ -z "$lb_rows" ]; then echo "INVALID：版本同步輸出沒有 JD2-Logbook 列（腳本輸出格式變了？）"; exit 3; fi
echo "[2] 版本同步（JD2-Logbook 列）："; echo "$lb_rows"
if echo "$lb_rows" | grep -q '❌'; then echo "GATE_FAIL：JD2-Logbook 版本同步有 ❌"; exit 1; fi

# 3. trimix 產品邊界
set +e
tri_out=$(bash "$FAMILY_SCRIPTS/check_trimix_boundary.sh" 2>&1); tri_rc=$?
set -e
echo "[3] trimix 邊界：rc=$tri_rc｜$(echo "$tri_out" | tail -1)"
if [ "$tri_rc" -ne 0 ]; then echo "GATE_FAIL：check_trimix_boundary.sh rc=$tri_rc"; exit 1; fi

echo GATE_OK
