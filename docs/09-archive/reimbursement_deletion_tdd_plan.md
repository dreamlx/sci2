# 报销单删除功能TDD开发计划

## 功能需求
- 仅super_admin可删除报销单
- 无关联记录时直接删除
- 有关联记录时显示确认提示
- 提供"取消/确认删除"选项
- 确认后执行级联删除

## 测试用例设计
```ruby
RSpec.feature '报销单删除功能', type: :feature do
  let(:super_admin) { create(:admin_user, :super_admin) }
  let(:admin) { create(:admin_user) }

  # 场景1: 无关联记录的正常删除
  scenario '删除无关联记录的报销单' do
    reimbursement = create(:reimbursement)
    login_as(super_admin)
    visit admin_reimbursement_path(reimbursement)
    accept_confirm { click_link '删除报销单' }
    expect(page).to have_content('报销单已删除')
    expect(Reimbursement.count).to eq(0)
  end

  # 场景2: 有关联记录的警告流程
  scenario '尝试删除有关联记录的报销单' do
    reimbursement = create(:reimbursement_with_associations)
    login_as(super_admin)
    visit admin_reimbursement_path(reimbursement)
    click_link '删除报销单'
    expect(page).to have_selector('#reimbursement-deletion-confirmation')
    expect(page).to have_content('关联了以下记录')
  end

  # 场景3: 取消删除操作
  scenario '取消删除操作' do
    reimbursement = create(:reimbursement_with_associations)
    login_as(super_admin)
    visit admin_reimbursement_path(reimbursement)
    click_link '删除报销单'
    click_button '取消'
    expect(page).to have_content(reimbursement.invoice_number)
    expect(Reimbursement.count).to eq(1)
  end

  # 场景4: 权限验证
  scenario '普通管理员无权删除报销单' do
    reimbursement = create(:reimbursement)
    login_as(admin)
    visit admin_reimbursement_path(reimbursement)
    expect(page).not_to have_link('删除报销单')
  end
end
```

## 模型层实现
```ruby:app/models/reimbursement.rb
# 添加删除确认方法
def deletion_confirmation_required?
  fee_details.exists? || work_orders.exists?
end
```

## Admin界面增强
```ruby:app/admin/reimbursements.rb
# 添加条件式删除按钮
action_item :delete_reimbursement, only: :show, priority: 3 do
  next unless authorized?(:destroy, resource)  # 依赖cancancan权限控制

  if resource.deletion_confirmation_required?
    link_to '删除报销单', '#', 
            data: { 
              toggle: 'modal',
              target: '#reimbursement-deletion-confirmation'
            }
  else
    link_to '删除报销单', admin_reimbursement_path(resource), 
            method: :delete, 
            data: { confirm: '确定删除此报销单吗？' }
  end
end

# 添加确认模态框
render "deletion_confirmation_modal", resource: resource
```

## 前端交互组件
```erb:app/views/active_admin/reimbursements/_deletion_confirmation_modal.html.erb
<div id="reimbursement-deletion-confirmation" class="modal">
  <div class="modal-content">
    <h4>确认删除</h4>
    <p>该报销单关联了以下记录：</p>
    <ul>
      <% if resource.fee_details.any? %>
        <li>费用明细 (<%= resource.fee_details.count %>条)</li>
      <% end %>
      <% if resource.work_orders.any? %>
        <li>工单 (<%= resource.work_orders.count %>条)</li>
      <% end %>
    </ul>
    <p>删除后将无法恢复，是否继续？</p>
  </div>
  <div class="modal-footer">
    <a href="#!" class="modal-close btn">取消</a>
    <%= link_to '确认删除', admin_reimbursement_path(resource), 
                method: :delete, 
                class: 'btn red' %>
  </div>
</div>

<script>
  // 初始化模态框组件
  document.addEventListener('DOMContentLoaded', function() {
    var elems = document.querySelectorAll('.modal');
    M.Modal.init(elems);
  });
</script>
```

## 开发计划
1. 编写RSpec测试用例
2. 实现模型层`deletion_confirmation_required?`方法
3. 在ActiveAdmin中添加条件式删除按钮
4. 创建确认删除模态框组件
5. 添加JavaScript初始化逻辑
6. 验证所有测试通过
7. 部署前进行完整回归测试

## 安全考虑
- 双重权限验证：
  - 前端使用`authorized?(:destroy)`过滤
  - 后端控制器强制执行`authorize! :destroy` 
- 防止CSRF攻击：
  - 确保使用`method: :delete`
  - 包含Rails CSRF token