# SCI2 工单系统 ActiveAdmin 用户界面设计更新 (v3.0)

关于UI实现的测试策略，请参阅[测试策略](06_testing_strategy.md)。
关于费用明细状态简化的设计，请参阅[费用明细状态简化](10_simplify_fee_detail_status.md)。

## 1. 用户界面设计概述

SCI2工单系统的用户界面采用ActiveAdmin框架实现，基于单表继承(STI)模型设计。本文档更新反映了最新需求变更，特别是工单模型的单表继承设计和共享表单字段的实现。

### 1.1 主要变更

1. **单表继承模型**：确认使用单表继承(STI)模型实现工单类型
2. **工单关联关系**：移除工单之间的直接关联，所有工单类型直接关联到报销单
3. **共享表单字段**：审核工单和沟通工单表单结构基本相同
4. **工单状态流转**：更新状态流转逻辑，状态由系统自动管理，不允许用户直接编辑
5. **费用明细验证**：统一验证状态流转
6. **沟通工单需要沟通标志**：实现为布尔字段，而非状态值
7. **处理意见与状态关系**：明确定义处理意见如何影响工单状态
8. **操作历史只读**：操作历史记录只能通过导入获取，不能在UI中添加、编辑或删除

### 1.2 用户角色与权限

系统支持三种主要用户角色，均通过`admin_users`表创建：

1. **管理员**：系统管理员，拥有所有权限
2. **审核人员**：负责审核报销单及费用明细
3. **沟通人员**：负责与申请人沟通解决问题

在第一阶段实现中，我们先假设所有用户都是管理员权限，后续再根据需求细化权限控制。

## 2. 用户界面交互流程

### 2.1 报销单处理流程

```mermaid
sequenceDiagram
    participant 财务管理员
    participant 系统
    participant 审核人员
    participant 沟通人员
    
    财务管理员->>系统: 导入报销单
    财务管理员->>系统: 导入快递收单
    系统->>系统: 自动创建快递收单工单(completed)
    系统->>系统: 更新报销单状态为processing
    财务管理员->>系统: 导入费用明细
    财务管理员->>系统: 导入操作历史
    
    审核人员->>系统: 查看报销单详情
    审核人员->>系统: 创建审核工单
    审核人员->>系统: 选择费用明细
    审核人员->>系统: 填写问题信息
    审核人员->>系统: 提交审核工单(系统自动设置为pending)
    
    alt 直接审核通过
        审核人员->>系统: 处理意见设为"可以通过"并点击"审核通过"按钮
        系统->>系统: 更新工单状态为approved
        系统->>系统: 更新费用明细状态为verified
        系统->>系统: 检查所有费用明细是否verified
        系统->>系统: 如果全部verified，更新报销单状态为waiting_completion
    else 开始处理
        审核人员->>系统: 点击"开始处理"按钮
        系统->>系统: 更新工单状态为processing
        系统->>系统: 更新费用明细状态为problematic
        
        alt 处理后通过
            审核人员->>系统: 处理意见设为"可以通过"并点击"审核通过"按钮
            系统->>系统: 更新工单状态为approved
            系统->>系统: 更新费用明细状态为verified
            系统->>系统: 检查所有费用明细是否verified
            系统->>系统: 如果全部verified，更新报销单状态为waiting_completion
        else 处理后拒绝
            审核人员->>系统: 处理意见设为"无法通过"并点击"审核拒绝"按钮
            系统->>系统: 更新工单状态为rejected
            
            沟通人员->>系统: 创建沟通工单
            沟通人员->>系统: 选择相同费用明细
            沟通人员->>系统: 填写问题信息
            沟通人员->>系统: 提交沟通工单(系统自动设置为pending)
            
            沟通人员->>系统: 点击"需要沟通"切换按钮
            系统->>系统: 设置needs_communication布尔标志为true
            系统->>系统: 保持工单当前状态不变
            系统->>系统: 更新费用明细状态为problematic
            
            沟通人员->>系统: 添加沟通记录
            沟通人员->>系统: 处理意见设为"可以通过"并点击"沟通后通过"按钮
            系统->>系统: 更新工单状态为approved
            系统->>系统: 更新费用明细状态为verified
            系统->>系统: 检查所有费用明细是否verified
            系统->>系统: 如果全部verified，更新报销单状态为waiting_completion
        end
    end
    
    系统->>系统: 导入包含"审批通过"的操作历史
    系统->>系统: 更新报销单状态为closed
```

### 2.2 工单状态流转图

#### 审核工单状态流转

```mermaid
stateDiagram-v2
    direction LR
    [*] --> pending
    pending --> processing : 点击"开始处理"按钮
    pending --> approved : 点击"审核通过"按钮
    processing --> approved : 点击"审核通过"按钮
    processing --> rejected : 点击"审核拒绝"按钮
    approved --> [*]
    rejected --> [*]
    
    note right of pending: 处理意见决定状态变化:\n- "可以通过": approved\n- "无法通过": rejected\n- 其他: processing
```

