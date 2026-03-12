---
name: codex-design
description: |
  Consult Codex for architectural decisions. Use when: (1) introducing patterns not in codebase, (2) 3+ design options exist, (3) performance-critical implementation, (4) major refactoring. Get risk assessment before coding.
---

# Codex Design Consultation

## Purpose

**Design-phase Codex consultation**: Consult with Codex before making complex design decisions.
Get expert validation, alternative approaches, and risk assessment early in the development process.

## When to Use

### Mandatory Triggers
- Introducing implementation patterns NOT found in existing codebase
- Architecture decision with 3+ viable options
- Performance-critical implementations (high-traffic endpoints, real-time processing, etc.)
- Major refactoring affecting multiple modules
- New technology/framework introduction
- Security-sensitive design (authentication, authorization, cryptography)

### Optional but Recommended
- Database schema design for new features
- API design for public/external consumption
- Distributed system component design
- Complex algorithm implementation

## Consultation Flow

### Step 1: Problem Analysis

Claude Code analyzes the design problem:
```
- Current situation and constraints
- Requirements (functional and non-functional)
- Existing codebase patterns
- Performance/security requirements
- Team expertise and maintenance considerations
```

### Step 2: Generate Design Options

Claude Code proposes 2-3 viable approaches:

```markdown
## Option 1: [Approach Name]
**Pros:**
- [Advantage 1]
- [Advantage 2]

**Cons:**
- [Drawback 1]
- [Drawback 2]

**Implementation Complexity:** Low/Medium/High
**Maintenance Cost:** Low/Medium/High
**Performance Impact:** Low/Medium/High

## Option 2: [Approach Name]
...

## Option 3: [Approach Name]
...
```

### Step 3: Codex Consultation

Execute Codex in read-only sandbox for design review:

```bash
codex exec --model gpt-5.4 --sandbox read-only "$(cat <<'EOF'
# Design Consultation Request

All string fields (reasoning, risks, recommendations, guidance) must be in Japanese.

## Context
[Project overview and current situation]

## Problem Statement
[Detailed description of the problem to solve]

## Constraints
- Performance: [Performance requirements]
- Security: [Security requirements]
- Scalability: [Scalability requirements]
- Maintainability: [Maintainability requirements]
- Team: [Team skillset]
- Timeline: [Schedule constraints]

## Proposed Design Options

### Option 1: [Approach name]
[Detailed description]

**Pros:**
- [Advantage 1]
- [Advantage 2]

**Cons:**
- [Drawback 1]
- [Drawback 2]

### Option 2: [Approach name]
[Detailed description]
...

### Option 3: [Approach name]
[Detailed description]
...

## Existing Codebase Patterns
[Patterns used in existing codebase]

## Questions for Codex

1. Validity assessment for each approach
2. Overlooked potential issues
3. Recommended approach and reasoning
4. Implementation considerations
5. Success/failure cases from similar projects

## Required Output Format (JSON, values in Japanese)

{
  "recommended_option": "Option 1|Option 2|Option 3|Alternative",
  "reasoning": "Detailed reasoning for recommendation (Japanese)",
  "risk_assessment": {
    "option_1": {
      "technical_risks": ["Risk 1", "Risk 2"],
      "mitigation": ["Mitigation 1", "Mitigation 2"]
    },
    "option_2": { ... },
    "option_3": { ... }
  },
  "additional_considerations": [
    {
      "category": "performance|security|maintainability|scalability",
      "point": "Consideration point (Japanese)",
      "importance": "critical|high|medium|low"
    }
  ],
  "alternative_approach": {
    "description": "Alternative approach description (if better than Options 1-3)",
    "why_better": "Why this is better"
  },
  "implementation_guidance": [
    "Implementation guidance 1",
    "Implementation guidance 2"
  ],
  "similar_patterns": [
    {
      "project": "Similar project name",
      "approach": "Adopted approach",
      "outcome": "Result (success/failure and reasons)"
    }
  ],
  "confidence": "high|medium|low",
  "caveats": ["Caveat 1", "Caveat 2"]
}
EOF
)"
```

### Step 4: Analysis and Synthesis

Claude Code analyzes Codex's response:
- Evaluate recommendation validity
- Consider project-specific context
- Synthesize with existing codebase patterns
- Identify any conflicting advice

### Step 5: Present to User

**All user-facing output must be in Japanese.**

Present comprehensive analysis to user for final decision:

