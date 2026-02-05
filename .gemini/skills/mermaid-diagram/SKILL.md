---
name: mermaid-diagram
description: Create accurate Mermaid diagrams with proper syntax, especially when using Japanese text. Use when creating flowcharts, sequence diagrams, class diagrams, ER diagrams, Gantt charts, or any other Mermaid visualization. Prevents common formatting errors with Japanese text by following strict syntax rules.
---

# Mermaid Diagram Creation

Create syntactically correct Mermaid diagrams, with special attention to Japanese text handling.

## Core Principles

1. **Always use double quotes for Japanese text** - Never use single quotes or backticks
2. **Avoid special characters in node IDs** - Use alphanumeric IDs only
3. **Escape quotes within labels** - Use `#quot;` or avoid nested quotes
4. **Validate arrow syntax** - Different diagram types use different arrow formats
5. **Test incrementally** - Build complex diagrams step by step

## Common Diagram Types

### Flowchart
```mermaid
flowchart TD
    A["開始"]
    B["処理1"]
    C{"判定"}
    D["処理2"]
    E["終了"]
    
    A --> B
    B --> C
    C -->|"はい"| D
    C -->|"いいえ"| E
    D --> E
```

**Key points:**
- Use `flowchart TD` (top-down) or `flowchart LR` (left-right)
- Node IDs: Simple alphanumerics (A, B, C, node1, etc.)
- Labels: Always in double quotes `["ラベル"]`
- Link labels: Use `|"ラベル"| ` format

### Sequence Diagram
```mermaid
sequenceDiagram
    participant U as ユーザー
    participant S as システム
    participant D as データベース
    
    U->>S: リクエスト送信
    activate S
    S->>D: データ問い合わせ
    activate D
    D-->>S: データ返却
    deactivate D
    S-->>U: レスポンス返却
    deactivate S
```

**Key points:**
- Use `participant X as "日本語名"` format
- Arrow types: `->`, `->>`, `-->`, `-->>`, `-x`, `--x`
- Activate/deactivate for lifelines
- Notes: `Note over X: "テキスト"` or `Note left/right of X: "テキスト"`

### Class Diagram
```mermaid
classDiagram
    class User {
        +String name
        +String email
        +login()
        +logout()
    }
    
    class Order {
        +int id
        +Date date
        +calculate()
    }
    
    User "1" --> "*" Order : "注文する"
```

**Key points:**
- Use English for class/method names (best practice)
- Japanese only in relationship labels with double quotes
- Visibility: `+` public, `-` private, `#` protected
- Relationships: `<|--` inheritance, `*--` composition, `o--` aggregation, `-->` association

### Entity Relationship Diagram
```mermaid
erDiagram
    USER ||--o{ ORDER : "注文する"
    ORDER ||--|{ ORDER_ITEM : "含む"
    PRODUCT ||--o{ ORDER_ITEM : "含まれる"
    
    USER {
        int id PK
        string name
        string email
    }
    
    ORDER {
        int id PK
        int user_id FK
        date order_date
    }
```

**Key points:**
- Relationship syntax: `||--o{` (one-to-many), `||--||` (one-to-one), `}o--o{` (many-to-many)
- Japanese in relationship labels only
- Field format: `type name constraints`

### Gantt Chart
```mermaid
gantt
    title プロジェクトスケジュール
    dateFormat YYYY-MM-DD
    
    section フェーズ1
    要件定義       :a1, 2024-01-01, 30d
    設計          :a2, after a1, 20d
    
    section フェーズ2
    開発          :b1, after a2, 60d
    テスト        :b2, after b1, 30d
```

**Key points:**
- Section names can be Japanese
- Task names can be Japanese
- Date format must match `dateFormat` declaration

## Critical Rules for Japanese Text

### ✅ CORRECT
```mermaid
flowchart TD
    A["ユーザー登録"]
    B["メール送信"]
    A --> B
```

### ❌ WRONG - Will cause errors
```mermaid
flowchart TD
    A['ユーザー登録']  ❌ Single quotes
    B[`メール送信`]    ❌ Backticks
    A -> B             ❌ Wrong arrow for flowchart
```

## Error Prevention Checklist

Before finalizing a diagram:

1. ✓ All Japanese text in double quotes `""`
2. ✓ Node IDs are simple (A, B, node1, etc.)
3. ✓ Correct arrow syntax for diagram type
4. ✓ No unescaped special characters in labels
5. ✓ Proper indentation (spaces, not tabs)
6. ✓ Diagram type declaration is correct

## Complex Example: Full System Flow

```mermaid
flowchart TD
    Start["開始"]
    Input["ユーザー入力"]
    Validate{"入力検証"}
    Process["データ処理"]
    Save["DB保存"]
    Success["成功メッセージ"]
    Error["エラー表示"]
    End["終了"]
    
    Start --> Input
    Input --> Validate
    Validate -->|"有効"| Process
    Validate -->|"無効"| Error
    Process --> Save
    Save -->|"成功"| Success
    Save -->|"失敗"| Error
    Success --> End
    Error --> End
```

## Best Practices

1. **Start simple**: Create basic structure first, then add Japanese labels
2. **Use English IDs**: Keep node IDs in English, use Japanese only in display labels
3. **Test incrementally**: Add one node/connection at a time when debugging
4. **Consistent spacing**: Use consistent indentation (4 spaces recommended)
5. **Comment complex parts**: Use `%%` for comments to explain complex logic

## Workflow

1. Determine diagram type based on use case
2. Create basic structure with English IDs
3. Add Japanese labels in double quotes
4. Verify arrow syntax matches diagram type
5. Test the diagram
6. Refine and add details

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Syntax error with Japanese | Single quotes or backticks | Use double quotes `["テキスト"]` |
| Invalid node ID | Special characters in ID | Use alphanumeric IDs only |
| Wrong arrow type | Incorrect syntax for diagram | Check diagram-specific arrow format |
| Unmatched quotes | Quote inside quoted text | Use `#quot;` or restructure |
| Indentation error | Mixed tabs/spaces | Use spaces consistently |

**For detailed error patterns and solutions**: See `references/error_patterns.md` for 12 common error patterns with Japanese text and their fixes.

**For advanced features**: See `references/advanced_syntax.md` for subgraphs, styling, state diagrams, and other advanced diagram types.
