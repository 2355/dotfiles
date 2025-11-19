#!/bin/bash
# My Mac settings

#----------------------------------------------------------
# Finder
#----------------------------------------------------------
# 全ての拡張子のファイルを表示する
defaults write NSGlobalDomain AppleShowAllExtensions 1
# デフォルトで隠しファイルを表示する
defaults write com.apple.finder AppleShowAllFiles 1
# 名前順でソートするときにフォルダを常に上部に表示
defaults write com.apple.finder _FXSortFoldersFirst 1
# 下部にパスバーを表示する
defaults write com.apple.finder ShowPathbar 1

#----------------------------------------------------------
# Keyboard
#----------------------------------------------------------
# キーリピートの速度を最速にする
defaults write NSGlobalDomain KeyRepeat 1
# キーリピート開始までのタイミングを短くする
defaults write NSGlobalDomain InitialKeyRepeat 15
# タップでクリックを有効にする
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking 1

#----------------------------------------------------------
# Dock
#----------------------------------------------------------
# すべてのアプリアイコンを Dock から消去する
defaults write com.apple.dock persistent-apps -array
# Dock を自動的に隠す
defaults write com.apple.dock autohide 1
# Dock 表示の遅延時間を変更する
defaults write com.apple.dock autohide-delay -float 0.1

#----------------------------------------------------------
# Others
#----------------------------------------------------------
# スクリーンショットの保存先をダウンロードフォルダに変更する
defaults write com.apple.screencapture location ~/Downloads

#----------------------------------------------------------
# 設定の反映
#----------------------------------------------------------
# Finder 設定を反映
killall Finder
# Dock 設定を反映
killall Dock
# その他設定を反映
killall SystemUIServer
