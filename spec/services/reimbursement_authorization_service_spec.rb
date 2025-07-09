require 'rails_helper'

RSpec.describe ReimbursementAuthorizationService, type: :service do
  # 先创建一个超级管理员来避免自动角色分配
  let!(:first_super_admin) { create(:admin_user, :super_admin) }
  let(:admin_user) { create(:admin_user, :admin) }
  let(:super_admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement1) { create(:reimbursement) }
  let!(:reimbursement2) { create(:reimbursement) }
  let!(:assignment) { create(:reimbursement_assignment, reimbursement: reimbursement1, assignee: admin_user, is_active: true) }
  
  describe '#can_assign?' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns false' do
        expect(service.can_assign?).to be false
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns true' do
        expect(service.can_assign?).to be true
      end
    end
  end
  
  describe '#can_view?' do
    let(:service) { described_class.new(admin_user) }
    
    it 'returns true for all users and reimbursements' do
      expect(service.can_view?).to be true
      expect(service.can_view?(reimbursement1)).to be true
      expect(service.can_view?(reimbursement2)).to be true
    end
  end
  
  describe '#can_edit?' do
    let(:service) { described_class.new(admin_user) }
    
    it 'returns true for all users and reimbursements' do
      expect(service.can_edit?).to be true
      expect(service.can_edit?(reimbursement1)).to be true
      expect(service.can_edit?(reimbursement2)).to be true
    end
  end
  
  describe '#can_delete?' do
    let(:service) { described_class.new(admin_user) }
    
    it 'returns true for all users and reimbursements' do
      expect(service.can_delete?).to be true
      expect(service.can_delete?(reimbursement1)).to be true
      expect(service.can_delete?(reimbursement2)).to be true
    end
  end
  
  describe '#default_scope' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns assigned_to_me' do
        expect(service.default_scope).to eq 'assigned_to_me'
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns all' do
        expect(service.default_scope).to eq 'all'
      end
    end
  end
  
  describe '#apply_role_based_default_filter' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'filters to assigned reimbursements' do
        result = service.apply_role_based_default_filter(Reimbursement.all)
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns all reimbursements' do
        result = service.apply_role_based_default_filter(Reimbursement.all)
        expect(result).to include(reimbursement1, reimbursement2)
      end
    end
  end
  
  describe '#should_show_assignment_ui?' do
    let(:service) { described_class.new(admin_user) }
    
    it 'always returns true' do
      expect(service.should_show_assignment_ui?).to be true
    end
  end
  
  describe '#assignment_button_class' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns disabled_action' do
        expect(service.assignment_button_class).to eq 'disabled_action'
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns primary_action' do
        expect(service.assignment_button_class).to eq 'primary_action'
      end
    end
  end
  
  describe '#assignment_permission_message' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns permission denied message' do
        expect(service.assignment_permission_message).to eq '您没有权限执行分配操作，请联系超级管理员'
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns nil' do
        expect(service.assignment_permission_message).to be_nil
      end
    end
  end
  
  describe '#apply_scope_filter' do
    let(:service) { described_class.new(admin_user) }
    let(:collection) { Reimbursement.all }
    
    context 'with status scopes (default behavior)' do
      before do
        reimbursement1.update(status: 'pending')
        reimbursement2.update(status: 'processing')
      end
      
      it 'filters by pending status' do
        result = service.apply_scope_filter(collection, 'pending')
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
      
      it 'filters by processing status' do
        result = service.apply_scope_filter(collection, 'processing')
        # 对于普通管理员，processing scope 应该只返回分配给他们且状态为 processing 的报销单
        # reimbursement2 状态是 processing 但没有分配给 admin_user，所以不应该包含
        expect(result).not_to include(reimbursement2)
        expect(result).not_to include(reimbursement1)
      end
    end
    
    context 'with status scopes and global view enabled' do
      before do
        reimbursement1.update(status: 'pending')
        reimbursement2.update(status: 'pending')
      end
      
      it 'filters by status only when global_view is true' do
        result = service.apply_scope_filter(collection, 'pending', { global_view: 'true' })
        expect(result).to include(reimbursement1, reimbursement2)
        expect(result.count).to eq(2)
      end
    end
    
    context 'with assigned_to_me scope' do
      it 'filters to assigned reimbursements' do
        result = service.apply_scope_filter(collection, 'assigned_to_me')
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
    end
    
    context 'with unassigned scope' do
      it 'filters to unassigned reimbursements by default' do
        result = service.apply_scope_filter(collection, 'unassigned')
        # 对于普通管理员，unassigned scope 应该返回空集合
        # 因为未分配的报销单意味着不是分配给他们的
        expect(result).to be_empty
        expect(result).not_to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
      
      it 'returns unassigned reimbursements when global view is enabled' do
        result = service.apply_scope_filter(collection, 'unassigned', { global_view: 'true' })
        expect(result).to include(reimbursement2)
        expect(result).not_to include(reimbursement1)
      end
    end
    
    context 'with all scope' do
      it 'returns assigned reimbursements by default' do
        result = service.apply_scope_filter(collection, 'all')
        # 对于普通管理员，即使选择 "all" scope 也只能看到分配给自己的报销单
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
      
      it 'returns all reimbursements when global view is enabled' do
        result = service.apply_scope_filter(collection, 'all', { global_view: 'true' })
        expect(result).to include(reimbursement1, reimbursement2)
        expect(result.count).to eq(2)
      end
    end
    
    context 'with global_all scope' do
      it 'returns all reimbursements for admin users' do
        result = service.apply_scope_filter(collection, 'global_all')
        expect(result).to include(reimbursement1, reimbursement2)
        expect(result.count).to eq(2)
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      before do
        reimbursement1.update(status: 'pending')
        reimbursement2.update(status: 'processing')
      end
      
      it 'filters by pending status for super_admin' do
        result = service.apply_scope_filter(collection, 'pending')
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
      
      it 'filters by processing status for super_admin' do
        result = service.apply_scope_filter(collection, 'processing')
        expect(result).to include(reimbursement2)
        expect(result).not_to include(reimbursement1)
      end
      
      it 'shows unassigned reimbursements for super_admin' do
        result = service.apply_scope_filter(collection, 'unassigned')
        expect(result).to include(reimbursement2)
        expect(result).not_to include(reimbursement1)
      end
      
      it 'shows all reimbursements for super_admin' do
        result = service.apply_scope_filter(collection, 'all')
        expect(result).to include(reimbursement1, reimbursement2)
      end
      
      it 'shows all reimbursements for global_all scope' do
        result = service.apply_scope_filter(collection, 'global_all')
        expect(result).to include(reimbursement1, reimbursement2)
        expect(result.count).to eq(2)
      end
    end
    
    context 'with no scope' do
      it 'applies role-based default filter' do
        result = service.apply_scope_filter(collection, nil)
        expect(result).to include(reimbursement1)
        expect(result).not_to include(reimbursement2)
      end
    end
  end
  
  describe '#role_display_name' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns 普通管理员' do
        expect(service.role_display_name).to eq '普通管理员'
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns 超级管理员' do
        expect(service.role_display_name).to eq '超级管理员'
      end
    end
  end
  
  describe '#should_show_default_scope_notice?' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns true' do
        expect(service.should_show_default_scope_notice?).to be true
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns false' do
        expect(service.should_show_default_scope_notice?).to be false
      end
    end
  end
  
  describe '#default_scope_notice' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns notice message' do
        expect(service.default_scope_notice).to eq '默认显示分配给您的报销单。您可以使用搜索和过滤功能查看其他报销单。'
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns nil' do
        expect(service.default_scope_notice).to be_nil
      end
    end
  end
  
  # 新增：全局视图相关测试
  describe '#should_use_global_view?' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns false by default' do
        expect(service.should_use_global_view?({})).to be false
      end
      
      it 'returns true when global_view param is true' do
        expect(service.should_use_global_view?({ global_view: 'true' })).to be true
      end
      
      it 'returns true when scope is global_all' do
        expect(service.should_use_global_view?({ scope: 'global_all' })).to be true
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns true by default (super admins always have global view)' do
        expect(service.should_use_global_view?({})).to be true
      end
    end
  end
  
  describe '#can_use_global_view?' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns true' do
        expect(service.can_use_global_view?).to be true
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns true' do
        expect(service.can_use_global_view?).to be true
      end
    end
  end
  
  describe '#global_view_notice' do
    context 'with admin user' do
      let(:service) { described_class.new(admin_user) }
      
      it 'returns appropriate notice for admin users' do
        expect(service.global_view_notice).to eq('当前为全局视图模式，您可以查看所有报销单数据')
      end
    end
    
    context 'with super_admin user' do
      let(:service) { described_class.new(super_admin_user) }
      
      it 'returns nil for super admin users (they always have global view)' do
        expect(service.global_view_notice).to be_nil
      end
    end
  end
end