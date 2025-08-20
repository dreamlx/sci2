# SCI2工单系统界面调整方案

## 背景

客户提出了新的需求，需要调整工单表单的界面交互方式，主要涉及费用类型显示和问题类型选择的变更。

## 当前实现

1. 工单表单中，费用类型是通过下拉列表选择的，然后根据选择的费用类型加载对应的问题类型。
2. 问题类型是单选的，一个工单只能关联一个问题类型。
3. 处理意见（"可以通过"或"无法通过"）决定工单状态。
4. 审核意见会根据选择的问题类型自动填充内容。

## 新需求

1. 费用类型不再是下拉列表，而是根据选择的费用明细自动以标签形式分组显示。
   - 例如：选中了3个费用明细，其中2个是费用类型A，1个是费用类型B，则显示"费用类型A，费用类型B"。
2. 问题类型改为复选框，允许多选问题。
3. 审核意见不再自动填充内容。
4. 处理意见仍然决定工单状态。

## 调整方案

### 1. 费用明细选择与费用类型标签

1. 修改 `app/views/admin/shared/_fee_details_selection.html.erb` 文件：
   - 保留现有的费用明细复选框选择功能
   - 增强JavaScript部分，实现选择费用明细后自动按费用类型分组显示标签
   - 移除费用类型下拉列表

2. 实现逻辑：
   - 当用户选择费用明细时，获取每个费用明细的费用类型
   - 按费用类型分组，统计每种费用类型下的费用明细数量
   - 以标签形式显示每种费用类型及其对应的费用明细数量

### 2. 问题类型多选实现

1. 修改 `app/views/admin/shared/_fee_details_selection.html.erb` 文件：
   - 将问题类型选择从单选改为复选框
   - 按费用类型分组显示问题类型复选框
   - 实现选择费用类型标签后加载对应的问题类型复选框

2. 实现逻辑：
   - 根据显示的费用类型标签，从服务器获取对应的问题类型列表
   - 按费用类型分组显示问题类型复选框
   - 允许用户选择多个问题类型

### 3. 移除审核意见自动填充

1. 修改 `app/services/work_order_service.rb` 文件：
   - 移除 `assign_shared_attributes` 方法中自动填充审核意见的代码
   - 保留处理意见与状态关系的逻辑

### 4. 保留处理意见与工单状态的关系

1. 保留 `app/models/work_order.rb` 中的 `set_status_based_on_processing_opinion` 方法
2. 保留 `app/services/work_order_service.rb` 中的状态处理逻辑

## 实现步骤

### 1. 修改费用明细选择部分

修改 `app/views/admin/shared/_fee_details_selection.html.erb` 文件，实现费用类型标签分组显示：

```html
<%# 费用类型分组标签 %>
<div class="fee-type-tags" id="fee-type-tags">
  <h4>已选费用类型</h4>
  <div class="fee-type-tags-container"></div>
</div>
```

添加JavaScript代码实现费用类型标签功能：

```javascript
// 更新费用类型标签
function updateFeeTypeTags() {
  feeTypeTagsContainer.innerHTML = '';
  
  if (Object.keys(feeTypeGroups).length === 0) {
    feeTypeTagsContainer.innerHTML = '<p>未选择费用明细</p>';
    problemTypesContainer.style.display = 'none';
    return;
  }
  
  for (const feeType in feeTypeGroups) {
    const tagDiv = document.createElement('div');
    tagDiv.className = 'fee-type-tag';
    tagDiv.dataset.feeType = feeType;
    tagDiv.textContent = `${feeType} (${feeTypeGroups[feeType].length}项)`;
    feeTypeTagsContainer.appendChild(tagDiv);
  }
  
  problemTypesContainer.style.display = 'block';
}
```

### 2. 修改问题类型选择部分

修改 `app/views/admin/shared/_fee_details_selection.html.erb` 文件，实现问题类型复选框：

```html
<%# 问题类型选择区域 %>
<div class="problem-types-container" id="problem-types-container" style="display:none;">
  <h4>选择问题类型</h4>
  <div class="problem-types-wrapper"></div>
</div>
```

添加JavaScript代码实现问题类型复选框功能：

