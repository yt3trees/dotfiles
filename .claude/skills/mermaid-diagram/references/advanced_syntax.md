# Mermaid Advanced Syntax Reference

This reference contains detailed syntax for advanced Mermaid diagram features.

## Advanced Flowchart Features

### Subgraphs
```mermaid
flowchart TD
    subgraph sub1["サブグラフ1"]
        A["処理A"]
        B["処理B"]
    end
    
    subgraph sub2["サブグラフ2"]
        C["処理C"]
        D["処理D"]
    end
    
    A --> B
    B --> C
    C --> D
```

### Node Shapes
- `["テキスト"]` - Rectangle (default)
- `("テキスト")` - Rounded rectangle
- `(["テキスト"])` - Stadium shape
- `[["テキスト"]]` - Subroutine
- `[("テキスト")]` - Cylindrical shape (database)
- `{{"テキスト"}}` - Hexagon
- `{{"テキスト"}}` - Rhombus (decision)
- `>"テキスト"]` - Flag
- `(("テキスト"))` - Circle
- `((("テキスト")))` - Double circle

### Styling
```mermaid
flowchart TD
    A["ノード"]
    B["強調ノード"]
    
    classDef highlight fill:#f9f,stroke:#333,stroke-width:4px
    class B highlight
```

## Advanced Sequence Diagram Features

### Loops and Alternatives
```mermaid
sequenceDiagram
    participant U as ユーザー
    participant S as システム
    
    U->>S: ログイン
    
    alt 認証成功
        S-->>U: ホーム画面
    else 認証失敗
        S-->>U: エラーメッセージ
    end
    
    loop 毎日
        U->>S: データ同期
        S-->>U: 完了通知
    end
```

### Background Highlighting
```mermaid
sequenceDiagram
    participant A as システムA
    participant B as システムB
    
    rect rgb(200, 220, 250)
        note right of A: 重要な処理
        A->>B: リクエスト
        B-->>A: レスポンス
    end
```

## State Diagrams

```mermaid
stateDiagram-v2
    [*] --> 待機中
    待機中 --> 処理中 : 開始
    処理中 --> 完了 : 成功
    処理中 --> エラー : 失敗
    完了 --> [*]
    エラー --> 待機中 : リトライ
```

### Composite States
```mermaid
stateDiagram-v2
    [*] --> アクティブ
    
    state アクティブ {
        [*] --> 実行中
        実行中 --> 一時停止
        一時停止 --> 実行中
    }
    
    アクティブ --> [*]
```

## Git Graphs

```mermaid
gitGraph
    commit id: "初期コミット"
    commit id: "機能追加"
    branch develop
    checkout develop
    commit id: "開発開始"
    commit id: "機能実装"
    checkout main
    merge develop tag: "v1.0"
    commit id: "リリース"
```

## Pie Charts

```mermaid
pie title プロジェクト工数配分
    "設計" : 30
    "開発" : 45
    "テスト" : 15
    "ドキュメント" : 10
```

## Requirement Diagrams

```mermaid
requirementDiagram
    requirement 機能要件1 {
        id: REQ-001
        text: ユーザー認証機能
        risk: high
        verifymethod: test
    }
    
    functionalRequirement 技術要件1 {
        id: FREQ-001
        text: OAuth2.0対応
        risk: medium
        verifymethod: inspection
    }
    
    機能要件1 - contains -> 技術要件1
```

## C4 Diagrams (Context)

```mermaid
C4Context
    title システムコンテキスト図
    
    Person(user, "ユーザー", "一般ユーザー")
    System(system, "メインシステム", "業務システム")
    System_Ext(external, "外部API", "サードパーティAPI")
    
    Rel(user, system, "使用する")
    Rel(system, external, "データ取得", "HTTPS")
```

## Timeline Diagrams

```mermaid
timeline
    title プロジェクトマイルストーン
    section 2024年1月
        要件定義完了 : キックオフ
                    : 要件確定
    section 2024年2月
        設計完了 : 基本設計
                : 詳細設計
    section 2024年3月
        開発完了 : コーディング
                : ユニットテスト
```

## Mind Maps

```mermaid
mindmap
  root((プロジェクト))
    フェーズ1
      要件定義
      設計
    フェーズ2
      開発
      テスト
    リソース
      人員
      予算
```

## Quadrant Charts

```mermaid
quadrantChart
    title 優先度マトリクス
    x-axis 低労力 --> 高労力
    y-axis 低価値 --> 高価値
    quadrant-1 後回し
    quadrant-2 優先実施
    quadrant-3 不要
    quadrant-4 効率化検討
    
    機能A: [0.3, 0.8]
    機能B: [0.7, 0.7]
    機能C: [0.2, 0.3]
```

## Styling Tips

### Theme Configuration
```mermaid
%%{init: {'theme':'dark'}}%%
flowchart TD
    A["ダークテーマ"]
```

Available themes: `default`, `dark`, `forest`, `neutral`

### Custom Styles
```mermaid
flowchart TD
    A["通常"]
    B["カスタム"]
    
    style B fill:#bbf,stroke:#333,stroke-width:4px,color:#000
```

## Performance Tips

1. **Limit node count**: Keep diagrams under 50 nodes for best performance
2. **Use subgraphs**: Group related nodes to improve readability
3. **Avoid crossing lines**: Plan layout to minimize line crossings
4. **Consistent naming**: Use clear, consistent node IDs

## Debugging Tips

1. **Validate incrementally**: Add nodes/edges one at a time
2. **Check quotes**: Ensure all Japanese text uses double quotes
3. **Verify syntax**: Each diagram type has specific syntax requirements
4. **Test isolation**: Create minimal reproduction when debugging errors
5. **Use comments**: Add `%% comment` to document complex diagrams
