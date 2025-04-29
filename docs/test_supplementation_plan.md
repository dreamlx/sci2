# 测试补充计划

根据对 `docs/999-SCI2工单系统测试计划_v3.md` 和现有测试代码的分析，我们需要补充以下测试用例以确保完整覆盖测试计划中的所有场景。

## 1. 审核工单测试补充 (AuditWorkOrder)

### 1.1 非法状态转换测试 (WF-A-007)

需要添加测试以验证系统能够正确处理非法状态转换尝试。具体测试代码如下：

```ruby
# 在 spec/models/audit_work_order_spec.rb 的 "state machine" describe 块中添加
context "when testing invalid transitions" do
  let(:reimbursement) { build_stubbed(:reimbursement) }
  
  it "cannot transition directly from pending to approved" do
    work_order = build(:audit_work_order, reimbursement: reimbursement)
    expect(work_order.status).to eq("pending")
    
    # 尝试直接从 pending 转换到 approved 应该失败
    expect { work_order.approve! }.to raise_error(StateMachines::InvalidTransition)
    expect(work_order.status).to eq("pending") # 状态应保持不变
  end
  
  it "cannot transition directly from pending to rejected" do
    work_order = build(:audit_work_order, reimbursement: reimbursement)
    expect(work_order.status).to eq("pending")
    
    # 尝试直接从 pending 转换到 rejected 应该失败
    expect { work_order.reject! }.to raise_error(StateMachines::InvalidTransition)
    expect(work_order.status).to eq("pending") # 状态应保持不变
  end
end
```

### 1.2 状态变更记录测试 (WF-A-006)

需要添加测试以验证系统正确记录工单状态变更历史。具体测试代码如下：

```ruby
# 在 spec/models/audit_work_order_spec.rb 中添加新的 describe 块
describe "status change recording" do
  let(:reimbursement) { create(:reimbursement) }
  let(:admin_user) { create(:admin_user) }
  
  before do
    # 模拟 Current.admin_user
    allow(Current).to receive(:admin_user).and_return(admin_user)
  end
  
  it "records status change when transitioning from pending to processing" do
    work_order = create(:audit_work_order, reimbursement: reimbursement)
    expect {
      work_order.start_processing!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("pending")
    expect(status_change.to_status).to eq("processing")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
  
  it "records status change when transitioning from processing to approved" do
    work_order = create(:audit_work_order, :processing, reimbursement: reimbursement)
    expect {
      work_order.approve!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("processing")
    expect(status_change.to_status).to eq("approved")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
  
  it "records status change when transitioning from processing to rejected" do
    work_order = create(:audit_work_order, :processing, reimbursement: reimbursement)
    work_order.problem_type = "documentation_issue"
    
    expect {
      work_order.reject!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("processing")
    expect(status_change.to_status).to eq("rejected")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
end
```

## 2. 沟通工单测试补充 (CommunicationWorkOrder)

### 2.1 非法状态转换测试 (WF-C-007)

需要添加测试以验证系统能够正确处理非法状态转换尝试。具体测试代码如下：

```ruby
# 在 spec/models/communication_work_order_spec.rb 的 "state machine" describe 块中添加
context "when testing invalid transitions" do
  let(:reimbursement) { build_stubbed(:reimbursement) }
  
  it "cannot transition directly from pending to approved" do
    work_order = build(:communication_work_order, reimbursement: reimbursement)
    expect(work_order.status).to eq("pending")
    
    # 尝试直接从 pending 转换到 approved 应该失败
    expect { work_order.approve! }.to raise_error(StateMachines::InvalidTransition)
    expect(work_order.status).to eq("pending") # 状态应保持不变
  end
  
  it "cannot transition directly from pending to rejected" do
    work_order = build(:communication_work_order, reimbursement: reimbursement)
    expect(work_order.status).to eq("pending")
    
    # 尝试直接从 pending 转换到 rejected 应该失败
    expect { work_order.reject! }.to raise_error(StateMachines::InvalidTransition)
    expect(work_order.status).to eq("pending") # 状态应保持不变
  end
  
  it "cannot transition from processing to needs_communication" do
    work_order = build(:communication_work_order, :processing, reimbursement: reimbursement)
    expect(work_order.status).to eq("processing")
    
    # 尝试从 processing 转换到 needs_communication 应该失败
    expect { work_order.mark_needs_communication! }.to raise_error(StateMachines::InvalidTransition)
    expect(work_order.status).to eq("processing") # 状态应保持不变
  end
end
```

### 2.2 状态变更记录测试 (WF-C-006)

需要添加测试以验证系统正确记录工单状态变更历史。具体测试代码如下：

```ruby
# 在 spec/models/communication_work_order_spec.rb 中添加新的 describe 块
describe "status change recording" do
  let(:reimbursement) { create(:reimbursement) }
  let(:admin_user) { create(:admin_user) }
  
  before do
    # 模拟 Current.admin_user
    allow(Current).to receive(:admin_user).and_return(admin_user)
  end
  
  it "records status change when transitioning from pending to processing" do
    work_order = create(:communication_work_order, reimbursement: reimbursement)
    expect {
      work_order.start_processing!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("pending")
    expect(status_change.to_status).to eq("processing")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
  
  it "records status change when transitioning from pending to needs_communication" do
    work_order = create(:communication_work_order, reimbursement: reimbursement)
    expect {
      work_order.mark_needs_communication!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("pending")
    expect(status_change.to_status).to eq("needs_communication")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
  
  it "records status change when transitioning from processing to approved" do
    work_order = create(:communication_work_order, :processing, reimbursement: reimbursement)
    work_order.resolution_summary = "问题已解决"
    
    expect {
      work_order.approve!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("processing")
    expect(status_change.to_status).to eq("approved")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
  
  it "records status change when transitioning from needs_communication to rejected" do
    work_order = create(:communication_work_order, :needs_communication, reimbursement: reimbursement)
    work_order.problem_type = "documentation_issue"
    work_order.resolution_summary = "无法解决"
    
    expect {
      work_order.reject!
    }.to change(WorkOrderStatusChange, :count).by(1)
    
    status_change = work_order.work_order_status_changes.last
    expect(status_change.from_status).to eq("needs_communication")
    expect(status_change.to_status).to eq("rejected")
    expect(status_change.changer_id).to eq(admin_user.id)
    expect(status_change.changed_at).to be_present
  end
end
```

## 3. 实施建议

1. 将上述测试代码添加到相应的测试文件中
2. 确保工厂文件中有正确的 trait 定义，例如 `:processing` 和 `:needs_communication`
3. 运行测试以确保新添加的测试能够通过
4. 如果测试失败，检查模型实现是否符合测试计划中的要求

## 4. 测试覆盖情况总结

添加上述测试后，我们将完整覆盖测试计划中的以下测试场景：

- WF-A-006: 审核工单状态变更记录
- WF-A-007: 审核工单非法状态转换
- WF-C-006: 沟通工单状态变更记录
- WF-C-007: 沟通工单非法状态转换

这些测试将确保工单状态流转逻辑的正确性和完整性，以及状态变更历史的准确记录。