#### 沟通工单状态流转

```mermaid
stateDiagram-v2
    direction LR
    [*] --> pending
    pending --> processing : 点击"开始处理"按钮
    pending --> approved : 点击"沟通后通过"按钮
    processing --> approved : 点击"沟通后通过"按钮
    processing --> rejected : 点击"沟通后拒绝"按钮
    approved --> [*]
    rejected --> [*]
    
    note right of pending: needs_communication是一个布尔标志，\n可以在任何状态下设置或取消\n而不是一个状态值
```

state pending {
    [*] --> needs_communication_false
    needs_communication_false --> needs_communication_true : 切换"需要沟通"标志
    needs_communication_true --> needs_communication_false : 切换"需要沟通"标志
}

state processing {
    [*] --> needs_communication_false
    needs_communication_false --> needs_communication_true : 切换"需要沟通"标志
    needs_communication_true --> needs_communication_false : 切换"需要沟通"标志
}

state approved {
    [*] --> needs_communication_false
    needs_communication_false --> needs_communication_true : 切换"需要沟通"标志
    needs_communication_true --> needs_communication_false : 切换"需要沟通"标志
}

state rejected {
    [*] --> needs_communication_false
    needs_communication_false --> needs_communication_true : 切换"需要沟通"标志
    needs_communication_true --> needs_communication_false : 切换"需要沟通"标志
}

#### 报销单状态流转

```mermaid
stateDiagram-v2
    direction LR
    [*] --> pending : 导入
    pending --> processing : 创建工单
    processing --> waiting_completion : 所有费用明细verified
    waiting_completion --> closed : 导入审批通过操作历史
    closed --> [*]
```

## 3. 仪表盘设计

仪表盘需要更新以反映新的"等待完成"状态：

```mermaid
graph TD
    A[仪表盘] --> B[报销单状态统计]
    A --> C[待处理工单]
    A --> D[最近活动]
    A --> E[快速操作]
    
    B --> B1[待处理]
    B --> B2[处理中]
    B --> B3[等待完成]
    B --> B4[已关闭]
    
    C --> C1[待处理审核工单]
    C --> C2[待处理沟通工单]
    
    E --> E1[导入报销单]
    E --> E2[导入快递收单]
    E --> E3[导入费用明细]
    E --> E4[导入操作历史]
```

## 4. 工单模块界面设计

### 4.1 审核工单详情页

```mermaid
graph TD
    A[审核工单详情页] --> B[基本信息标签页]
    A --> C[费用明细标签页]
    A --> D[状态变更历史标签页]
    
    B --> B1[工单属性表]
    B --> B2[状态操作按钮]
    
    C --> C1[关联费用明细列表]
    C --> C2[费用明细验证状态] # 注意：根据费用明细状态简化设计，状态由FeeDetail模型管理
    C --> C3[更新验证状态按钮]
    
    D --> D1[状态变更历史列表]
    
    B1 --> B1a[报销单]
    B1 --> B1b[状态]
    B1 --> B1c[问题类型]
    B1 --> B1d[问题说明]
    B1 --> B1e[备注说明]
    B1 --> B1f[处理意见]
    B1 --> B1g[审核结果]
    B1 --> B1h[审核意见]
    
    B2 --> B2a[开始处理]
    B2 --> B2b[审核通过]
    B2 --> B2c[审核拒绝]
```

### 4.2 沟通工单详情页

```mermaid
graph TD
    A[沟通工单详情页] --> B[基本信息标签页]
    A --> C[沟通记录标签页]
    A --> D[费用明细标签页]
    A --> E[状态变更历史标签页]
    
    B --> B1[工单属性表]
    B --> B2[状态操作按钮]
    B --> B3[需要沟通标志]
    
    C --> C1[沟通记录列表]
    C --> C2[添加沟通记录按钮]
    
    D --> D1[关联费用明细列表]
    D --> D2[费用明细验证状态] # 注意：根据费用明细状态简化设计，状态由FeeDetail模型管理
    D --> D3[更新验证状态按钮]
    
    E --> E1[状态变更历史列表]
    
    B1 --> B1a[报销单]
    B1 --> B1b[状态]
    B1 --> B1c[问题类型]
    B1 --> B1d[问题说明]
    B1 --> B1e[备注说明]
    B1 --> B1f[处理意见]
    B1 --> B1g[沟通方式]
    B1 --> B1h[发起人角色]
    B1 --> B1i[解决方案摘要]
    
    B2 --> B2a[开始处理]
    B2 --> B2b[沟通后通过]
    B2 --> B2c[沟通后拒绝]
    
    B3 --> B3a[切换需要沟通标志]
```

### 4.3 操作历史列表页

