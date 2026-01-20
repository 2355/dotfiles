#!/bin/zsh

# このリポジトリを ~/work/dotfiles/ にクローンしてから実行してください。
# run `zsh setup-mac.sh`

# エラーが出たら即終了
set -e

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
# シンボリックリンクの作成
#----------------------------------------------------------
echo "Creating symbolic links for dotfiles..."
ln -fnsv ~/work/dotfiles/.gitconfig ~/.gitconfig
mkdir -p ~/.config/git
ln -fnsv ~/work/dotfiles/.config/git/ignore ~/.config/git/ignore
ln -fnsv ~/work/dotfiles/.vimrc ~/.vimrc
ln -fnsv ~/work/dotfiles/.zshrc ~/.zshrc
source ~/.zshrc
mkdir -p ~/.claude
ln -fnsv ~/work/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -fnsv ~/work/dotfiles/.claude/settings.json ~/.claude/settings.json
ln -sfn ~/work/dotfiles/.claude/commands ~/.claude/commands

echo "✅ setup complete!"

#----------------------------------------------------------
# その他手動対応
#----------------------------------------------------------
# キーボード > キーボードショートカット > Spotlight > Spotlight検索を表示 : OFF
# キーボード > キーボードショートカット > 修飾キー > Caps Lock : Command
# コントロールセンター > バッテリー > 割合(%)を表示 : ON
# コントロールセンター > 時計 > 時計のオプション > 時刻 > スタイル : アナログ
# コントロールセンター > Bluetooth : メニューバーに表示
# コントロールセンター > Spotlight : メニューバーに非表示
# コントロールセンター > Siri : メニューバーに非表示

# Itsycal の設定
# Appearance > Menubar で「M/d E HH:mm:ss」、「Hide icon」を ON

# iterm の設定の import
# https://zenn.dev/ripopo23/articles/2d1baf1a97e136

# Raycast の設定の import
# Settings > Advanced > Import / Export
# https://phys-edu.net/wp/?p=42570

# Google 日本語入力の設定
# スペースや数字を半角入力する
# ¥ キーで \ を入力する

# ssh キーの作成、GitHubへの登録
# nodenv で Node.js のインストール
