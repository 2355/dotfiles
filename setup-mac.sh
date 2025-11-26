#!/bin/bash
# My Mac settings

#----------------------------------------------------------
# Finder
#----------------------------------------------------------
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
# キーリピートの速度を最速にする
defaults write NSGlobalDomain KeyRepeat -int  1
# キーリピート開始までのタイミングを短くする
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# タップでクリックを有効にする
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad -bool true
# F1、F2 などのキーを標準のファンクションキーとして使用する
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

#----------------------------------------------------------
# Dock
#----------------------------------------------------------
# すべてのアプリアイコンを Dock から消去する
defaults write com.apple.dock persistent-apps -array
# Dock を自動的に隠す
defaults write com.apple.dock autohide -bool true
# Dock 表示の遅延時間を変更する
defaults write com.apple.dock autohide-delay -float 0.1

#----------------------------------------------------------
# Others
#----------------------------------------------------------
# ダークモードを有効にする
defaults write -g AppleInterfaceStyle -string "Dark"
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
