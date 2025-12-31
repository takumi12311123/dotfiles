---
name: security-scan
description: |
  Perform comprehensive security analysis to identify vulnerabilities.
  Integrates with codex-review for automatic security checks.
  Covers OWASP Top 10, common vulnerabilities, and secure coding practices.
  Output: Japanese
trigger_keywords: security, セキュリティ, vulnerability, 脆弱性, OWASP
---

# Security Scan SKILL

## 🎯 Purpose

**セキュリティ脆弱性の検出**: Identify security vulnerabilities and ensure secure coding practices.
Automatically invoked during codex-review for security-sensitive code.

## 📋 When to Use

### Automatic Triggers (via codex-review)
- Authentication/Authorization code
- Database queries (SQL injection risk)
- User input handling (XSS/injection risk)
- File operations (path traversal risk)
- Cryptography usage
- API endpoints
- Session management

### Manual Invocation
- User explicitly requests security scan
- Before deploying security-critical features
- After dependency updates

## 🔐 Security Focus Areas

### 1. Input Validation
**Risks:**
- SQL Injection
- XSS (Cross-Site Scripting)
- Command Injection
- Path Traversal
- LDAP Injection
- XML/XXE Injection

**Checks:**
```javascript
// ❌ VULNERABLE
const query = `SELECT * FROM users WHERE id = ${userId}`;

// ✅ SECURE
const query = 'SELECT * FROM users WHERE id = ?';
db.query(query, [userId]);
```

### 2. Authentication & Authorization
**Risks:**
- Weak password policies
- Insecure session management
- Missing authentication
- Broken access control
- Privilege escalation

**Checks:**
```javascript
// ❌ VULNERABLE
if (user.role === 'admin') {
  // No verification of user identity
}

// ✅ SECURE
if (authenticatedUser.id === user.id && user.role === 'admin') {
  // Verify both identity and role
}
```

### 3. Data Protection
**Risks:**
- Sensitive data exposure
- Insecure cryptography
- Weak encryption
- Plaintext credentials
- Insufficient SSL/TLS

**Checks:**
```javascript
// ❌ VULNERABLE
const password = req.body.password; // Plaintext
localStorage.setItem('token', token); // Insecure storage

// ✅ SECURE
const hashedPassword = await bcrypt.hash(password, 10);
// Use httpOnly, secure cookies instead
```

### 4. Dependencies
**Risks:**
- Known vulnerabilities (CVEs)
- Outdated packages
- Supply chain attacks
- License compliance issues

**Checks:**
- npm audit / go mod verify / pip check
- Dependency version analysis
- Vulnerability database lookup

## 🔍 Security Scan Process

### Step 1: Identify Security-Sensitive Code

Scan for patterns:
```regex
- Database queries: (SELECT|INSERT|UPDATE|DELETE|query|exec)
- User input: (req\.body|params|query|input|form)
- Authentication: (auth|login|password|token|session)
- File operations: (readFile|writeFile|fs\.|path\.)
- Crypto: (crypto|encrypt|decrypt|hash|sign)
- Dangerous functions: (eval|exec|system|shell)
```

### Step 2: Vulnerability Detection

Check against OWASP Top 10:
1. **A01: Broken Access Control**
2. **A02: Cryptographic Failures**
3. **A03: Injection**
4. **A04: Insecure Design**
5. **A05: Security Misconfiguration**
6. **A06: Vulnerable and Outdated Components**
7. **A07: Identification and Authentication Failures**
8. **A08: Software and Data Integrity Failures**
9. **A09: Security Logging and Monitoring Failures**
10. **A10: Server-Side Request Forgery (SSRF)**

### Step 3: Risk Assessment

**Severity Levels:**
- **Critical**: Immediate exploitable vulnerability
- **High**: Significant security risk
- **Medium**: Potential security concern
- **Low**: Best practice violation
- **Info**: Security improvement opportunity

### Step 4: Generate Security Report

Output with remediation guidance.

## 📊 Output Format to User

