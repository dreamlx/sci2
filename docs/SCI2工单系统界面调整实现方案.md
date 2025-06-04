# SCI2工单系统界面调整实现方案

基于《SCI2工单系统界面调整方案》中的需求分析，本文档提供详细的实现方案，包括具体的代码修改。

## 1. 修改费用明细选择与费用类型标签

### 1.1 修改 `app/views/admin/shared/_fee_details_selection.html.erb`

现有的费用明细选择部分已经实现了复选框选择功能，我们需要增强它以支持费用类型标签分组显示。

```html
<%# 费用类型分组标签 %>
<div class="fee-type-tags" id="fee-type-tags">
  <h4>已选费用类型</h4>
  <div class="fee-type-tags-container"></div>
</div>

<%# 问题类型选择区域 %>
<div class="problem-types-container" id="problem-types-container" style="display:none;">
  <h4>选择问题类型</h4>
  <div class="problem-types-wrapper"></div>
</div>
```

### 1.2 添加CSS样式

```css
/* 费用类型标签样式 */
.fee-type-tags {
  margin-top: 20px;
  border: 1px solid #ddd;
  padding: 10px;
  border-radius: 4px;
}

.fee-type-tags h4 {
  margin-top: 0;
  margin-bottom: 10px;
  font-size: 16px;
}

.fee-type-tags-container {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.fee-type-tag {
  background-color: #f0f0f0;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 5px 10px;
  font-size: 14px;
  display: inline-block;
}

/* 问题类型复选框样式 */
.problem-types-container {
  margin-top: 20px;
  border: 1px solid #ddd;
  padding: 10px;
  border-radius: 4px;
}

.problem-types-container h4 {
  margin-top: 0;
  margin-bottom: 10px;
  font-size: 16px;
}

.problem-types-wrapper {
  margin-top: 10px;
  max-height: 300px;
  overflow-y: auto;
}

.problem-type-section {
  margin-bottom: 15px;
  padding-bottom: 10px;
  border-bottom: 1px solid #eee;
}

.problem-type-section h5 {
  margin-top: 10px;
  margin-bottom: 5px;
  padding-bottom: 5px;
  font-size: 14px;
  font-weight: bold;
}

.problem-type-checkboxes {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.problem-type-checkbox {
  display: flex;
  align-items: center;
  margin-right: 15px;
  margin-bottom: 5px;
}

.problem-type-checkbox input {
  margin-right: 5px;
}

.problem-type-checkbox label {
  font-size: 13px;
  cursor: pointer;
}
### 1.3 添加JavaScript代码

```javascript
document.addEventListener('DOMContentLoaded', function() {
  const feeDetailCheckboxes = document.querySelectorAll('.fee-detail-checkbox');
  const feeTypeTagsContainer = document.querySelector('.fee-type-tags-container');
  const problemTypesContainer = document.getElementById('problem-types-container');
  const problemTypesWrapper = document.querySelector('.problem-types-wrapper');
  
  // 存储选中的费用明细
  let selectedFeeDetails = [];
  
  // 存储费用类型分组
  let feeTypeGroups = {};
  
  // 存储费用类型ID映射
  let feeTypeNameToIdMap = {};
  let feeTypeIdToNameMap = {};
  
  // 监听费用明细复选框变化
  feeDetailCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', function() {
      updateSelectedFeeDetails();
      updateFeeTypeTags();
      loadProblemTypes();
    });
  });
  
  // 更新选中的费用明细
  function updateSelectedFeeDetails() {
    selectedFeeDetails = [];
    feeTypeGroups = {};
    
    feeDetailCheckboxes.forEach(checkbox => {
      if (checkbox.checked) {
        const feeDetailId = checkbox.value;
        const feeType = checkbox.dataset.feeType;
        
        selectedFeeDetails.push({
          id: feeDetailId,
          feeType: feeType
        });
        
        // 按费用类型分组
        if (!feeTypeGroups[feeType]) {
          feeTypeGroups[feeType] = [];
        }
        feeTypeGroups[feeType].push(feeDetailId);
      }
    });
  }
  
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
            checkbox.dataset.problemTypeId = problemType.id;
            
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
      })
      .catch(error => console.error('Error fetching problem types:', error));
  }
  
  // 辅助函数：按费用类型分组问题类型
  function groupProblemTypesByFeeType(problemTypes) {
    const grouped = {};
    
    problemTypes.forEach(problemType => {
      const feeTypeId = problemType.fee_type_id;
      
      if (!grouped[feeTypeId]) {
        grouped[feeTypeId] = [];
      }
      
      grouped[feeTypeId].push(problemType);
    });
    
    return grouped;
  }
  
  // 辅助函数：根据费用类型名称获取ID
  function getFeeTypeIdByName(name) {
    return feeTypeNameToIdMap[name] || null;
  }
  
  // 辅助函数：根据费用类型ID获取名称
  function getFeeTypeNameById(id) {
    return feeTypeIdToNameMap[id] || '未知费用类型';
  }
  
  // 预加载费用类型映射关系
  fetch('/admin/fee_types.json')
    .then(response => response.json())
    .then(data => {
      data.forEach(feeType => {
        feeTypeNameToIdMap[feeType.title] = feeType.id;
        feeTypeIdToNameMap[feeType.id] = feeType.title;
      });
      
      // 初始化
      updateSelectedFeeDetails();
      updateFeeTypeTags();
      
      // 如果已有选中的费用明细，加载问题类型
      if (Object.keys(feeTypeGroups).length > 0) {
        loadProblemTypes();
      }
    })
    .catch(error => console.error('Error fetching fee types:', error));
});
```

## 2. 修改 `app/admin/audit_work_orders.rb`

### 2.1 更新 `permit_params`

确保 `permit_params` 包含 `problem_type_ids` 数组：

```ruby
permit_params :reimbursement_id, :audit_comment, # resolution & audit_date are set by system, creator_id by controller
              :vat_verified,
              # 共享字段 - 使用 _id 后缀
              :remark, :processing_opinion,
              submitted_fee_detail_ids: [], problem_type_ids: []
