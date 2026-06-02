#!/bin/zsh

# このリポジトリを ~/work/dotfiles/ にクローンしてから実行してください。
# run `zsh setup-mac.sh`

# エラーが出たら即終了
set -e

#----------------------------------------------------------
# sudo セッションの維持
#----------------------------------------------------------
# brew bundle 中の cask インストールで sudo を繰り返し求められないように、
# 最初に認証してバックグラウンドでタイムスタンプを更新し続ける
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

#----------------------------------------------------------
# Finder
#----------------------------------------------------------
echo "Setting Finder..."
# 全ての拡張子のファイルを表示する
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# デフォルトで隠しファイルを表示する
defaults write com.apple.finder AppleShowAllFiles -bool true
# 名前順でソートするときにフォルダを常に上部に表示
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# 下部にパスバーを表示する
defaults write com.apple.finder ShowPathbar -bool true

#----------------------------------------------------------
# Keyboard
#----------------------------------------------------------
echo "Setting Keyboard..."
# キーリピートの速度を最速にする
defaults write NSGlobalDomain KeyRepeat -int  1
# キーリピート開始までのタイミングを短くする
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# トラックパッドをタップでクリックを有効にする
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
# F1、F2 などのキーを標準のファンクションキーとして使用する
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
# すべての入力ソースでライブ変換をオフにする（日本語向け）
defaults write com.apple.inputmethod.Kotoeri JIMLiveConversionEnabled -bool false

#----------------------------------------------------------
# Dock
#----------------------------------------------------------
echo "Setting Dock..."
# すべてのアプリアイコンを Dock から消去する
defaults write com.apple.dock persistent-apps -array
# Dock を自動的に隠す
defaults write com.apple.dock autohide -bool true
# Dock 表示の遅延時間を変更する（意味ないかも）
defaults write com.apple.dock autohide-delay -float 0.1

#----------------------------------------------------------
# Others
#----------------------------------------------------------
echo "Setting Others..."
# ダークモードを有効にする（意味ないかも）
defaults write -g AppleInterfaceStyle -string "Dark"
# スクリーンショットの保存先をダウンロードフォルダに変更する
defaults write com.apple.screencapture location ~/Downloads
# 保存ダイアログを常に展開状態で表示
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

#----------------------------------------------------------
# 設定の反映
#----------------------------------------------------------
echo "Applying settings..."
# Finder 設定を反映
killall Finder
# Dock 設定を反映
killall Dock
# その他設定を反映
killall SystemUIServer

#----------------------------------------------------------
# Xcode Command Line Tools のインストール
#----------------------------------------------------------
if ! xcode-select --print-path &> /dev/null; then
  # Install command line tools
  echo "Command line tools not found. Installing..."
  xcode-select --install
else
  echo "Command line tools are already installed."
fi

#----------------------------------------------------------
# Homebrew のインストール
#----------------------------------------------------------
# Homebrew のパスを即時反映
eval "$(/opt/homebrew/bin/brew shellenv)"
if ! (type "brew" >/dev/null 2>&1); then
  echo "Installing Homebrew ..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/${USER}/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew is already installed."
fi

#----------------------------------------------------------
# brew 管理のアプリをインストール
#----------------------------------------------------------
echo "Installing applications via Homebrew..."
brew bundle install --file=.Brewfile

#----------------------------------------------------------
# zsh compinit の insecure directory 警告を解消
#----------------------------------------------------------
# Homebrew が作るディレクトリの一部に group-write が付いており、
# compinit が起動時に「insecure directories」警告を出すため、compaudit で
# 検出した該当ディレクトリの group-write を一括で外す
echo "Fixing insecure zsh completion directories..."
insecure_dirs="$(zsh -c 'autoload -Uz compaudit; compaudit' 2>/dev/null || true)"
if [ -n "${insecure_dirs}" ]; then
  echo "${insecure_dirs}" | xargs chmod g-w
fi

