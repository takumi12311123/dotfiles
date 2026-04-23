<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [dotfiles](#dotfiles)
  - [前提条件](#%E5%89%8D%E6%8F%90%E6%9D%A1%E4%BB%B6)
  - [クイックスタート](#%E3%82%AF%E3%82%A4%E3%83%83%E3%82%AF%E3%82%B9%E3%82%BF%E3%83%BC%E3%83%88)
  - [ディレクトリ構成](#%E3%83%87%E3%82%A3%E3%83%AC%E3%82%AF%E3%83%88%E3%83%AA%E6%A7%8B%E6%88%90)
  - [主要コンポーネント](#%E4%B8%BB%E8%A6%81%E3%82%B3%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%8D%E3%83%B3%E3%83%88)
    - [シェル環境](#%E3%82%B7%E3%82%A7%E3%83%AB%E7%92%B0%E5%A2%83)
    - [ターミナル](#%E3%82%BF%E3%83%BC%E3%83%9F%E3%83%8A%E3%83%AB)
    - [エディタ](#%E3%82%A8%E3%83%87%E3%82%A3%E3%82%BF)
    - [ウィンドウ管理](#%E3%82%A6%E3%82%A3%E3%83%B3%E3%83%89%E3%82%A6%E7%AE%A1%E7%90%86)
    - [キーボード](#%E3%82%AD%E3%83%BC%E3%83%9C%E3%83%BC%E3%83%89)
    - [AIツール](#ai%E3%83%84%E3%83%BC%E3%83%AB)
  - [開発ワークフロー](#%E9%96%8B%E7%99%BA%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BC)
  - [カスタムコマンド/エイリアス](#%E3%82%AB%E3%82%B9%E3%82%BF%E3%83%A0%E3%82%B3%E3%83%9E%E3%83%B3%E3%83%89%E3%82%A8%E3%82%A4%E3%83%AA%E3%82%A2%E3%82%B9)
    - [Git操作（fzf連携）](#git%E6%93%8D%E4%BD%9Cfzf%E9%80%A3%E6%90%BA)
    - [ナビゲーション](#%E3%83%8A%E3%83%93%E3%82%B2%E3%83%BC%E3%82%B7%E3%83%A7%E3%83%B3)
    - [その他](#%E3%81%9D%E3%81%AE%E4%BB%96)
  - [シークレット管理](#%E3%82%B7%E3%83%BC%E3%82%AF%E3%83%AC%E3%83%83%E3%83%88%E7%AE%A1%E7%90%86)
  - [Karabiner設定の更新](#karabiner%E8%A8%AD%E5%AE%9A%E3%81%AE%E6%9B%B4%E6%96%B0)
  - [トラブルシューティング](#%E3%83%88%E3%83%A9%E3%83%96%E3%83%AB%E3%82%B7%E3%83%A5%E3%83%BC%E3%83%86%E3%82%A3%E3%83%B3%E3%82%B0)
    - [setup.shが失敗する](#setupsh%E3%81%8C%E5%A4%B1%E6%95%97%E3%81%99%E3%82%8B)
    - [シンボリックリンクを再作成したい](#%E3%82%B7%E3%83%B3%E3%83%9C%E3%83%AA%E3%83%83%E3%82%AF%E3%83%AA%E3%83%B3%E3%82%AF%E3%82%92%E5%86%8D%E4%BD%9C%E6%88%90%E3%81%97%E3%81%9F%E3%81%84)
  - [ライセンス](#%E3%83%A9%E3%82%A4%E3%82%BB%E3%83%B3%E3%82%B9)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# dotfiles

macOS向けの開発環境設定ファイル一式。シェル、ターミナル（Ghostty）、ウィンドウマネージャ、AIツールの設定を管理。

## 前提条件

- macOS (Apple Silicon)
- Homebrew
- Git
- Zsh

## クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/takumi12311123/dotfiles.git
cd dotfiles

# Homebrewパッケージをインストール
brew bundle --file=.homebrew/Brewfile

# シンボリックリンクを作成（AIツールのセットアップも含む）
./setup.sh

# シークレットファイルを設定（テンプレートからコピー）
cp .zsh/secrets.zsh.template ~/.zsh/secrets.zsh
chmod 600 ~/.zsh/secrets.zsh
# ~/.zsh/secrets.zsh を編集して必要な値を設定
```

## ディレクトリ構成

```
.
├── .claude/          # Claude Code設定（skills, commands, plugins）
├── .codex/           # Codex CLI設定
├── .config/          # アプリケーション設定
│   ├── alacritty/    # ターミナルエミュレータ
│   ├── ghostty/      # ターミナルエミュレータ（メイン）
│   ├── gokurakujoudo/# Karabiner設定（EDN形式）
│   ├── karabiner/    # Karabiner-Elements設定
│   ├── prr/          # PRレビューツール設定
│   └── starship/     # プロンプトテーマ
├── .homebrew/        # Brewfile（パッケージ一覧）
├── .script/          # カスタムスクリプト
│   ├── dev.sh        # tmux開発環境（lazygit + Claude Code）
│   ├── ide.sh        # tmux IDE風レイアウト
│   └── review-pr.sh  # 複数AIでPRレビュー
├── .zsh/             # Zsh設定（モジュール分割）
├── .skhdrc           # キーボードショートカット
├── .tmux.conf        # tmux設定（レガシー）
├── .yabairc          # タイル型ウィンドウマネージャ
├── .zprofile         # ログインシェル環境変数
└── .zshrc            # Zshメイン設定
```

## 主要コンポーネント

### シェル環境

| ツール | 用途 |
|--------|------|
| [Zsh](https://github.com/zsh-users/zsh) | メインシェル |
| [Starship](https://github.com/starship/starship) | プロンプトテーマ |
| [Atuin](https://github.com/atuinsh/atuin) | シェル履歴管理 |
| [fzf](https://github.com/junegunn/fzf) | ファジーファインダー |

### ターミナル

| ツール | 用途 |
|--------|------|
| [Ghostty](https://ghostty.org) | ターミナルエミュレータ（メイン） |
| [Alacritty](https://github.com/alacritty/alacritty) | ターミナルエミュレータ |
| [tmux](https://github.com/tmux/tmux) | ターミナルマルチプレクサ |

### エディタ

| ツール | 用途 |
|--------|------|
| [Neovim](https://github.com/neovim/neovim) | エディタ |
| [Cursor](https://cursor.sh) | AIエディタ |
| [VS Code](https://code.visualstudio.com) | エディタ |

### ウィンドウ管理

| ツール | 用途 |
|--------|------|
| [yabai](https://github.com/koekeishiya/yabai) | タイル型ウィンドウマネージャ |
| [skhd](https://github.com/koekeishiya/skhd) | ホットキーデーモン |
| [SketchyBar](https://github.com/FelixKratz/SketchyBar) | カスタムメニューバー |

### キーボード

| ツール | 用途 |
|--------|------|
| [Karabiner-Elements](https://github.com/pqrs-org/Karabiner-Elements) | キーリマッピング |
| [GokuRakuJoudo](https://github.com/yqrashawn/GokuRakuJoudo) | Karabiner設定DSL |

### AIツール

| ツール | 用途 |
|--------|------|
| [Claude Code](https://claude.com/claude-code) | AIコーディングアシスタント |
| [Codex CLI](https://github.com/openai/codex) | OpenAI Codex CLI |
| [RTK](https://github.com/rtk-ai/rtk) | Claude Codeトークン最適化プロキシ |
| [difit](https://github.com/nicolo-ribaudo/difit) | Web UIのGit diffビューア（AIプロンプト生成） |
| [agent-browser](https://github.com/anthropics/agent-browser) | ヘッドレスブラウザ自動化 |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google Gemini CLI |

## 開発ワークフロー

メインのターミナル環境はGhostty + tmux。`dev` コマンドでlazygitとClaude Codeを左右分割で起動する。

```
+---------+------------------+
| lazygit |   claude code    |
|  (33%)  |      (67%)       |
+---------+------------------+
```

```bash
dev           # カレントディレクトリで起動
dev ~/project # 指定ディレクトリで起動
```

- `meh + return`（Ctrl+Option+Shift+Return）でGhosttyの表示/非表示を切り替え

## カスタムコマンド/エイリアス

### Git操作（fzf連携）

- `ga` - インタラクティブなgit add（diffプレビュー付き）
- `gr` - インタラクティブなgit restore
- `gd` - インタラクティブなgit diff
- `gsw` - インタラクティブなブランチ切り替え
- `gsp` - インタラクティブなgit stash pop
- `gss` - インタラクティブなgit stash save
- `gbd` - インタラクティブなブランチ削除

### ナビゲーション

- `cdd` - ghqで管理されたリポジトリへ移動
- `h` - 履歴検索
- `search` - コード検索してエディタで開く

### その他

- `dev` - tmuxでlazygit + Claude Code分割レイアウトを起動
- `ide` - tmuxでIDE風レイアウトを構築
- `review-pr` - 複数AIでPRレビュー

## シークレット管理

機密情報は`~/.zsh/secrets.zsh`に保存（gitignore済み）。

```bash
# テンプレートをコピーして権限を設定
cp .zsh/secrets.zsh.template ~/.zsh/secrets.zsh
chmod 600 ~/.zsh/secrets.zsh

# 必要な値を設定
vim ~/.zsh/secrets.zsh
```

## Karabiner設定の更新

```bash
# EDNファイルを編集後、Karabiner設定を生成
goku
```

## トラブルシューティング

### setup.shが失敗する

```bash
# 事前チェックを確認
which git
which brew

# 権限を確認
chmod +x setup.sh
```

### シンボリックリンクを再作成したい

```bash
# setup.shは既存リンクを自動検出して更新
./setup.sh
```

## ライセンス

MIT
