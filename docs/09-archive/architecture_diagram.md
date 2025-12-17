# 三级问题代码库架构设计图

## 1. 数据库结构关系图

```mermaid
erDiagram
    REIMBURSEMENTS ||--o{ FEE_DETAILS : "has many"
    REIMBURSEMENTS ||--o{ WORK_ORDERS : "has many"
    
    WORK_ORDERS ||--o{ WORK_ORDER_FEE_DETAILS : "has many"
    FEE_DETAILS ||--o{ WORK_ORDER_FEE_DETAILS : "has many"
    
    PROBLEM_MEETING_TYPES ||--o{ PROBLEM_MAJOR_CATEGORIES : "has many"
    PROBLEM_MAJOR_CATEGORIES ||--o{ PROBLEM_SPECIFIC_TYPES : "has many"
    
    WORK_ORDERS }o--|| PROBLEM_MEETING_TYPES : "belongs to"
    WORK_ORDERS }o--|| PROBLEM_MAJOR_CATEGORIES : "belongs to"
    WORK_ORDERS }o--|| PROBLEM_SPECIFIC_TYPES : "belongs to"
    
    REIMBURSEMENTS {
        string invoice_number PK
        string document_name
        string status
        boolean is_electronic
        datetime created_at
    }
    
    FEE_DETAILS {
        int id PK
        string document_number FK
        string fee_type
        decimal amount
        string verification_status
        string flex_field_7
    }
    
    WORK_ORDERS {
        int id PK
        int reimbursement_id FK
        string type
        string status
        string processing_opinion
        int problem_meeting_type_id FK
        int problem_major_category_id FK
        int problem_specific_type_id FK
        text custom_description
    }
    
    WORK_ORDER_FEE_DETAILS {
        int id PK
        int work_order_id FK
        int fee_detail_id FK
        string work_order_type
    }
    
    PROBLEM_MEETING_TYPES {
        int id PK
        string code
        string title
        boolean active
    }
    
    PROBLEM_MAJOR_CATEGORIES {
        int id PK
        string code
        string title
        int meeting_type_id FK
        boolean active
    }
    
    PROBLEM_SPECIFIC_TYPES {
        int id PK
        string code
        string title
        text sop_description
        text standard_handling
        int major_category_id FK
        boolean active
    }
```

## 2. 三级问题选择流程图

```mermaid
flowchart TD
    A[开始创建工单] --> B[选择报销单]
    B --> C[选择费用明细组]
    C --> D{报销单类型判断}
    
    D -->|个人单| E[自动选择: 00-个人]
    D -->|学术单| F[显示学术会议类型列表]
    
    E --> G[加载个人问题大类]
    F --> H[用户选择会议类型]
    H --> I[加载对应问题大类]
    
    G --> J[用户选择问题大类]
    I --> J
    J --> K[加载具体问题类型]
    K --> L[用户选择具体问题]
    L --> M{是否需要自定义描述?}
    
    M -->|是| N[填写自定义描述]
    M -->|否| O[设置处理意见]
    N --> O
    O --> P[保存工单]
    P --> Q[更新费用明细状态]
    Q --> R[结束]
```

## 3. 数据迁移流程图

```mermaid
flowchart TD
    A[开始数据迁移] --> B[备份现有数据]
    B --> C[创建三级表结构]
    C --> D[创建默认会议类型]
    D --> E[分析现有问题类型]
    
    E --> F{问题类型属于哪个类别?}
    F -->|个人相关| G[映射到个人会议类型]
    F -->|学术相关| H[映射到学术会议类型]
    
    G --> I[创建问题大类记录]
    H --> I
    I --> J[迁移问题描述到具体问题类型]
    J --> K[验证数据完整性]
    K --> L{验证通过?}
    
    L -->|否| M[修复数据问题]
    M --> K
    L -->|是| N[从CSV导入标准代码]
    N --> O[最终验证]
    O --> P[迁移完成]
```