```markdown
## セキュリティスキャン結果

### 概要
- **スキャンファイル**: 5ファイル
- **検出された問題**: 3件
  - Critical: 1件
  - High: 1件
  - Medium: 1件

### 🚨 Critical (即座に修正が必要)

#### 1. SQL Injection 脆弱性
- **ファイル**: `src/api/users.ts:45-48`
- **問題**: ユーザー入力を直接SQLクエリに埋め込んでいます
- **リスク**: データベース全体が侵害される可能性
- **OWASP**: A03:2021 - Injection

**脆弱なコード:**
```typescript
const query = `SELECT * FROM users WHERE email = '${email}'`;
db.query(query);
```

**修正案:**
```typescript
const query = 'SELECT * FROM users WHERE email = ?';
db.query(query, [email]);
// または ORMを使用
const user = await User.findOne({ where: { email } });
```

**影響**: 攻撃者が任意のSQLを実行可能
**修正優先度**: 最高

---

### ⚠️ High (早急に修正を推奨)

#### 2. 認証トークンの不適切な保存
- **ファイル**: `src/auth/session.ts:23`
- **問題**: JWTトークンがlocalStorageに保存されています
- **リスク**: XSS攻撃でトークンが盗まれる可能性
- **OWASP**: A07:2021 - Identification and Authentication Failures

**脆弱なコード:**
```typescript
localStorage.setItem('authToken', token);
```

**修正案:**
```typescript
// httpOnly, secure cookieを使用
res.cookie('authToken', token, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
  maxAge: 3600000
});
```

---

### 📋 Medium

#### 3. パスワードハッシュの不十分な強度
- **ファイル**: `src/auth/password.ts:12`
- **問題**: bcryptのsalt roundsが10未満
- **推奨**: 12以上のsalt roundsを使用

---

### ✅ セキュリティベストプラクティス

検出された良好な実装:
- ✅ CORS設定が適切に構成されています
- ✅ CSRFトークン検証が実装されています
- ✅ HTTPSが強制されています

---

### 📚 推奨される追加対策

1. **セキュリティヘッダーの追加**
```typescript
app.use(helmet({
  contentSecurityPolicy: true,
  hsts: true,
  noSniff: true
}));
```

2. **レート制限の実装**
```typescript
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});
app.use('/api/', limiter);
```

3. **入力バリデーションライブラリの使用**
```typescript
import { z } from 'zod';

const userSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});
```

---

### 🔗 参考リソース
- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)

これらの問題を修正してから進めますか?
```

## 🛡️ Language-Specific Checks

### JavaScript/TypeScript
```javascript
// Dangerous patterns
- eval() usage
- new Function() with user input
- innerHTML with unescaped data
- document.write()
- setTimeout/setInterval with string argument

// Security libraries
- helmet (security headers)
- express-rate-limit
- joi/zod (validation)
- bcrypt (password hashing)
```

### Go
```go
// Dangerous patterns
- SQL string concatenation
- exec.Command() with user input
- filepath.Join() without validation
- crypto/md5, crypto/sha1 (weak hashing)

// Security libraries
- golang.org/x/crypto/bcrypt
- github.com/go-playground/validator
- database/sql with prepared statements
```

### Python
```python
# Dangerous patterns
- eval(), exec() with user input
- pickle.loads() on untrusted data
- SQL string formatting
- os.system() with user input

# Security libraries
- bcrypt
- SQLAlchemy (ORM)
- bleach (XSS prevention)
- cryptography
```

## 🔗 Integration with codex-review

Security scan runs automatically during codex-review:

```
codex-review triggers security-scan when detecting:
├─ SQL queries → Check for injection
├─ User input handling → Check for XSS/injection
├─ Auth code → Check authentication/authorization
├─ File operations → Check path traversal
├─ Crypto usage → Check weak algorithms
└─ Dependencies → Check known vulnerabilities
```

**Security findings are included in codex-review output as blocking issues.**

## 🔧 Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| severity_threshold | medium | Minimum severity to report |
| include_dependencies | true | Check dependency vulnerabilities |
| owasp_checks | all | OWASP categories to check |
| auto_fix_suggestions | true | Provide code fix examples |

## ⚠️ Important Reminders

1. **Security is non-negotiable** - All Critical/High issues are blocking
2. **Output in Japanese** for user-facing text
3. **Provide specific code examples** for fixes
4. **Link to OWASP/CWE** for educational value
5. **Integrate with codex-review** for automatic scanning
6. **Check dependencies** for known CVEs
7. **Fail fast** - Don't allow insecure code to proceed

## 📝 Security Checklist

Before marking code as secure:
- [ ] All inputs validated and sanitized
- [ ] SQL queries use prepared statements/ORM
- [ ] Authentication/authorization properly implemented
- [ ] Sensitive data encrypted at rest and in transit
- [ ] Security headers configured
- [ ] Dependencies up to date and vulnerability-free
- [ ] Error messages don't leak sensitive information
- [ ] Logging doesn't include sensitive data
- [ ] Rate limiting implemented for APIs
- [ ] CSRF protection enabled