```

### 2.2 更新 `create` 和 `update` 方法

确保 `create` 和 `update` 方法正确处理 `problem_type_ids` 参数：

```ruby
# Updated create action
def create
  # Permit submitted_fee_detail_ids along with other attributes
  # Parameters should align with the main permit_params, using _id for problem type
  _audit_work_order_params = params.require(:audit_work_order).permit(
    :reimbursement_id, :audit_comment, # resolution & audit_date are set by system
    :remark, :processing_opinion,
    submitted_fee_detail_ids: [], problem_type_ids: []
  )

  @audit_work_order = AuditWorkOrder.new(_audit_work_order_params.except(:submitted_fee_detail_ids, :problem_type_ids))
  @audit_work_order.created_by = current_admin_user.id # MODIFIED: Use created_by instead of creator_id

  if _audit_work_order_params[:submitted_fee_detail_ids].present?
    # Set the special instance variable for the callback in WorkOrder model
    @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _audit_work_order_params[:submitted_fee_detail_ids])
    # Also set the accessor for form repopulation if validation fails and we re-render new
    @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids]
  end
  
  # 设置问题类型IDs
  if _audit_work_order_params[:problem_type_ids].present?
    @audit_work_order.problem_type_ids = _audit_work_order_params[:problem_type_ids]
  end
  
  if @audit_work_order.save
    redirect_to admin_audit_work_order_path(@audit_work_order), notice: "审核工单已成功创建"
  else
    Rails.logger.debug "AuditWorkOrder save failed. Errors: #{@audit_work_order.errors.full_messages.inspect}" # DEBUG LINE
    # Re-fetch reimbursement if save fails, needed for the form on render :new
    @reimbursement = Reimbursement.find_by(id: _audit_work_order_params[:reimbursement_id])
    # Ensure @_direct_submitted_fee_ids is set for the callback if save is retried from a re-rendered form (though less likely)
    # and submitted_fee_detail_ids (accessor) is set for form repopulation.
    if _audit_work_order_params[:submitted_fee_detail_ids].present? 
      @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, _audit_work_order_params[:submitted_fee_detail_ids])
      @audit_work_order.submitted_fee_detail_ids = _audit_work_order_params[:submitted_fee_detail_ids]
    end
    # 重新设置问题类型IDs
    if _audit_work_order_params[:problem_type_ids].present?
      @audit_work_order.problem_type_ids = _audit_work_order_params[:problem_type_ids]
    end
    flash.now[:error] = "创建审核工单失败: #{@audit_work_order.errors.full_messages.join(', ')}"
    render :new
  end