```mermaid
graph TD
    A[操作历史列表页] --> B[过滤器]
    A --> C[操作历史列表]
    A --> D[导入按钮]
    
    B --> B1[报销单号过滤器]
    B --> B2[操作类型过滤器]
    B --> B3[操作人过滤器]
    
    C --> C1[报销单号]
    C --> C2[操作类型]
    C --> C3[操作时间]
    C --> C4[操作人]
    C --> C5[操作意见]
    
    D --> D1[导入操作历史按钮]
```

## 5. 表单设计

### 5.1 共享字段下拉列表选项

为审核工单和沟通工单的共享字段提供统一的下拉列表选项：

1. **问题类型下拉列表**
   - 发票问题
   - 金额错误
   - 费用类型错误
   - 缺少附件
   - 其他问题

2. **问题说明下拉列表**
   - 发票信息不完整
   - 发票金额与申报金额不符
   - 费用类型选择错误
   - 缺少必要证明材料
   - 其他问题说明

3. **处理意见下拉列表**
   - 需要补充材料
   - 需要修改申报信息
   - 需要重新提交
   - 可以通过
   - 无法通过

### 5.2 审核工单表单

```mermaid
graph TD
    A[审核工单表单] --> B[报销单信息]
    A --> C[工单基本信息]
    A --> D[费用明细选择]
    A --> E[提交按钮]
    
    C --> C2[问题类型下拉列表]
    C --> C3[问题说明下拉列表]
    C --> C4[备注说明文本框]
    C --> C5[处理意见下拉列表]
    C --> C6[审核意见文本框]
    
    D --> D1[费用明细多选框]
    
    note right of A[状态由系统自动管理，不在表单中显示为可编辑字段]
```

### 5.3 沟通工单表单

```mermaid
graph TD
    A[沟通工单表单] --> B[报销单信息]
    A --> C[工单基本信息]
    A --> D[费用明细选择]
    A --> E[提交按钮]
    
    C --> C2[问题类型下拉列表]
    C --> C3[问题说明下拉列表]
    C --> C4[备注说明文本框]
    C --> C5[处理意见下拉列表]
    C --> C6[沟通方式下拉列表]
    C --> C7[发起人角色下拉列表]
    C --> C8[解决方案摘要文本框]
    C --> C9[需要沟通复选框]
    
    D --> D1[费用明细多选框]
    
    note right of A[状态由系统自动管理，不在表单中显示为可编辑字段]
```

## 6. 数据导入界面设计

数据导入界面需要更新以支持重复记录处理：

```mermaid
graph TD
    A[数据导入界面] --> B[文件选择]
    A --> C[导入选项]
    A --> D[导入按钮]
    A --> E[导入结果]
    
    B --> B1[文件上传控件]
    
    C --> C1[数据类型选择]
    C --> C2[重复处理策略]
    
    E --> E1[成功记录数]
    E --> E2[更新记录数]
    E --> E3[跳过记录数]
    E --> E4[错误记录数]
    E --> E5[错误详情]
    E --> E6[未匹配记录下载]
```

### 6.1 重复处理策略

- **报销单**：以invoice number为唯一键，重复时覆盖更新
- **费用明细**：完全相同记录跳过
- **操作历史**：完全相同记录跳过

## 7. 处理意见与状态关系

处理意见与工单状态的关系如下：

- **处理意见为空**：保持当前状态
- **处理意见为"可以通过"**：状态变为approved（当用户点击相应的操作按钮时）
- **处理意见为"无法通过"**：状态变为rejected（当用户点击相应的操作按钮时）
- **其他处理意见**：状态变为processing（当用户点击"开始处理"按钮时）

这种关系通过状态机和服务层方法实现，而不是通过直接编辑状态字段。

## 8. 实施建议

1. **优先级排序**：
   - 首先更新数据库结构和模型实现
   - 然后更新服务层实现
   - 最后更新ActiveAdmin集成和UI设计

2. **测试策略**：
   - 确保单元测试覆盖单表继承模型的所有功能
   - 添加集成测试验证工单状态流转和费用明细状态变更
   - 测试数据导入的重复处理逻辑
   - 测试needs_communication布尔标志的设置和取消
   - 测试操作历史的只读性

3. **UI改进**：
   - 使用标准化的下拉列表选项
   - 确保表单字段布局一致
   - 提供清晰的状态流转操作按钮
   - 为needs_communication布尔标志提供明确的UI控件
   - 确保操作历史只能通过导入功能添加，不能在UI中直接编辑
   
## 9. 相关文档引用

- 有关详细的数据库结构设计，请参阅[数据库结构设计](02_database_structure.md)
- 有关详细的模型实现，请参阅[模型实现](03_model_implementation_updated.md)
- 有关详细的服务实现，请参阅[服务实现](04_service_implementation_updated.md)
- 有关详细的ActiveAdmin集成，请参阅[ActiveAdmin集成](05_activeadmin_integration_updated_v3.md)
- 有关详细的测试策略，请参阅[测试策略](06_testing_strategy.md)
- 有关费用明细状态简化的设计，请参阅[费用明细状态简化](10_simplify_fee_detail_status.md)