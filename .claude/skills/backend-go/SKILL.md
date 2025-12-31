---
name: backend-go
description: Goバックエンド開発のベストプラクティスに従い、クリーンアーキテクチャ、テスト駆動開発、保守性の高いコードを実現します。Goのバックエンド実装、API開発、マイクロサービス構築に自動適用されます。
metadata:
  context: go, backend, api, microservices, clean-architecture
  auto-trigger: true
---

# Backend Go Development

## 概要

このスキルは、Goバックエンド開発におけるベストプラクティスを提供します。クリーンアーキテクチャ、依存性注入、テスト駆動開発を重視し、スケーラブルで保守性の高いコードベースを構築します。

## 自動トリガー条件

以下の場合に自動的にこのスキルが適用されます:

- Goファイル (`.go`) の作成・編集
- バックエンドAPI開発
- マイクロサービス実装
- データベース操作
- "バックエンド実装"、"API作成"などのキーワード

## プロジェクト構造 (Clean Architecture)

```bash
project/
├── cmd/
│   └── api/                    # アプリケーションエントリーポイント
│       └── main.go
├── internal/                   # プライベートコード（外部からimport不可）
│   ├── domain/                 # ビジネスロジック層（最も内側）
│   │   ├── entity/            # エンティティ（ビジネスオブジェクト）
│   │   ├── repository/        # リポジトリインターフェース
│   │   └── service/           # ドメインサービス
│   ├── usecase/               # アプリケーションビジネスルール
│   │   └── user/
│   │       ├── create.go
│   │       └── get.go
│   ├── handler/               # プレゼンテーション層（外側）
│   │   ├── http/              # HTTPハンドラー
│   │   └── grpc/              # gRPCハンドラー
│   ├── repository/            # データアクセス層
│   │   ├── postgres/          # PostgreSQL実装
│   │   └── redis/             # Redis実装
│   └── infrastructure/        # 外部依存
│       ├── config/            # 設定管理
│       ├── database/          # DB接続
│       └── logger/            # ロガー
├── pkg/                       # パブリックライブラリ（外部から利用可能）
│   ├── validator/
│   ├── middleware/
│   └── errors/
├── test/                      # 統合テスト
│   ├── integration/
│   └── e2e/
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

## レイヤー設計原則

### 1. Domain Layer (内側)

```go
// internal/domain/entity/user.go
package entity

import (
    "time"
    "github.com/google/uuid"
)

// User エンティティ - ビジネスロジックのみ
type User struct {
    ID        uuid.UUID
    Email     string
    Name      string
    CreatedAt time.Time
    UpdatedAt time.Time
}

// Validate ドメインバリデーション
func (u *User) Validate() error {
    if u.Email == "" {
        return ErrInvalidEmail
    }
    if u.Name == "" {
        return ErrInvalidName
    }
    return nil
}

// internal/domain/repository/user.go
package repository

import (
    "context"
    "github.com/google/uuid"
    "yourproject/internal/domain/entity"
)

// UserRepository インターフェース定義（実装は外側のレイヤー）
type UserRepository interface {
    Create(ctx context.Context, user *entity.User) error
    GetByID(ctx context.Context, id uuid.UUID) (*entity.User, error)
    Update(ctx context.Context, user *entity.User) error
    Delete(ctx context.Context, id uuid.UUID) error
}
```

### 2. UseCase Layer (ビジネスルール)

```go
// internal/usecase/user/create.go
package user

import (
    "context"
    "github.com/google/uuid"
    "yourproject/internal/domain/entity"
    "yourproject/internal/domain/repository"
)

type CreateUserInput struct {
    Email string
    Name  string
}

type CreateUserUseCase struct {
    userRepo repository.UserRepository
}

func NewCreateUserUseCase(userRepo repository.UserRepository) *CreateUserUseCase {
    return &CreateUserUseCase{
        userRepo: userRepo,
    }
}

func (uc *CreateUserUseCase) Execute(ctx context.Context, input CreateUserInput) (*entity.User, error) {
    // 1. エンティティ作成
    user := &entity.User{
        ID:    uuid.New(),
        Email: input.Email,
        Name:  input.Name,
    }

    // 2. ドメインバリデーション
    if err := user.Validate(); err != nil {
        return nil, err
    }

    // 3. リポジトリを通じて永続化
    if err := uc.userRepo.Create(ctx, user); err != nil {
        return nil, err
    }

    return user, nil
}
```

### 3. Handler Layer (プレゼンテーション)

```go
// internal/handler/http/user.go
package http

