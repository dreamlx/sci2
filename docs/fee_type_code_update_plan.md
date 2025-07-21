# 费用类型和问题类型导入功能修改计划

## 1. 背景与需求

当前系统中，费用类型和问题类型的导入功能通过CSV文件实现。根据需求，需要修改费用类型的code生成逻辑，使其为CSV文件中"Meeting Code"和"Expense Code"的组合，而不是仅使用"Expense Code"。

例如，对于CSV中的一行数据：
```
Document Code,Meeting Code,会议类型,Expense Code,费用类型,Issue Code,问题类型,...
EN000101,00,个人,01,月度交通费（销售/SMO/CO),01,燃油费行程问题,...
```

- 当前逻辑：fee_type.code = "01"（仅使用Expense Code）
- 新逻辑：fee_type.code = "0001"（Meeting Code + Expense Code）

## 2. 系统现状分析

### 2.1 数据模型

1. **FeeType（费用类型）**:
   - 主要字段：code, title, meeting_type, active
   - code字段有唯一性约束
   - 与ProblemType是一对多关系

2. **ProblemType（问题类型）**:
   - 主要字段：code, title, sop_description, standard_handling, fee_type_id, active
   - code字段有唯一性约束
   - 属于一个FeeType（可选）

### 2.2 导入功能

导入功能由`ProblemCodeImportService`类实现，主要流程为：
1. 读取CSV文件
2. 逐行处理数据
3. 创建或更新费用类型和问题类型
4. 返回导入结果

当前费用类型code生成逻辑在`process_row`方法中：
```ruby
# 当前逻辑
fee_type_code = exp_code
```

## 3. 修改方案

### 3.1 代码修改

1. **修改`ProblemCodeImportService`中的`process_row`方法**:

```ruby
def process_row(row)
  # Extract meeting type from Meeting Code
  meeting_code = row['Meeting Code']&.strip
  meeting_type = row['会议类型']&.strip
  
  # Extract fee type information
  exp_code = row['Expense Code']&.strip
  fee_type_title = row['费用类型']&.strip
  
  # 其他代码保持不变...
  
  # 修改这里：使用meeting_code + exp_code作为fee_type_code
  fee_type_code = "#{meeting_code}#{exp_code}"
  
  # 修改查找逻辑，优先按code查找
  fee_type = FeeType.find_by(code: fee_type_code)
  
  if fee_type
    # 更新逻辑...
  else
    # 创建逻辑...
  end
  
  # 其他代码保持不变...
end
```

2. **更新导入视图说明**:

修改`app/views/admin/imports/problem_codes.html.erb`文件，添加关于新code生成规则的说明：

```erb
<p><strong>注意：</strong> 费用类型代码将自动生成为 Meeting Code + Expense Code 的组合</p>

<p><strong>在上面的例子中：</strong></p>
<ul>
  <li>费用类型代码将为 "0001"（Meeting Code "00" + Expense Code "01"）</li>
  <li>问题类型代码将为 "EN000101"（Document Code）</li>
</ul>
```

### 3.2 数据迁移

为了处理现有数据，我们创建了一个数据迁移脚本`db/migrate/20250720162600_update_fee_type_codes.rb`，将现有费用类型的code更新为新的组合格式：

```ruby
class UpdateFeeTypeCodes < ActiveRecord::Migration[7.1]
  def up
    # 创建一个临时表来存储费用类型和会议类型的映射关系
    mapping = {}
    
    # 查找所有费用类型
    FeeType.find_each do |fee_type|
      # 跳过已经是组合格式的代码（假设组合格式的代码长度大于2）
      next if fee_type.code.length > 2
      
      # 根据会议类型确定Meeting Code
      meeting_code = case fee_type.meeting_type
                     when "个人"
                       "00"
                     when "学术论坛"
                       "01"
                     else
                       "99" # 默认值
                     end
      
      # 生成新的代码
      new_code = "#{meeting_code}#{fee_type.code}"
      
      # 存储映射关系
      mapping[fee_type.id] = new_code
    end
    
    # 更新费用类型代码
    mapping.each do |fee_type_id, new_code|
      # 检查新代码是否已存在
      if FeeType.where(code: new_code).where.not(id: fee_type_id).exists?
        # 如果已存在，生成一个唯一的代码
        suffix = 1
        while FeeType.where(code: "#{new_code}#{suffix}").exists?
          suffix += 1
        end
        new_code = "#{new_code}#{suffix}"
      end
      
      # 更新费用类型代码
      FeeType.where(id: fee_type_id).update_all(code: new_code)
    end
    
    # 输出迁移结果
    puts "已更新 #{mapping.size} 个费用类型代码"
  end
  
  def down
    # 这个迁移不可逆，因为我们无法确定原始的代码
    raise ActiveRecord::IrreversibleMigration
  end
end
```

## 4. 测试计划

我们创建了一个RSpec测试文件`spec/services/problem_code_import_service_spec.rb`，用于测试修改后的导入功能：

### 4.1 测试场景

1. **基本功能测试**:
   - 导入全新的费用类型和问题类型
   - 验证费用类型的code是否正确组合（Meeting Code + Expense Code）
   - 验证问题类型是否正确关联到费用类型

2. **更新测试**:
   - 导入已存在的费用类型（相同code）但title或meeting_type不同
   - 验证费用类型是否被正确更新
   - 导入已存在的问题类型但关联的费用类型不同
   - 验证问题类型是否被正确更新

3. **边界情况测试**:
   - 导入缺少必要字段的数据行
   - 验证是否正确跳过并记录日志

## 5. 实施步骤

1. **开发阶段**:
   - [x] 修改`ProblemCodeImportService`中的代码生成逻辑
   - [x] 更新导入视图中的说明
   - [x] 创建数据迁移脚本
   - [x] 编写测试用例

2. **测试阶段**:
   - [ ] 在开发环境中执行测试
   - [ ] 验证导入结果
   - [ ] 修复发现的问题

3. **部署阶段**:
   - [ ] 将修改后的代码部署到测试环境
   - [ ] 执行集成测试
   - [ ] 确认功能正常后部署到生产环境

4. **上线后监控**:
   - [ ] 监控导入功能的使用情况
   - [ ] 收集用户反馈
   - [ ] 必要时进行调整

## 6. 风险与缓解措施

1. **数据一致性风险**:
   - 风险：修改code生成逻辑可能导致新旧数据不一致
   - 缓解：使用数据迁移脚本，将现有数据转换为新格式

2. **功能兼容性风险**:
   - 风险：其他依赖费用类型code的功能可能受到影响
   - 缓解：全面测试系统中所有相关功能，确保兼容性

3. **用户适应风险**:
   - 风险：用户可能不适应新的code格式
   - 缓解：更新文档和培训材料，明确说明新的code生成规则

## 7. 总结

本计划详细描述了费用类型和问题类型导入功能的修改方案，包括代码修改、数据迁移、测试计划和实施步骤。通过这些修改，系统将能够按照新的需求生成费用类型的code，即使用Meeting Code和Expense Code的组合。