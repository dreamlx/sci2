# 测试质量改进快速实施指南

## 🎯 立即行动清单 (1-2周完成)

### 1. 紧急修复 (1-3天)

#### 修复缺失的模型方法
```bash
# 在对应模型中添加以下方法:
app/models/problem_type.rb → 添加 code= 方法
app/models/audit_work_order.rb → 添加 process_fee_detail_selections 方法
app/models/reimbursement.rb → 添加 mark_as_close! 和 can_mark_as_close? 方法
```

#### 更新Factory状态
```ruby
# spec/factories/reimbursements.rb
# 移除废弃的 :closed trait
# 确保所有状态都是当前有效的
```

#### 修复CSV导入测试
```bash
# 检查并修复以下文件:
spec/integration/full_workflow_spec.rb
spec/fixtures/files/test_*.csv 文件路径
```

### 2. 配置优化 (3-5天)

#### 启用测试覆盖率
```ruby
# 在 spec/spec_helper.rb 顶部添加:
require 'simplecov'
SimpleCov.start 'rails' do
  minimum_coverage 85
  add_filter '/spec/'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
end
```

#### 优化RSpec配置
```ruby
# .rspec 文件添加:
--profile 10
--format progress
```

### 3. 质量检查 (1周内)

#### 运行完整测试套件
```bash
bundle exec rspec --format documentation
# 检查所有失败测试并修复
```

#### 性能基准测试
```bash
time bundle exec rspec
# 记录当前执行时间作为基准
```

---

## 📋 每日检查清单

### 开发前
- [ ] 拉取最新代码
- [ ] 运行 `bundle exec rspec` 确保测试通过
- [ ] 检查覆盖率报告

### 开发中
- [ ] 新功能先写测试
- [ ] 使用FactoryBot创建测试数据
- [ ] 遵循现有测试模式

### 提交前
- [ ] 所有相关测试通过
- [ ] 新增测试覆盖新功能
- [ ] 代码风格检查通过

---

## 🛠 常用命令速查

### 测试执行
```bash
# 运行所有测试
bundle exec rspec

# 运行特定文件
bundle exec rspec spec/models/user_spec.rb

# 运行特定测试
bundle exec rspec spec/models/user_spec.rb:25

# 运行特定类型测试
bundle exec rspec spec/models/
bundle exec rspec spec/services/
bundle exec rspec spec/system/

# 生成覆盖率报告
COVERAGE=true bundle exec rspec
```

### Factory调试
```bash
# 查看Factory定义
rails c
> FactoryBot.create(:reimbursement)

# 重新加载Factory
> FactoryBot.reload
```

### 性能分析
```bash
# 查看最慢的10个测试
bundle exec rspec --profile 10

# 分析测试时间
bundle exec rspec --format documentation
```

---

## 🔧 问题排查指南

### 常见失败类型

#### 1. 数据库相关
```ruby
# 症状: ActiveRecord::RecordInvalid
# 解决: 检查Factory数据完整性
# 检查模型验证规则
```

#### 2. 路由相关
```ruby
# 症状: No route matches
# 解决: 检查routes.rb配置
# 检查controller/action名称
```

#### 3. 权限相关
```ruby
# 症状: 期望的按钮/链接不存在
# 解决: 检查Policy权限设置
# 更新测试预期值
```

#### 4. 异步相关
```ruby
# 症状: 测试不稳定，时好时坏
# 解决: 添加等待机制
# 使用Capybara的wait方法
```

### 调试技巧

#### 1. 使用save_and_open_page
```ruby
# 在system测试中
save_and_open_page
# 会自动打开浏览器查看当前页面
```

#### 2. 使用puts调试
```ruby
# 在测试中添加调试输出
puts "Current user: #{user.inspect}"
puts "Reimbursement status: #{reimbursement.status}"
```

#### 3. 使用byebug调试
```ruby
# 在测试中添加断点
byebug
# 进入调试模式
```

---

## 📊 质量监控设置

### Git Hooks配置
```bash
# .git/hooks/pre-commit
#!/bin/bash
bundle exec rspec --format progress
if [ $? -ne 0 ]; then
  echo "Tests failed! Commit aborted."
  exit 1
fi
```

### CI/CD基础配置
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
      - run: bundle install
      - run: bundle exec rspec
```

---

## 🎯 成功标准

### 短期目标 (1周)
- [ ] 测试通过率 ≥ 98%
- [ ] 所有失败测试修复
- [ ] 覆盖率配置完成

### 中期目标 (1月)
- [ ] 测试通过率 ≥ 99%
- [ ] 代码覆盖率 ≥ 85%
- [ ] 执行时间 ≤ 6分钟

### 长期目标 (3月)
- [ ] 测试通过率 100%
- [ ] 代码覆盖率 ≥ 90%
- [ ] 执行时间 ≤ 4分钟

---

## 📞 获取帮助

### 内部资源
- 📖 完整报告: `RAILS_TESTING_QUALITY_IMPROVEMENT_REPORT.md`
- 🧠 测试方法论: `AI_CODER_TESTING_METHODOLOGY.md`
- 📋 项目记忆: Serena记忆系统搜索"测试"

### 外部资源
- 📚 RSpec文档: https://rspec.info/
- 📖 Better Specs: https://www.betterspecs.org/
- 🔧 FactoryBot文档: https://github.com/thoughtbot/factory_bot

---

**记住**: 好的测试是项目成功的基石。每天坚持质量标准，长期收益巨大！