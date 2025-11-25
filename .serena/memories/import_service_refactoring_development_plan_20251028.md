# Import服务重构开发计划和任务清单

## 🎯 重构目标确认
**用户决策**: 废弃重复服务，OptimizedFeeDetailImportService需要分析价值并合并到统一版本，BaseImportService不需要过度抽象

## 📋 核心任务分解

### Phase 1: ExpressReceipt服务废弃和统一 (Day 1)
- 验证UnifiedExpressReceiptImportService功能完整性
- 标记express_receipt_import_service.rb为废弃
- 迁移improved_express_receipt_import_service.rb的字段映射配置
- 更新所有调用方引用到统一版本

### Phase 2: FeeDetail服务优化合并 (Day 2)  
- 创建OptimizedUnifiedFeeDetailImportService
- 集成BatchImportManager性能优化架构
- 迁移SqliteOptimizationManager集成
- 验证业务逻辑完整性

### Phase 3: 核心测试补充 (Day 3-4)
- 编写OptimizedUnifiedFeeDetailImportService测试
- 增强UnifiedExpressReceiptImportService测试覆盖
- 创建BatchImportManager性能基准测试

### Phase 4: 验证和清理 (Day 5)
- 运行完整测试套件验证重构结果
- 验证覆盖率提升目标达成
- 性能基准测试和优化验证
- 更新项目文档和记忆

## 🚀 OptimizedFeeDetailImportService优化价值确认

### 核心优化特性
1. **BatchImportManager批量处理**: 1000条/批次，原始SQL插入，upsert_all批量更新
2. **SQLite优化管理器**: MODERATE_SETTINGS，WAL模式，外键约束临时关闭
3. **智能回调禁用**: 跳过耗时回调，避免N+1查询，减少20-30%导入时间
4. **预加载关联数据**: 避免重复查询，从N×M次降至N+M次

### 性能提升预期
- 小批量(<1000条): 20-40%提升
- 中批量(1000-5000条): 40-70%提升  
- 大批量(>5000条): 70-200%提升

## 📊 重构收益预期
- **代码减少**: 883行 (76%重复代码消除)
- **覆盖率提升**: 20% → 32%+ (+8-10%服务层覆盖)
- **性能保持**: 40-200%性能提升完全保留
- **架构统一**: BaseImportService + 性能优化模式

## 🎯 验收标准
- 代码重复率: 76% → <15%
- 测试覆盖率: 20% → 32%+
- 性能提升: 40-200% (根据数据量)
- 技术债务: 2个重复服务完全废弃

## 📅 执行时间表
5天执行周期，每天一个Phase，Day 5完成全面验证和文档更新

## 📄 详细开发计划
完整开发计划已保存至: IMPORT_SERVICE_REFACTORING_DEVELOPMENT_PLAN.md