## 4. 工单状态流转图

```mermaid
stateDiagram-v2
    [*] --> pending : 创建工单
    
    pending --> approved : 处理意见=可以通过
    pending --> rejected : 处理意见=无法通过
    
    approved --> rejected : 修改为无法通过
    rejected --> approved : 问题解决,修改为可以通过
    
    approved --> [*] : 报销单关闭
    rejected --> [*] : 报销单关闭
    
    note right of approved
        费用明细状态 = verified
    end note
    
    note right of rejected
        费用明细状态 = problematic
        必须选择具体问题类型
    end note
```

## 5. 报销单状态流转图

```mermaid
stateDiagram-v2
    [*] --> pending : 导入报销单
    
    pending --> processing : 创建工单 OR 收到快递
    processing --> closed : 手动完成 OR 操作历史触发
    
    closed --> processing : 重新打开(如果支持)
    
    note right of pending
        初始状态
        is_electronic = true
    end note
    
    note right of processing
        有工单处理中
        可能 is_electronic = false
    end note
    
    note right of closed
        处理完成
        禁止创建/修改工单
    end note
```

## 6. 系统架构层次图

```mermaid
graph TB
    subgraph "用户界面层"
        A[ActiveAdmin 管理界面]
        B[三级级联下拉组件]
        C[工单管理界面]
    end
    
    subgraph "业务逻辑层"
        D[WorkOrder 模型]
        E[问题选择验证逻辑]
        F[状态流转逻辑]
    end
    
    subgraph "数据访问层"
        G[三级问题代码库模型]
        H[工单-费用明细关联]
        I[数据验证和约束]
    end
    
    subgraph "数据存储层"
        J[(问题代码库表)]
        K[(工单表)]
        L[(关联表)]
    end
    
    A --> D
    B --> E
    C --> F
    
    D --> G
    E --> H
    F --> I
    
    G --> J
    H --> K
    I --> L
```

## 7. 实施时间线

```mermaid
gantt
    title 三级问题代码库实施时间线
    dateFormat  YYYY-MM-DD
    section 数据库升级
    创建表结构        :db1, 2025-05-29, 1d
    添加字段和索引    :db2, after db1, 1d
    
    section 模型开发
    创建新模型类      :model1, after db2, 1d
    更新关联关系      :model2, after model1, 1d
    
    section 数据迁移
    分析现有数据      :migrate1, after model2, 1d
    执行数据迁移      :migrate2, after migrate1, 2d
    验证迁移结果      :migrate3, after migrate2, 1d
    
    section 界面开发
    更新表单界面      :ui1, after migrate3, 2d
    实现级联下拉      :ui2, after ui1, 2d
    添加管理界面      :ui3, after ui2, 1d
    
    section 测试验证
    单元测试          :test1, after ui3, 1d
    集成测试          :test2, after test1, 1d
    用户验收测试      :test3, after test2, 1d
```

## 8. 风险控制流程

```mermaid
flowchart TD
    A[开始实施] --> B[数据备份]
    B --> C[创建测试环境]
    C --> D[分阶段实施]
    
    D --> E{当前阶段测试}
    E -->|通过| F[进入下一阶段]
    E -->|失败| G[分析问题]
    
    G --> H{问题严重程度}
    H -->|轻微| I[修复并重测]
    H -->|严重| J[执行回滚]
    
    I --> E
    J --> K[恢复到上一稳定状态]
    K --> L[重新评估方案]
    L --> D
    
    F --> M{是否最后阶段?}
    M -->|否| D
    M -->|是| N[最终验收]
    N --> O[部署到生产环境]
    O --> P[实施完成]
```

这些图表清晰地展示了：
1. 数据库结构的完整关系
2. 三级问题选择的用户流程
3. 数据迁移的详细步骤
4. 系统各层次的架构关系
5. 实施的时间安排
6. 风险控制的流程

通过这些可视化图表，团队可以更好地理解整个调整计划的复杂性和实施路径。