# 费用明细重复记录修复方案文件索引

本文档提供了费用明细重复记录修复方案中所有文件的索引和说明。

## 代码文件

### 模型

| 文件路径 | 说明 | 修改内容 |
|---------|------|---------|
| `app/models/fee_detail.rb` | 费用明细模型 | 已包含 `validates :external_fee_id, presence: true, uniqueness: true` 验证 |

### 服务

| 文件路径 | 说明 | 修改内容 |
|---------|------|---------|
| `app/services/fee_detail_import_service.rb` | 费用明细导入服务 | 已更新以严格要求 `external_fee_id` 存在并简化重复检测逻辑 |

## 数据库迁移

| 文件路径 | 说明 | 用途 |
|---------|------|------|
| `db/migrate/20250725080400_ensure_external_fee_id_presence.rb` | 确保 external_fee_id 存在的迁移 | 为所有 `nil` 值的 `external_fee_id` 生成唯一值，并添加非空约束和唯一索引 |
| `db/migrate/20250725080500_fix_duplicate_external_fee_ids.rb` | 修复重复 external_fee_id 的迁移 | 识别并修复所有重复的 `external_fee_id` 值，保留最近更新的记录 |

## 脚本

| 文件路径 | 说明 | 用途 |
|---------|------|------|
| `db/scripts/fix_duplicate_external_fee_ids.rb` | 修复重复 external_fee_id 的脚本 | 提供更详细的处理，可在迁移后运行以确保所有问题都已解决 |
| `db/scripts/README_FIX_DUPLICATE_EXTERNAL_FEE_IDS.md` | 脚本说明文档 | 提供运行迁移和脚本的详细说明 |

## 文档

| 文件路径 | 说明 | 用途 |
|---------|------|------|
| `docs/fee_detail_duplicate_fix_summary.md` | 总结文档 | 提供问题、解决方案和实施细节的综合概述 |
| `docs/fee_detail_duplicate_fix_test_plan.md` | 测试计划 | 提供在开发环境中测试实施更改的步骤和验证点 |
| `docs/fee_detail_duplicate_fix_deployment_plan.md` | 部署计划 | 提供在生产环境中部署更改的步骤和注意事项 |
| `docs/fee_detail_duplicate_fix_monitoring_plan.md` | 监控计划 | 提供部署后监控系统的指标、工具和流程 |
| `docs/fee_detail_duplicate_fix_file_index.md` | 文件索引 | 提供所有相关文件的索引和说明（本文档） |

## 监控脚本

| 文件路径 | 说明 | 用途 |
|---------|------|------|
| `db/scripts/monitor_duplicate_external_fee_ids.rb` | 监控重复 external_fee_id 的脚本 | 定期检查是否有重复的 `external_fee_id` 值 |
| `db/scripts/monitor_nil_external_fee_ids.rb` | 监控 nil external_fee_id 的脚本 | 定期检查是否有 `nil` 值的 `external_fee_id` |
| `db/scripts/README_MONITORING_SCRIPTS.md` | 监控脚本说明文档 | 提供监控脚本的使用说明和配置选项 |

## 文件关系图

```
费用明细重复记录修复方案
│
├── 代码文件
│   ├── app/models/fee_detail.rb (模型验证)
│   └── app/services/fee_detail_import_service.rb (导入逻辑)
│
├── 数据库迁移
│   ├── db/migrate/20250725080400_ensure_external_fee_id_presence.rb (处理 nil 值)
│   └── db/migrate/20250725080500_fix_duplicate_external_fee_ids.rb (处理重复值)
│
├── 脚本
│   ├── db/scripts/fix_duplicate_external_fee_ids.rb (详细处理脚本)
│   ├── db/scripts/README_FIX_DUPLICATE_EXTERNAL_FEE_IDS.md (脚本说明)
│   ├── db/scripts/monitor_duplicate_external_fee_ids.rb (监控重复值)
│   ├── db/scripts/monitor_nil_external_fee_ids.rb (监控 nil 值)
│   └── db/scripts/README_MONITORING_SCRIPTS.md (监控脚本说明)
│
└── 文档
    ├── docs/fee_detail_duplicate_fix_summary.md (总结)
    ├── docs/fee_detail_duplicate_fix_test_plan.md (测试)
    ├── docs/fee_detail_duplicate_fix_deployment_plan.md (部署)
    ├── docs/fee_detail_duplicate_fix_monitoring_plan.md (监控)
    └── docs/fee_detail_duplicate_fix_file_index.md (索引)
```

## 执行顺序

1. 在开发/测试环境中：
   1. 部署代码更改
   2. 运行 `20250725080400_ensure_external_fee_id_presence.rb` 迁移
   3. 运行 `20250725080500_fix_duplicate_external_fee_ids.rb` 迁移
   4. 如果需要，运行 `fix_duplicate_external_fee_ids.rb` 脚本
   5. 按照测试计划验证更改

2. 在生产环境中：
   1. 按照部署计划进行部署
   2. 部署后按照监控计划进行监控

## 注意事项

1. 在执行任何操作前，务必备份数据库
2. 迁移和脚本会修改数据，请确保在测试环境中充分测试
3. 部署应在维护窗口期间进行，以最小化对用户的影响
4. 部署后应密切监控系统，确保没有新的重复记录产生