```javascript
// 加载问题类型
function loadProblemTypes() {
  problemTypesWrapper.innerHTML = '';
  
  if (Object.keys(feeTypeGroups).length === 0) {
    return;
  }
  
  // 获取所有相关费用类型的ID
  const feeTypeIds = Object.keys(feeTypeGroups).map(feeType => {
    return getFeeTypeIdByName(feeType);
  }).filter(id => id);
  
  if (feeTypeIds.length === 0) {
    return;
  }
  
  // 按费用类型获取问题类型
  fetch('/admin/problem_types.json?fee_type_ids=' + feeTypeIds.join(','))
    .then(response => response.json())
    .then(data => {
      // 按费用类型分组显示问题类型
      const groupedProblemTypes = groupProblemTypesByFeeType(data);
      
      for (const feeTypeId in groupedProblemTypes) {
        const feeTypeName = getFeeTypeNameById(feeTypeId);
        const problemTypes = groupedProblemTypes[feeTypeId];
        
        // 创建费用类型分组
        const sectionDiv = document.createElement('div');
        sectionDiv.className = 'problem-type-section';
        
        // 创建费用类型标题
        const feeTypeTitle = document.createElement('h5');
        feeTypeTitle.textContent = feeTypeName;
        sectionDiv.appendChild(feeTypeTitle);
        
        // 创建问题类型复选框容器
        const checkboxContainer = document.createElement('div');
        checkboxContainer.className = 'problem-type-checkboxes';
        
        problemTypes.forEach(problemType => {
          const checkboxDiv = document.createElement('div');
          checkboxDiv.className = 'problem-type-checkbox';
          
          const checkbox = document.createElement('input');
          checkbox.type = 'checkbox';
          checkbox.id = `problem_type_${problemType.id}`;
          checkbox.name = 'audit_work_order[problem_type_ids][]';
          checkbox.value = problemType.id;
          
          const label = document.createElement('label');
          label.htmlFor = `problem_type_${problemType.id}`;
          label.textContent = problemType.display_name;
          
          checkboxDiv.appendChild(checkbox);
          checkboxDiv.appendChild(label);
          checkboxContainer.appendChild(checkboxDiv);
        });
        
        sectionDiv.appendChild(checkboxContainer);
        problemTypesWrapper.appendChild(sectionDiv);
      }
    });
}
```

### 3. 修改WorkOrderService

修改 `app/services/work_order_service.rb` 文件，移除审核意见自动填充功能：

```ruby
def assign_shared_attributes(params)
  shared_attr_keys = [
    :remark, :processing_opinion, :audit_comment,
    :problem_type_id, :fee_type_id,
    # AuditWorkOrder specific fields that are now shared due to alignment
    :audit_result # audit_result if it's set directly, though status implies it
                                 # For CommunicationWorkOrder, these would be nil or handled by model defaults if any
  ]
  
  attrs_to_assign = params.slice(*shared_attr_keys.select { |key| params.key?(key) })
  
  # Ensure audit_result is not directly assigned if it's purely driven by status
  # If audit_result is a direct input field (e.g. from a form for specific cases), this is fine.
  # But our current design: status implies audit_result ('approved'/'rejected')
  attrs_to_assign.delete(:audit_result) # Let status dictate this, model has audit_result column for db persistence
  
  # Handle fee_type_id separately - it's not directly stored but used to filter problem_types
  fee_type_id = attrs_to_assign.delete(:fee_type_id)
  submitted_fee_detail_ids = attrs_to_assign.delete(:submitted_fee_detail_ids)
  
  # Assign the remaining attributes
  @work_order.assign_attributes(attrs_to_assign) if attrs_to_assign.present?
  
  # 处理费用明细选择
  if submitted_fee_detail_ids.present?
    process_fee_detail_selections(submitted_fee_detail_ids)
  end
  
  # 移除自动填充审核意见的代码
  # 保留费用类型和问题类型关联的处理
  if fee_type_id.present?
    @work_order.fee_type_id = fee_type_id
    
    # If problem_type_id is not set but fee_type_id is provided, try to find a default problem_type
    if !@work_order.problem_type_id.present?
      # Find the first active problem_type for this fee_type
      default_problem_type = ProblemType.active.where(fee_type_id: fee_type_id).first
      @work_order.problem_type_id = default_problem_type.id if default_problem_type
    end
  end
end
```

## 测试计划

1. 费用明细选择测试：
   - 选择多个不同费用类型的费用明细，验证费用类型标签是否正确显示
   - 取消选择费用明细，验证费用类型标签是否正确更新

2. 问题类型多选测试：
   - 验证问题类型是否按费用类型分组显示
   - 选择多个问题类型，验证是否能正确保存
   - 编辑工单时，验证已选问题类型是否正确显示

3. 处理意见与状态关系测试：
   - 设置处理意见为"可以通过"，验证工单状态是否变为"approved"
   - 设置处理意见为"无法通过"，验证工单状态是否变为"rejected"

4. 审核意见测试：
   - 验证审核意见不再自动填充
   - 手动输入审核意见，验证是否能正确保存

## 结论

通过以上调整，我们可以实现客户的新需求，使工单表单的界面交互更加符合客户的期望。同时，我们保留了处理意见与工单状态的关系，确保系统的核心逻辑不变。