end

# Update action
def update
  @audit_work_order = AuditWorkOrder.find(params[:id])
  service = AuditWorkOrderService.new(@audit_work_order, current_admin_user) # This service might be deprecated in favor of WorkOrderService
  
  update_params = audit_work_order_params_for_update
  if update_params[:submitted_fee_detail_ids].present?
    @audit_work_order.instance_variable_set(:@_direct_submitted_fee_ids, update_params[:submitted_fee_detail_ids])
    # For form repopulation on error, also set the accessor if it exists
    @audit_work_order.submitted_fee_detail_ids = update_params[:submitted_fee_detail_ids] if @audit_work_order.respond_to?(:submitted_fee_detail_ids=)
  end
  
  # 设置问题类型IDs
  if update_params[:problem_type_ids].present?
    @audit_work_order.problem_type_ids = update_params[:problem_type_ids]
  end

  # Use the centrally defined audit_work_order_params method for strong parameters
  # The service update method should ideally only take attributes for the model itself, not the fee IDs which are handled by callback
  if service.update(update_params.except(:submitted_fee_detail_ids, :problem_type_ids)) 
    redirect_to admin_audit_work_order_path(@audit_work_order), notice: '审核工单已更新'
  else
    # If update fails, @_direct_submitted_fee_ids might need to be preserved or reset for the form
    # For now, assume submitted_fee_detail_ids accessor helps repopulate via the form builder if re-rendering edit
    render :edit
  end
end
```
### 2.3 更新 `do_approve` 和 `do_reject` 方法

确保 `do_approve` 和 `do_reject` 方法正确处理 `problem_type_ids` 参数：

```ruby
member_action :do_approve, method: :post do
  # Use the base WorkOrderService
  service = WorkOrderService.new(resource, current_admin_user)
  # Params should align with what WorkOrderService and WorkOrder model expect
  # Ensure :processing_opinion is part of the permitted params for approval logic
  permitted_params = params.require(:audit_work_order).permit(
    :audit_comment, :processing_opinion,
    :remark, # Shared fields
    :vat_verified, # AuditWorkOrder specific, if still needed here
    problem_type_ids: []
  ).merge(processing_opinion: '可以通过') # Explicitly set for approval

  if service.approve(permitted_params)
    redirect_to admin_audit_work_order_path(resource), notice: "审核已通过"
  else
    @audit_work_order = resource # 重新赋值用于表单渲染
    flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
    render :approve
  end
end

member_action :do_reject, method: :post do
  # Use the base WorkOrderService
  service = WorkOrderService.new(resource, current_admin_user)
  # Params should align with what WorkOrderService and WorkOrder model expect
  # Ensure :processing_opinion is part of the permitted params for rejection logic
  permitted_params = params.require(:audit_work_order).permit(
    :audit_comment, :processing_opinion,
    :remark, # Shared fields
    :vat_verified, # AuditWorkOrder specific, if still needed here
    problem_type_ids: []
  ).merge(processing_opinion: '无法通过') # Explicitly set for rejection

  if service.reject(permitted_params)
    redirect_to admin_audit_work_order_path(resource), notice: "审核已拒绝"
  else
     @audit_work_order = resource # 重新赋值用于表单渲染
    flash.now[:alert] = "操作失败: #{resource.errors.full_messages.join(', ')}"
    render :reject
  end
