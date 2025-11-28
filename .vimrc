" 表示設定
set number " 行番号を表示
set laststatus=2 " ステータスバー表示

" 操作設定
set virtualedit=onemore " 行末の1文字先までカーソルを移動できるように
set backspace=2 " backspaceの有効化

" インデント設定
set smartindent
set noautoindent

" タブキー設定
set smarttab
set expandtab

" 検索設定
set hlsearch " ハイライト
set ignorecase "大文字/小文字の区別なく検索する
set smartcase "検索文字列に大文字が含まれている場合は区別して検索する

" シンタックスハイライト
filetype on
syntax on
"colorscheme molokai
set t_Co=256