import (
    "net/http"
    "github.com/gin-gonic/gin"
    "yourproject/internal/usecase/user"
)

type UserHandler struct {
    createUserUseCase *user.CreateUserUseCase
}

func NewUserHandler(createUserUseCase *user.CreateUserUseCase) *UserHandler {
    return &UserHandler{
        createUserUseCase: createUserUseCase,
    }
}

type CreateUserRequest struct {
    Email string `json:"email" binding:"required,email"`
    Name  string `json:"name" binding:"required,min=1"`
}

func (h *UserHandler) CreateUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    user, err := h.createUserUseCase.Execute(c.Request.Context(), user.CreateUserInput{
        Email: req.Email,
        Name:  req.Name,
    })
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusCreated, user)
}
```

### 4. Repository Layer (データアクセス)

```go
// internal/repository/postgres/user.go
package postgres

import (
    "context"
    "database/sql"
    "github.com/google/uuid"
    "yourproject/internal/domain/entity"
    "yourproject/internal/domain/repository"
)

type userRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) repository.UserRepository {
    return &userRepository{db: db}
}

func (r *userRepository) Create(ctx context.Context, user *entity.User) error {
    query := `
        INSERT INTO users (id, email, name, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5)
    `
    _, err := r.db.ExecContext(ctx, query,
        user.ID,
        user.Email,
        user.Name,
        user.CreatedAt,
        user.UpdatedAt,
    )
    return err
}

func (r *userRepository) GetByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
    query := `
        SELECT id, email, name, created_at, updated_at
        FROM users
        WHERE id = $1
    `
    var user entity.User
    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &user.ID,
        &user.Email,
        &user.Name,
        &user.CreatedAt,
        &user.UpdatedAt,
    )
    if err != nil {
        return nil, err
    }
    return &user, nil
}
```

## 依存性注入 (Dependency Injection)

```go
// cmd/api/main.go
package main

import (
    "database/sql"
    "log"

    "github.com/gin-gonic/gin"
    _ "github.com/lib/pq"

    "yourproject/internal/handler/http"
    "yourproject/internal/repository/postgres"
    "yourproject/internal/usecase/user"
)

func main() {
    // 1. インフラストラクチャ初期化
    db, err := sql.Open("postgres", "postgresql://...")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    // 2. リポジトリ層の構築
    userRepo := postgres.NewUserRepository(db)

    // 3. ユースケース層の構築
    createUserUseCase := user.NewCreateUserUseCase(userRepo)

    // 4. ハンドラー層の構築
    userHandler := http.NewUserHandler(createUserUseCase)

    // 5. ルーター設定
    r := gin.Default()
    r.POST("/users", userHandler.CreateUser)

    // 6. サーバー起動
    if err := r.Run(":8080"); err != nil {
        log.Fatal(err)
    }
}
```

## エラーハンドリング

```go
// pkg/errors/errors.go
package errors

import (
    "errors"
    "fmt"
)

type AppError struct {
    Code    string
    Message string
    Err     error
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %v", e.Message, e.Err)
    }
    return e.Message
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// 定義済みエラー
var (
    ErrNotFound      = &AppError{Code: "NOT_FOUND", Message: "resource not found"}
    ErrInvalidInput  = &AppError{Code: "INVALID_INPUT", Message: "invalid input"}
    ErrUnauthorized  = &AppError{Code: "UNAUTHORIZED", Message: "unauthorized"}
)

// エラーラッピング
func Wrap(err error, message string) error {
    return &AppError{
        Message: message,
        Err:     err,
    }
}
```

## テスト戦略

### ユニットテスト

```go
// internal/usecase/user/create_test.go
package user_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"

    "yourproject/internal/domain/entity"
    "yourproject/internal/usecase/user"
)

// モックリポジトリ
type MockUserRepository struct {
    mock.Mock
}

func (m *MockUserRepository) Create(ctx context.Context, user *entity.User) error {
    args := m.Called(ctx, user)
    return args.Error(0)
}

