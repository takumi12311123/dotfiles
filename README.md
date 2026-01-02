# dotfiles

macOS向けの開発環境設定ファイル一式。シェル、エディタ、ウィンドウマネージャ、AIツールの設定を管理。

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

# シンボリックリンクを作成
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
│   ├── gokurakujoudo/# Karabiner設定（EDN形式）
│   └── starship/     # プロンプトテーマ
├── .homebrew/        # Brewfile（パッケージ一覧）
├── .script/          # カスタムスクリプト
├── .zsh/             # Zsh設定（モジュール分割）
├── .skhdrc           # キーボードショートカット
├── .tmux.conf        # ターミナルマルチプレクサ
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

### ターミナル/エディタ

| ツール | 用途 |
|--------|------|
| [Alacritty](https://github.com/alacritty/alacritty) | ターミナルエミュレータ |
| [tmux](https://github.com/tmux/tmux) | ターミナルマルチプレクサ |
| [Neovim](https://github.com/neovim/neovim) | エディタ |

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

## カスタムコマンド/エイリアス

### Git操作（fzf連携）

- `ga` - インタラクティブなgit add（diffプレビュー付き）
- `gr` - インタラクティブなgit restore
- `gd` - インタラクティブなgit diff
- `gsp` - インタラクティブなgit stash pop
- `gss` - インタラクティブなgit stash save
- `gbd` - インタラクティブなブランチ削除

### ナビゲーション

- `cdd` - ghqで管理されたリポジトリへ移動
- `h` - 履歴検索
- `search` - コード検索してエディタで開く

### その他

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
