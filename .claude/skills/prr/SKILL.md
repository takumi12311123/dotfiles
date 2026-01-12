---
name: prr
description: |
  Terminal-based GitHub PR review tool. Review PRs without leaving the terminal using your favorite editor.
---

# prr - Pull Request Review Tool

## Overview

prr brings mailing-list style code reviews to GitHub PRs.
Write reviews in your editor, submit directly to GitHub.

## Basic Commands

### Get a PR for review
```bash
prr get owner/repo/PR_NUMBER

# Example
prr get takumi12311123/dotfiles/123
```

### Edit an existing review
```bash
prr edit owner/repo/PR_NUMBER
```

### Submit the review
```bash
prr submit owner/repo/PR_NUMBER
```

### Check review status
```bash
prr status
```

### Remove a review
```bash
prr remove owner/repo/PR_NUMBER
```

## Writing Reviews

### Basic Structure

After `prr get`, a `.prr` file opens in your editor.
Lines starting with `>` are the diff. Write comments between them.

```diff
> diff --git a/src/main.rs b/src/main.rs
> @@ -1,5 +1,6 @@
> +fn hello() {

Add your comment here

> +    println!("Hello");
> +}
```

### Review Type Directives

Add `@prr` directive at the top of the file:

```
@prr approve     # Approve the PR
@prr reject      # Request changes
@prr comment     # Comment only (default)
```

### Single Line Comment

```diff
> +fn hello() {

Please add documentation for this function

> +    println!("Hello");
> +}
```

### Multi-line (Spanned) Comment

Add a blank line to start the comment span:

```diff
> +fn hello() {

Comment about this entire function block

> +    println!("Hello");
> +}
```

### Suggestion (Code Proposal)

Same format as GitHub's Suggested changes:

```diff
> +fn hello() {

```suggestion
+fn greet(name: &str) {
+    println!("Hello, {}!", name);
+}
```

> +    println!("Hello");
> +}
```

### Multi-line Suggestion

```diff
> +fn process() {

Please refactor this

```suggestion
+fn process() -> Result<(), Error> {
+    validate()?;
+    execute()?;
+    Ok(())
+}
```

> +    validate();
> +    execute();
> +}
```

### Suggest Deletion

Use an empty suggestion block:

```diff
> +// TODO: remove this

This comment is unnecessary

```suggestion
```

> +fn main() {
```

## Configuration

`~/.config/prr/config.toml`:

```toml
[prr]
# Token is read from GH_TOKEN environment variable
workdir = "/Users/username/.local/share/prr"
```

## Local Configuration

Add `.prr.toml` in your repo to use PR number only:

```toml
[local]
repository = "owner/repo"
```

```bash
# Instead of owner/repo/123
prr get 123
```

## Workflow

```bash
# 1. Get PR (opens editor)
prr get owner/repo/42

# 2. Write review
#    - Add @prr approve/reject/comment at top
#    - Add comments between diff lines
#    - Use suggestion blocks for code proposals

# 3. Save and close editor

# 4. Submit review
prr submit owner/repo/42

# 5. Edit again if needed
prr edit owner/repo/42
prr submit owner/repo/42
```

## Tips

- `prr status` shows all review states
- `prr remove` deletes unwanted reviews
- Suggestions only work on `+` lines (added lines)
- Blank lines define spanned comment ranges