#----------------------------------------------------------
# シンボリックリンクの作成
#----------------------------------------------------------
echo "Creating symbolic links for dotfiles..."
ln -fnsv ~/work/dotfiles/.gitconfig ~/.gitconfig
mkdir -p ~/.config/git
ln -fnsv ~/work/dotfiles/.config/git/ignore ~/.config/git/ignore
mkdir -p ~/.config/yazi
ln -fnsv ~/work/dotfiles/.config/yazi/yazi.toml ~/.config/yazi/yazi.toml
ln -fnsv ~/work/dotfiles/.vimrc ~/.vimrc
ln -fnsv ~/work/dotfiles/.zshrc ~/.zshrc
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ln -fnsv ~/work/dotfiles/.ssh/config ~/.ssh/config
source ~/.zshrc
mkdir -p ~/.claude
ln -fnsv ~/work/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -fnsv ~/work/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -fnsv ~/work/dotfiles/.claude/statusline-command.sh ~/.claude/statusline-command.sh
ln -sfn ~/work/dotfiles/.claude/agents ~/.claude/agents
ln -sfn ~/work/dotfiles/.claude/commands ~/.claude/commands
ln -sfn ~/work/dotfiles/.claude/skills ~/.claude/skills

#----------------------------------------------------------
# Claude Code MCP サーバーの登録
#----------------------------------------------------------
# claude mcp add は重複登録できないため、未登録のもののみ追加する
echo "Registering Claude Code MCP servers..."
mcp_list="$(claude mcp list 2>/dev/null || true)"
mcp_add_if_missing() {
  local name="$1"; shift
  if printf '%s\n' "${mcp_list}" | grep -q "^${name}:"; then
    echo "MCP server '${name}' is already registered."
  else
    claude mcp add --scope user "$@"
  fi
}
mcp_add_if_missing serena serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --enable-web-dashboard false

#----------------------------------------------------------
# Node.js のセットアップ (nodenv 経由)
#----------------------------------------------------------
echo "Setting up Node.js via nodenv..."
# anyenv-update: anyenv update で **env / プラグインを一括更新できるようにする
if [ ! -d "$(anyenv root)/plugins/anyenv-update" ]; then
  git clone https://github.com/znz/anyenv-update.git "$(anyenv root)/plugins/anyenv-update"
fi
# anyenv install マニフェストの初期化（初回のみ）
if [ ! -d ~/.config/anyenv/anyenv-install ]; then
  printf 'y\n' | anyenv install --init
fi
# nodenv のインストール
if [ ! -d "$(anyenv root)/envs/nodenv" ]; then
  anyenv install nodenv
  eval "$(anyenv init -)"
fi
# nodenv-package-json-engine: package.json の engines.node から自動でバージョン解決
if [ ! -d "$(nodenv root)/plugins/nodenv-package-json-engine" ]; then
  git clone https://github.com/nodenv/nodenv-package-json-engine.git "$(nodenv root)/plugins/nodenv-package-json-engine"
fi
# 最新 LTS を取得して install / global を設定
NODE_LTS="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version' | sed 's/^v//')"
if ! nodenv versions --bare | grep -qx "${NODE_LTS}"; then
  nodenv install "${NODE_LTS}"
fi
nodenv global "${NODE_LTS}"
nodenv rehash
source ~/.zshrc
node -v
# Node 同梱の corepack を有効化（pnpm / yarn の shim を生成）
corepack enable

echo "✅ setup complete!"

#----------------------------------------------------------
# その他手動対応
#----------------------------------------------------------
# キーボード > キーボードショートカット > Spotlight > Spotlight検索を表示 : OFF
# キーボード > キーボードショートカット > 修飾キー > Caps Lock : Command
# メニューバー > バッテリー > 割合(%)を表示 : ON
# メニューバー > 時計 > 時計のオプション > 時刻 > スタイル : アナログ
# メニューバー > Bluetooth : メニューバーに表示
# メニューバー > Spotlight : メニューバーに非表示
# メニューバー > Siri : メニューバーに非表示

# Raycast の設定の import
# Settings > Advanced > Import / Export
# https://phys-edu.net/wp/?p=42570


# iterm の設定の import
# https://zenn.dev/ripopo23/articles/2d1baf1a97e136

# Itsycal の設定
# Appearance > Menubar で「M/d E HH:mm:ss」、「Hide icon」を ON

# Google 日本語入力の設定
# スペースや数字を半角入力する
# ¥ キーで \ を入力する

# ssh キーの作成、GitHubへの登録