```markdown
## Design Consultation Result: [Problem Title]

### Problem Summary
[Brief description of the problem]

### Proposed Design Options
1. **Option 1**: [Summary]
2. **Option 2**: [Summary]
3. **Option 3**: [Summary]

### Codex Recommendation
- **Recommended approach**: Option 2
- **Confidence**: High
- **Reasoning**:
  [Codex reasoning explained]

### Risk Assessment

#### Option 1: [Name]
- **Technical risks**:
  - [Risk 1]
  - [Risk 2]
- **Mitigations**:
  - [Mitigation 1]
  - [Mitigation 2]

#### Option 2: [Name] (recommended)
- **Technical risks**:
  - [Risk 1]
- **Mitigations**:
  - [Mitigation 1]

#### Option 3: [Name]
- **Technical risks**:
  - [Risk 1]
  - [Risk 2]
- **Mitigations**:
  - [Mitigation 1]

### Additional Considerations

#### Critical
- [Critical consideration 1]

#### High
- [High priority consideration 1]
- [High priority consideration 2]

#### Medium
- [Medium priority consideration 1]

### Alternative Approach (Codex proposal)
[Alternative proposed by Codex, if any]

**Why better**: [Reasoning]

### Implementation Guidance
1. [Implementation note 1]
2. [Implementation note 2]
3. [Implementation note 3]

### Similar Project Examples
- **Project**: [Name]
  - **Approach**: [Adopted method]
  - **Result**: [Success/failure reasons]

### Caveats
- [Caveat 1]
- [Caveat 2]

### Claude Code Observations
[Project-specific insights considering Codex recommendation]

Which approach should we proceed with? Or investigate further?
```

## Specific Use Cases

### Use Case 1: Database Schema Design

```markdown
## Problem
Database design for new multi-tenant feature

## Options
1. Single database with tenant_id column
2. Database per tenant
3. Schema per tenant (PostgreSQL)

[Codex consultation...]

## Codex Recommendation
Option 3 (Schema per tenant) for this scale
- Reasoning: Balance of isolation and management
- Risk: Schema migration complexity
- Mitigation: Use migration tool like Flyway
```

### Use Case 2: API Design Pattern

```markdown
## Problem
API design for new microservice communication

## Options
1. REST with JSON
2. gRPC
3. GraphQL

[Codex consultation...]

## Codex Recommendation
Option 2 (gRPC) for internal services
- Reasoning: Type safety, performance, streaming support
- Risk: Steeper learning curve
- Mitigation: Start with simple unary calls, add streaming later
```

### Use Case 3: State Management

```markdown
## Problem
State management for React application

## Options
1. Redux Toolkit
2. Zustand
3. Jotai

[Codex consultation...]

## Codex Recommendation
Option 2 (Zustand) for this project size
- Reasoning: Simplicity, less boilerplate, sufficient for current needs
- Risk: Might need migration if app grows significantly
- Mitigation: Keep state logic modular for easier migration
```

## Error Handling

### Codex Timeout
- Wait up to 10 minutes (10 polls)
- If timeout: Present options to user without Codex input
- Explain that consultation couldn't complete

### Codex API Failure
- Retry once after 5 seconds
- If retry fails: Proceed with Claude Code's analysis only
- Inform user that external validation unavailable

### Conflicting Recommendations
- If Codex recommendation contradicts project constraints
- Claude Code highlights the conflict
- Provides reasoning for both perspectives
- Lets user make informed decision

## Output Quality Indicators

### High Confidence Output
- Clear recommendation with strong reasoning
- Multiple supporting examples
- Specific implementation guidance
- Risk assessment with mitigations

### Low Confidence Output
- Multiple viable options with trade-offs
- Insufficient context for firm recommendation
- Suggests gathering more information
- Recommends prototyping or spike

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| timeout_minutes | 10 | Codex consultation timeout |
| min_options | 2 | Minimum design options to present |
| max_options | 4 | Maximum design options to present |
| require_risk_assessment | true | Require risk analysis for each option |
| include_examples | true | Include similar project examples |

## Success Criteria

Consultation is successful when:
- Codex provides clear recommendation
- All options have risk assessment
- Implementation guidance provided
- User has sufficient information to decide
- Potential pitfalls identified

## Best Practices

### Before Consultation
1. Clearly define the problem and constraints
2. Research existing patterns in codebase
3. Identify at least 2 viable options
4. Document non-functional requirements

### During Consultation
1. Wait for complete Codex response
2. Validate recommendations against project context
3. Identify any missed considerations
4. Synthesize with project-specific knowledge

### After Consultation
1. Document the decision and rationale
2. Update architecture documentation if needed
3. Share decision with team
4. Reference consultation in implementation

## Important Reminders

1. **Use early** - Consult before writing code, not after
2. **Be specific** - Provide detailed context and constraints
3. **Consider context** - Codex doesn't know your project specifics
4. **Final decision** - Human makes the final call, not AI
5. **Document** - Record the decision for future reference
6. **Output in Japanese** - All user-facing text in Japanese
