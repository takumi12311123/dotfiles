---
name: frontend-design
description: Figmaデザインを本番環境対応のコードに変換し、1:1のビジュアル精度を実現します。フロントエンド実装、UIコンポーネント作成、Figma URLが提供された場合に自動的に使用されます。
metadata:
  context: frontend, ui, react, typescript, tailwind, figma
  auto-trigger: true
---

# Frontend Design Implementation

## 概要

このスキルは、Figmaデザインをピクセルパーフェクトな本番対応コードに変換するための構造化されたワークフローを提供します。デザインシステムとの一貫性、適切なコンポーネント再利用、アクセシビリティを確保します。

## 自動トリガー条件

以下の場合に自動的にこのスキルが適用されます:

- フロントエンド実装タスク
- UIコンポーネントの作成・修正
- Figma URLが提供された場合
- "デザイン実装"、"コンポーネント作成"などのキーワード
- TypeScript/React/Tailwind CSS関連のタスク

## ワークフロー

### 1. プロジェクト構造の確認

```bash
# 既存のコンポーネント構造を確認
src/
├── components/     # 再利用可能なUIコンポーネント
├── features/       # 機能別コンポーネント
├── hooks/          # カスタムフック
├── styles/         # グローバルスタイル
├── types/          # TypeScript型定義
└── utils/          # ユーティリティ関数
```

### 2. デザインシステムの確認

実装前に以下を確認:

- **既存のコンポーネント**: 再利用可能なコンポーネントを優先
- **デザイントークン**: カラー、スペーシング、タイポグラフィ
- **スタイルガイド**: 命名規則、構造パターン
- **状態管理**: 既存の状態管理パターン

### 3. コンポーネント設計原則

#### TypeScript型定義
```typescript
// Props型を明示的に定義
interface ComponentProps {
  // 必須プロパティ
  id: string;
  title: string;

  // オプショナルプロパティ
  description?: string;

  // イベントハンドラー
  onClick?: () => void;

  // スタイルのカスタマイズ
  className?: string;
}
```

#### コンポーネント構造
```typescript
// 関数コンポーネント + TypeScript
export const Component: React.FC<ComponentProps> = ({
  id,
  title,
  description,
  onClick,
  className
}) => {
  // カスタムフック
  const { state, handlers } = useComponentLogic();

  // 条件付きレンダリング
  if (!title) return null;

  return (
    <div className={cn('base-styles', className)}>
      {/* コンポーネント実装 */}
    </div>
  );
};
```

### 4. スタイリング戦略

#### Tailwind CSS優先
```typescript
// Tailwind クラスを使用
<div className="flex items-center gap-4 p-6 rounded-lg bg-white shadow-md">
  <h2 className="text-2xl font-bold text-gray-900">{title}</h2>
</div>
```

#### 条件付きスタイル
```typescript
import { cn } from '@/utils/cn';

<button
  className={cn(
    'px-4 py-2 rounded-md font-medium transition-colors',
    variant === 'primary' && 'bg-blue-600 text-white hover:bg-blue-700',
    variant === 'secondary' && 'bg-gray-200 text-gray-900 hover:bg-gray-300',
    disabled && 'opacity-50 cursor-not-allowed'
  )}
>
```

### 5. アクセシビリティ要件

必須事項:
- ✅ **セマンティックHTML**: `<button>`, `<nav>`, `<header>` など
- ✅ **ARIA属性**: `aria-label`, `aria-describedby`, `role`
- ✅ **キーボードナビゲーション**: Tab, Enter, Escapeサポート
- ✅ **フォーカス管理**: 適切なフォーカススタイル
- ✅ **カラーコントラスト**: WCAG AA準拠 (4.5:1以上)

```typescript
<button
  aria-label="メニューを開く"
  aria-expanded={isOpen}
  onClick={handleClick}
  onKeyDown={(e) => e.key === 'Enter' && handleClick()}
>
```

### 6. パフォーマンス最適化

```typescript
// 1. React.memo で不要な再レンダリング防止
export const MemoizedComponent = React.memo(Component);

// 2. useCallback でイベントハンドラーを最適化
const handleClick = useCallback(() => {
  // 処理
}, [dependencies]);

// 3. useMemo で計算コストの高い処理をキャッシュ
const expensiveValue = useMemo(
  () => computeExpensiveValue(data),
  [data]
);

// 4. 動的インポートでコード分割
const HeavyComponent = lazy(() => import('./HeavyComponent'));
```

### 7. テスト戦略

```typescript
import { render, screen, fireEvent } from '@testing-library/react';

describe('Component', () => {
  it('should render with correct props', () => {
    render(<Component title="Test" />);
    expect(screen.getByText('Test')).toBeInTheDocument();
  });

  it('should handle click events', () => {
    const onClick = jest.fn();
    render(<Component title="Test" onClick={onClick} />);

    fireEvent.click(screen.getByRole('button'));
    expect(onClick).toHaveBeenCalledTimes(1);
  });
});
```

### 8. 実装チェックリスト

実装前:
- [ ] 既存の類似コンポーネントを検索
- [ ] デザインシステムのトークンを確認
- [ ] 必要なアセット（画像、アイコン）を特定

実装中:
- [ ] TypeScript型定義を作成
- [ ] Tailwind CSSでスタイリング
- [ ] アクセシビリティ要件を満たす
- [ ] レスポンシブデザイン対応
- [ ] エラーハンドリング実装

実装後:
- [ ] ビジュアル確認（デザインと比較）
- [ ] ユニットテスト作成
- [ ] ストーリーブック追加（存在する場合）
- [ ] ドキュメント更新

## ベストプラクティス

### DO ✅
- 既存コンポーネントの再利用を優先
- デザインシステムのトークンを使用
- セマンティックHTMLを使用
- アクセシビリティを最初から考慮
- エッジケースのエラーハンドリング
- パフォーマンスを意識した実装

### DON'T ❌
- 新規コンポーネントを安易に作成しない
- ハードコードされた値を使用しない
- インラインスタイルを多用しない
- アクセシビリティを後回しにしない
- テストを書かない
- グローバルスタイルを汚染しない

## エラーハンドリング

```typescript
// エラーバウンダリー
class ErrorBoundary extends React.Component<Props, State> {
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Component error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return <ErrorFallback />;
    }
    return this.props.children;
  }
}

// ローディング・エラー状態
const Component = () => {
  const { data, isLoading, error } = useQuery();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!data) return null;

  return <ActualComponent data={data} />;
};
```

## Figma統合（オプション）

Figma MCP Serverが利用可能な場合:

1. デザインURLからノードIDを取得
2. デザイントークンを自動抽出
3. ビジュアルリファレンスをキャプチャ
4. アセットを自動ダウンロード
5. 実装後にビジュアル比較

## まとめ

このスキルは以下を保証します:

- 🎨 **デザインとの1:1精度**: ピクセルパーフェクト実装
- ♿ **アクセシビリティ**: WCAG準拠
- 🔄 **再利用性**: コンポーネント指向
- ⚡ **パフォーマンス**: 最適化された実装
- 🧪 **テスト可能性**: 保守しやすいコード
- 📚 **一貫性**: デザインシステムへの準拠
