---
name: frontend-design
description: Translates Figma designs into production-ready code with 1:1 visual fidelity. Automatically applied for frontend implementation, UI component creation, and when Figma URLs are provided.
metadata:
  context: frontend, ui, react, typescript, tailwind, figma
  auto-trigger: true
---

# Frontend Design Implementation

## Overview

This skill provides a structured workflow for translating Figma designs into pixel-perfect production-ready code. It ensures consistency with design systems, proper component reuse, and accessibility compliance.

## Auto-Trigger Conditions

This skill is automatically applied when:

- Working on frontend implementation tasks
- Creating or modifying UI components
- Figma URLs are provided
- Keywords like "design implementation", "component creation" are mentioned
- Working with TypeScript/React/Tailwind CSS

## Workflow

### 1. Project Structure Verification

```bash
# Verify existing component structure
src/
├── components/     # Reusable UI components
├── features/       # Feature-specific components
├── hooks/          # Custom hooks
├── styles/         # Global styles
├── types/          # TypeScript type definitions
└── utils/          # Utility functions
```

### 2. Design System Check

Before implementation, verify:

- **Existing Components**: Prioritize reusable components
- **Design Tokens**: Colors, spacing, typography
- **Style Guide**: Naming conventions, structural patterns
- **State Management**: Existing state management patterns

### 3. Component Design Principles

#### TypeScript Type Definitions
```typescript
// Define Props types explicitly
interface ComponentProps {
  // Required properties
  id: string;
  title: string;

  // Optional properties
  description?: string;

  // Event handlers
  onClick?: () => void;

  // Style customization
  className?: string;
}
```

#### Component Structure
```typescript
// Function component + TypeScript
export const Component: React.FC<ComponentProps> = ({
  id,
  title,
  description,
  onClick,
  className
}) => {
  // Custom hooks
  const { state, handlers } = useComponentLogic();

  // Conditional rendering
  if (!title) return null;

  return (
    <div className={cn('base-styles', className)}>
      {/* Component implementation */}
    </div>
  );
};
```

### 4. Styling Strategy

#### Tailwind CSS First
```typescript
// Use Tailwind classes
<div className="flex items-center gap-4 p-6 rounded-lg bg-white shadow-md">
  <h2 className="text-2xl font-bold text-gray-900">{title}</h2>
</div>
```

#### Conditional Styles
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

### 5. Accessibility Requirements

Must-haves:
- ✅ **Semantic HTML**: `<button>`, `<nav>`, `<header>`, etc.
- ✅ **ARIA Attributes**: `aria-label`, `aria-describedby`, `role`
- ✅ **Keyboard Navigation**: Tab, Enter, Escape support
- ✅ **Focus Management**: Proper focus styles
- ✅ **Color Contrast**: WCAG AA compliance (4.5:1 minimum)

```typescript
<button
  aria-label="Open menu"
  aria-expanded={isOpen}
  onClick={handleClick}
  onKeyDown={(e) => e.key === 'Enter' && handleClick()}
>
```

### 6. Performance Optimization

```typescript
// 1. React.memo to prevent unnecessary re-renders
export const MemoizedComponent = React.memo(Component);

// 2. useCallback to optimize event handlers
const handleClick = useCallback(() => {
  // processing
}, [dependencies]);

// 3. useMemo to cache expensive computations
const expensiveValue = useMemo(
  () => computeExpensiveValue(data),
  [data]
);

// 4. Dynamic imports for code splitting
const HeavyComponent = lazy(() => import('./HeavyComponent'));
```

### 7. Testing Strategy

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

### 8. Implementation Checklist

Before implementation:
- [ ] Search for similar existing components
- [ ] Verify design system tokens
- [ ] Identify required assets (images, icons)

During implementation:
- [ ] Create TypeScript type definitions
- [ ] Style with Tailwind CSS
- [ ] Meet accessibility requirements
- [ ] Implement responsive design
- [ ] Add error handling

After implementation:
- [ ] Visual verification (compare with design)
- [ ] Write unit tests
- [ ] Add to Storybook (if exists)
- [ ] Update documentation

## Best Practices

### DO ✅
- Prioritize reusing existing components
- Use design system tokens
- Use semantic HTML
- Consider accessibility from the start
- Handle edge case errors
- Implement with performance in mind

### DON'T ❌
- Don't create new components carelessly
- Don't use hardcoded values
- Don't overuse inline styles
- Don't defer accessibility
- Don't skip writing tests
- Don't pollute global styles

## Error Handling

```typescript
// Error Boundary
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

// Loading & Error states
const Component = () => {
  const { data, isLoading, error } = useQuery();

  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!data) return null;

  return <ActualComponent data={data} />;
};
```

## Figma Integration (Optional)

When Figma MCP Server is available:

1. Extract node ID from design URL
2. Auto-extract design tokens
3. Capture visual reference
4. Auto-download assets
5. Visual comparison after implementation

## Summary

This skill ensures:

- 🎨 **1:1 Accuracy with Design**: Pixel-perfect implementation
- ♿ **Accessibility**: WCAG compliance
- 🔄 **Reusability**: Component-oriented approach
- ⚡ **Performance**: Optimized implementation
- 🧪 **Testability**: Maintainable code
- 📚 **Consistency**: Adherence to design system
