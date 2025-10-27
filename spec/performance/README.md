# 导入服务性能测试

## 概述

这个性能测试套件专门为Rails导入服务重构设计，用于验证重构后的性能表现并检测潜在的回归问题。

## 测试架构

### 核心组件

1. **BenchmarkHelpers** (`benchmark_helpers.rb`)
   - 性能测试辅助工具
   - 内存分析和查询计数
   - 并发测试支持
   - 系统资源监控

2. **PerformanceReporter** (`performance_reporter.rb`)
   - 性能报告生成器
   - 支持JSON、HTML格式
   - CI/CD友好的简化报告
   - 趋势分析和建议生成

3. **ImportServicePerformanceSpec** (`import_service_performance_spec.rb`)
   - 主要的性能测试套件
   - 覆盖所有导入服务场景
   - 回调链性能测试
   - 并发和数据完整性测试

## 测试覆盖范围

### 1. 基准性能测试
- **数据量**: 100, 500, 1000, 5000条记录
- **服务**: UnifiedReimbursementImportService, UnifiedExpressReceiptImportService
- **指标**: 执行时间、数据库查询数、内存使用、吞吐量

### 2. 回调链性能测试
- 工单创建回调链 (`after_create`)
- 状态机回调 (`after_transition`)
- 批量状态同步性能
- N+1查询检测

### 3. 并发测试
- 多线程同时导入
- 数据一致性验证
- 资源竞争检测
- 性能退化监控

### 4. 资源使用监控
- CPU使用率监控
- 内存分配跟踪
- 数据库连接池健康
- 磁盘I/O统计

### 5. 数据完整性测试
- 大批量导入的事务安全性
- 回滚机制验证
- 数据一致性检查
- 并发写入冲突检测

## 性能阈值

### 动态阈值策略

性能阈值根据数据量动态调整：

```ruby
# 报销单导入阈值
execution_time: base_time + (record_count * 0.002)  # 每条记录增加2ms
db_queries: base_queries + (record_count * 0.05)     # 每条记录增加0.05个查询
memory_usage: 50MB + (record_count * 10KB)           # 基础50MB + 每条记录10KB

# 快递收单导入阈值
execution_time: 1.5s + (record_count * 0.0015s)
db_queries: 30 + (record_count * 0.08)
memory_usage: 30MB + (record_count * 8KB)
```

### 静态阈值

- **执行时间警告**: 5秒
- **执行时间严重**: 10秒
- **数据库查询警告**: 100个查询
- **数据库查询严重**: 200个查询
- **内存使用警告**: 50MB
- **内存使用严重**: 100MB
- **吞吐量警告**: 10 records/sec
- **吞吐量严重**: 5 records/sec

## 运行测试

### 本地运行

```bash
# 运行所有性能测试
bundle exec rspec spec/performance/

# 运行特定测试
bundle exec rspec spec/performance/import_service_performance_spec.rb

# 运行时生成报告
PERFORMANCE_TEST=true bundle exec rspec spec/performance/ --format documentation
```

### CI/CD运行

性能测试通过GitHub Actions自动运行：
- **触发条件**: push到main/develop分支、PR、每日定时任务
- **数据库**: PostgreSQL 13
- **报告**: 自动生成并上传为Artifacts

## 报告输出

### 1. JSON详细报告
- 完整的性能指标
- 测试元数据
- 趋势分析
- 优化建议

### 2. HTML可视化报告
- 交互式图表
- 性能趋势可视化
- 详细的测试结果表格

### 3. CI友好报告
- 简化的JSON格式
- 阈值状态检查
- 关键指标摘要

### 4. PR评论集成
- 自动在PR中添加性能测试结果
- 高亮显示性能回归
- 提供优化建议

## 性能监控

### 实时监控

```ruby
# 在测试中启用监控
result = benchmark_performance('test_name',
                              profile_memory: true,
                              iterations: 3) do
  # 被测试的代码
end
```

### 资源监控

```ruby
# 系统资源监控
resources = monitor_system_resources
# => { cpu_usage: 45.2, memory_usage: 524288000, db_connections: 5, disk_io: {...} }
```

### 数据库查询分析

```ruby
# 查询计数和N+1检测
query_count = count_db_queries do
  # 执行数据库操作
end
```

## 故障排除

### 常见问题

1. **内存不足错误**
   - 减少测试数据量
   - 检查内存泄漏
   - 增加JVM堆大小

2. **数据库连接超时**
   - 检查连接池配置
   - 验证查询优化
   - 增加连接超时时间

3. **测试不稳定**
   - 确保测试数据隔离
   - 使用事务回滚
   - 增加等待时间

### 调试技巧

```ruby
# 启用详细日志
Rails.logger.level = :debug

# 捕获测试日志
logs = with_captured_logs do
  # 测试代码
end

# 内存分析
MemoryProfiler.report do
  # 测试代码
end.pretty_print
```

## 最佳实践

### 1. 测试设计
- 使用真实的业务数据
- 模拟生产环境负载
- 包含边界条件测试

### 2. 性能优化
- 优先优化最慢的测试
- 关注数据库查询效率
- 监控内存分配模式

### 3. 持续改进
- 定期更新性能阈值
- 跟踪性能趋势
- 建立性能回归检测

## 扩展指南

### 添加新的性能测试

```ruby
describe 'NewService Performance' do
  it 'performs efficiently' do
    result = benchmark_performance('new_service_test') do
      # 测试代码
    end

    # 断言和报告
    reporter.add_result(result)
  end
end
```

### 自定义指标

```ruby
# 扩展PerformanceResult类
class CustomPerformanceResult < PerformanceResult
  attr_accessor :custom_metric

  def calculate_custom_metric
    # 自定义指标计算
  end
end
```

## 相关文档

- [Rails性能测试指南](https://guides.rubyonrails.org/testing.html#performance-testing)
- [Benchmark库文档](https://ruby-doc.org/stdlib-3.0.0/libdoc/benchmark/rdoc/Benchmark.html)
- [MemoryProfiler文档](https://github.com/SamSaffron/memory_profiler)

## 贡献指南

1. 新增测试请遵循现有模式
2. 更新文档说明
3. 确保CI通过
4. 添加相应的性能阈值
5. 提供充分的测试覆盖