end
```

### 2.4 更新表单JavaScript

修改表单中的JavaScript代码，以适应新的界面交互方式：

```javascript
document.addEventListener('DOMContentLoaded', function() {
  const processingOpinionSelect = document.getElementById('audit_work_order_processing_opinion');
  const auditCommentRow = document.getElementById('audit_comment_row');
  const remarkRow = document.getElementById('remark_row');
  const problemTypesContainer = document.getElementById('problem-types-container');
  
  // 切换字段显示
  function toggleFields() {
    if (!processingOpinionSelect || !auditCommentRow || !remarkRow) {
      return;
    }
    const selectedValue = processingOpinionSelect.value;
    
    auditCommentRow.style.display = 'none';
    remarkRow.style.display = 'none';
    
    if (selectedValue === '无法通过') {
      if (problemTypesContainer) {
        problemTypesContainer.style.display = 'block';
      }
      auditCommentRow.style.display = 'list-item';
      remarkRow.style.display = 'list-item';
    } else if (selectedValue === '可以通过') {
      if (problemTypesContainer) {
        problemTypesContainer.style.display = 'none';
      }
      auditCommentRow.style.display = 'list-item';
    } else { // Blank
      if (problemTypesContainer) {
        problemTypesContainer.style.display = 'none';
      }
      auditCommentRow.style.display = 'list-item';
    }
  }
  
  // 设置事件监听器
  if (processingOpinionSelect) {
    processingOpinionSelect.addEventListener('change', toggleFields);
    toggleFields();
  }
});
```

## 3. 修改 `app/services/work_order_service.rb`

### 3.1 移除审核意见自动填充功能

修改 `assign_shared_attributes` 方法，移除审核意见自动填充功能：

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
  
  # 处理费用类型和问题类型关联
  if fee_type_id.present?
    @work_order.fee_type_id = fee_type_id
    
    # If problem_type_id is not set but fee_type_id is provided, try to find a default problem_type
    if !@work_order.problem_type_id.present?
      # Find the first active problem_type for this fee_type
      default_problem_type = ProblemType.active.where(fee_type_id: fee_type_id).first
      @work_order.problem_type_id = default_problem_type.id if default_problem_type
    end
  end
  
  # 移除自动填充审核意见的代码
  # 以下代码被移除：
  # if @work_order.problem_type_id.present?
  #   problem_type = ProblemType.find_by(id: @work_order.problem_type_id)
  #   if problem_type && problem_type.standard_handling.present?
  #     if params.key?(:problem_type_id)
  #       @work_order.audit_comment = problem_type.standard_handling
  #     elsif !@work_order.audit_comment.present? || @work_order.audit_comment.blank?
  #       @work_order.audit_comment = problem_type.standard_handling
  #     end
  #   end
  # end
end
```

## 4. 修改 `app/admin/problem_types.rb`

### 4.1 更新JSON端点

确保 `problem_types.rb` 中的JSON端点支持按多个费用类型ID筛选：

```ruby
# 添加JSON端点
collection_action :index, format: :json do
  if params[:fee_type_id].present?
    # 单个费用类型查询
    @problem_types = ProblemType.active.by_fee_type(params[:fee_type_id])
  elsif params[:fee_type_ids].present?
    # 多个费用类型查询
    fee_type_ids = params[:fee_type_ids].split(',')
    @problem_types = ProblemType.active.where(fee_type_id: fee_type_ids)
  else
    @problem_types = ProblemType.active
  end
  
  render json: @problem_types.as_json(
    only: [:id, :code, :title, :fee_type_id, :sop_description, :standard_handling],
    methods: [:display_name]
  )
end
```

## 5. 修改 `app/admin/fee_types.rb`

### 5.1 确保JSON端点返回所需信息

```ruby
# 添加JSON端点
collection_action :index, format: :json do
  @fee_types = if params[:meeting_type].present?
                 FeeType.active.by_meeting_type(params[:meeting_type])
               else
                 FeeType.active
               end
  
  render json: @fee_types.as_json(
    only: [:id, :code, :title, :meeting_type],
    methods: [:display_name]
  )
end
```
## 6. 修改 `app/views/admin/audit_work_orders/approve.html.erb` 和 `app/views/admin/audit_work_orders/reject.html.erb`

### 6.1 更新审核通过表单

确保 `approve.html.erb` 包含问题类型多选字段：

```erb
<%= semantic_form_for @audit_work_order, url: do_approve_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs "审核通过" do %>
    <%= f.input :audit_comment, label: "审核意见", input_html: { rows: 5 } %>
    <%= f.input :remark, label: "备注", input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :hidden, input_html: { value: '可以通过' } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认通过" %>
    <%= link_to "取消", admin_audit_work_order_path(@audit_work_order), class: "cancel-link" %>
  <% end %>
<% end %>
```

### 6.2 更新审核拒绝表单

