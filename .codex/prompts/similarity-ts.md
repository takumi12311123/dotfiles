---
allowed-tools: Bash(similarity-ts:*)
description: Analyze code similarity and detect duplicates using similarity-ts
argument-hint: [scan-type] - basic | detailed | cross-file | comprehensive | react | large-functions
---

## Project Context

- Project structure: !`find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | head -10`
- Source directory: !`if [ -d "./src" ]; then echo "src/ directory found"; else echo "No src/ directory"; fi`

## Similarity Analysis Options

### Available Scan Types:

**basic** - Quick similarity scan of current directory

```bash
similarity-ts .
```

**detailed** - Analysis with code display

```bash
similarity-ts . --print
```

**cross-file** - Detect duplicates across different files

```bash
similarity-ts . --cross-file --print --threshold 0.85
```

**comprehensive** - Full analysis with custom thresholds

```bash
similarity-ts ./src --threshold 0.8 --min-lines 10 --cross-file --print
```

**react** - Optimized for TypeScript/React projects

```bash
similarity-ts ./src --extensions ts,tsx --cross-file --threshold 0.85 --print
```

**large-functions** - Focus on large function similarities

```bash
similarity-ts ./src --min-lines 20 --threshold 0.8 --print
```

## Your Task

Run similarity analysis using the specified scan type.

If no scan type specified, run a **comprehensive** analysis.

### Analysis Parameters:

- **Threshold**: 0.8-0.85 (80-85% similarity to flag)
- **Min Lines**: 10+ lines for meaningful duplicates
- **Extensions**: Focus on relevant file types
- **Cross-file**: Enable for better duplicate detection

After running the analysis, provide:

1. Summary of findings
2. Most significant duplicates identified
3. Recommendations for refactoring opportunities