func TestCreateUserUseCase_Execute(t *testing.T) {
    // Arrange
    mockRepo := new(MockUserRepository)
    useCase := user.NewCreateUserUseCase(mockRepo)

    input := user.CreateUserInput{
        Email: "test@example.com",
        Name:  "Test User",
    }

    mockRepo.On("Create", mock.Anything, mock.AnythingOfType("*entity.User")).Return(nil)

    // Act
    result, err := useCase.Execute(context.Background(), input)

    // Assert
    assert.NoError(t, err)
    assert.NotNil(t, result)
    assert.Equal(t, input.Email, result.Email)
    mockRepo.AssertExpectations(t)
}
```

### テーブル駆動テスト

```go
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        user    *entity.User
        wantErr bool
    }{
        {
            name:    "valid user",
            user:    &entity.User{Email: "test@example.com", Name: "Test"},
            wantErr: false,
        },
        {
            name:    "empty email",
            user:    &entity.User{Email: "", Name: "Test"},
            wantErr: true,
        },
        {
            name:    "empty name",
            user:    &entity.User{Email: "test@example.com", Name: ""},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.user.Validate()
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

## パフォーマンス最適化

### 1. コンテキスト管理

```go
func (h *Handler) Handle(c *gin.Context) {
    // タイムアウト設定
    ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
    defer cancel()

    result, err := h.useCase.Execute(ctx)
    // ...
}
```

### 2. コネクションプーリング

```go
func NewDB(connStr string) (*sql.DB, error) {
    db, err := sql.Open("postgres", connStr)
    if err != nil {
        return nil, err
    }

    db.SetMaxOpenConns(25)                 // 最大オープン接続数
    db.SetMaxIdleConns(5)                  // 最大アイドル接続数
    db.SetConnMaxLifetime(5 * time.Minute) // 接続の最大生存時間

    return db, nil
}
```

### 3. Goroutineとチャネル

```go
func (s *Service) ProcessBatch(ctx context.Context, items []Item) error {
    errCh := make(chan error, len(items))
    sem := make(chan struct{}, 10) // 同時実行数制限

    for _, item := range items {
        sem <- struct{}{} // セマフォ取得

        go func(item Item) {
            defer func() { <-sem }() // セマフォ解放

            if err := s.processItem(ctx, item); err != nil {
                errCh <- err
            }
        }(item)
    }

    // 全ゴルーチン完了を待つ
    for i := 0; i < cap(sem); i++ {
        sem <- struct{}{}
    }
    close(errCh)

    // エラー集約
    for err := range errCh {
        if err != nil {
            return err
        }
    }

    return nil
}
```

## 実装チェックリスト

### 設計フェーズ
- [ ] クリーンアーキテクチャの各レイヤーを定義
- [ ] エンティティとビジネスルールを特定
- [ ] インターフェースを明確に定義
- [ ] 依存関係の方向を確認（内側→外側への依存禁止）

### 実装フェーズ
- [ ] Domain層: エンティティとリポジトリインターフェース
- [ ] UseCase層: ビジネスロジック実装
- [ ] Repository層: データアクセス実装
- [ ] Handler層: HTTPハンドラー実装
- [ ] エラーハンドリング実装
- [ ] ロギング追加

### テストフェーズ
- [ ] ユニットテスト作成（カバレッジ80%以上目標）
- [ ] モックを使った依存の分離
- [ ] テーブル駆動テスト適用
- [ ] 統合テスト作成

### 本番デプロイ前
- [ ] パフォーマンステスト実施
- [ ] セキュリティレビュー
- [ ] ドキュメント更新
- [ ] ログレベル確認

## ベストプラクティス

### DO ✅
- クリーンアーキテクチャに従う
- インターフェースを活用した疎結合設計
- テスト駆動開発（TDD）を実践
- エラーハンドリングを適切に行う
- コンテキストを活用したキャンセル処理
- 構造体のポインタレシーバーを使用

### DON'T ❌
- グローバル変数を使わない
- パニックを多用しない（エラーを返す）
- goroutineのリークを起こさない
- nilチェックを怠らない
- 巨大な関数を作らない（関数は小さく）
- 循環依存を作らない

## セキュリティ

```go
// 1. SQL Injection対策: プレースホルダー使用
query := "SELECT * FROM users WHERE id = $1"
db.QueryContext(ctx, query, userID)

// 2. パスワードハッシュ化
import "golang.org/x/crypto/bcrypt"

hashedPassword, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

// 3. レート制限
import "golang.org/x/time/rate"

limiter := rate.NewLimiter(rate.Limit(10), 100) // 10 req/sec, burst 100
if !limiter.Allow() {
    return ErrTooManyRequests
}
```

## まとめ

このスキルは以下を保証します:

- 🏗️ **クリーンアーキテクチャ**: レイヤー分離と依存性の逆転
- 🧪 **テスト可能性**: 高いカバレッジと保守性
- ⚡ **パフォーマンス**: 効率的な並行処理
- 🔒 **セキュリティ**: 安全なコード実装
- 📦 **スケーラビリティ**: マイクロサービス対応
- 📚 **保守性**: 読みやすく拡張しやすいコード