确保 `reject.html.erb` 包含问题类型多选字段：

```erb
<%= semantic_form_for @audit_work_order, url: do_reject_admin_audit_work_order_path(@audit_work_order), method: :post do |f| %>
  <%= f.inputs "审核拒绝" do %>
    <% if @audit_work_order.fee_details.any? %>
      <div class="fee-type-tags" id="fee-type-tags">
        <h4>费用类型</h4>
        <div class="fee-type-tags-container">
          <% @audit_work_order.fee_details.group_by(&:fee_type).each do |fee_type, details| %>
            <div class="fee-type-tag" data-fee-type="<%= fee_type %>">
              <%= fee_type %> (<%= details.length %>项)
            </div>
          <% end %>
        </div>
      </div>
      
      <div class="problem-types-container" id="problem-types-container">
        <h4>选择问题类型</h4>
        <div class="problem-types-wrapper">
          <% @audit_work_order.fee_details.group_by { |fd| fd.fee_type }.each do |fee_type, details| %>
            <% fee_type_id = FeeType.find_by(title: fee_type)&.id %>
            <% if fee_type_id %>
              <% problem_types = ProblemType.active.by_fee_type(fee_type_id) %>
              <div class="problem-type-section">
                <h5><%= fee_type %></h5>
                <div class="problem-type-checkboxes">
                  <% problem_types.each do |problem_type| %>
                    <div class="problem-type-checkbox">
                      <%= check_box_tag "audit_work_order[problem_type_ids][]", 
                                      problem_type.id, 
                                      @audit_work_order.problem_type_ids.include?(problem_type.id.to_s), 
                                      id: "problem_type_#{problem_type.id}" %>
                      <label for="problem_type_<%= problem_type.id %>"><%= problem_type.display_name %></label>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <%= f.input :audit_comment, label: "审核意见", input_html: { rows: 5 } %>
    <%= f.input :remark, label: "备注", input_html: { rows: 3 } %>
    <%= f.input :processing_opinion, as: :hidden, input_html: { value: '无法通过' } %>
  <% end %>
  <%= f.actions do %>
    <%= f.action :submit, label: "确认拒绝" %>
    <%= link_to "取消", admin_audit_work_order_path(@audit_work_order), class: "cancel-link" %>
  <% end %>
<% end %>
```

## 7. 测试计划

### 7.1 费用明细选择测试

1. 选择多个不同费用类型的费用明细，验证费用类型标签是否正确显示
2. 取消选择费用明细，验证费用类型标签是否正确更新

### 7.2 问题类型多选测试

1. 验证问题类型是否按费用类型分组显示
2. 选择多个问题类型，验证是否能正确保存
3. 编辑工单时，验证已选问题类型是否正确显示

### 7.3 处理意见与状态关系测试

1. 设置处理意见为"可以通过"，验证工单状态是否变为"approved"
2. 设置处理意见为"无法通过"，验证工单状态是否变为"rejected"

### 7.4 审核意见测试

1. 验证审核意见不再自动填充
2. 手动输入审核意见，验证是否能正确保存

## 8. 实施步骤

1. 备份当前代码
2. 修改 `app/views/admin/shared/_fee_details_selection.html.erb` 文件
3. 修改 `app/admin/audit_work_orders.rb` 文件
4. 修改 `app/services/work_order_service.rb` 文件
5. 修改 `app/admin/problem_types.rb` 文件
6. 修改 `app/admin/fee_types.rb` 文件
7. 修改 `app/views/admin/audit_work_orders/approve.html.erb` 和 `app/views/admin/audit_work_orders/reject.html.erb` 文件
8. 执行测试计划
9. 部署到生产环境

## 9. 注意事项

1. 确保所有JavaScript代码在不同浏览器中都能正常工作
2. 确保问题类型多选功能与现有的工单状态逻辑兼容
3. 确保费用类型标签显示与费用明细选择同步
4. 确保处理意见与工单状态的关系保持不变
5. 确保审核意见不再自动填充，但仍然可以手动输入

## 10. 结论

通过以上修改，我们可以实现客户的新需求，使工单表单的界面交互更加符合客户的期望。同时，我们保留了处理意见与工单状态的关系，确保系统的核心逻辑不变。