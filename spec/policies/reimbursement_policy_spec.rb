# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReimbursementPolicy, type: :policy do
  let(:super_admin) { create(:admin_user, role: 'super_admin') }
  let(:admin) { create(:admin_user, role: 'admin') }
  let(:reimbursement) { create(:reimbursement) }

  before do
    # Ensure the admin user is actually an admin, not promoted to super_admin
    admin.update!(role: 'admin') if admin.super_admin?
  end

  subject { described_class.new(user, reimbursement) }

  context 'when user is super admin' do
    let(:user) { super_admin }

    it 'allows all actions' do
      expect(subject.can_index?).to be true
      expect(subject.can_show?).to be true
      expect(subject.can_create?).to be true
      expect(subject.can_update?).to be true
      expect(subject.can_destroy?).to be true
    end

    it 'allows assignment operations' do
      expect(subject.can_assign?).to be true
      expect(subject.can_batch_assign?).to be true
      expect(subject.can_transfer_assignment?).to be true
      expect(subject.can_unassign?).to be true
    end

    it 'allows manual override operations' do
      expect(subject.can_manual_override?).to be true
      expect(subject.can_set_pending?).to be true
      expect(subject.can_set_processing?).to be true
      expect(subject.can_set_closed?).to be true
      expect(subject.can_reset_override?).to be true
    end

    it 'allows attachment operations' do
      expect(subject.can_upload_attachment?).to be true
    end

    it 'allows import/export operations' do
      expect(subject.can_import?).to be true
      expect(subject.can_export?).to be true
    end

    it 'allows all scope views' do
      expect(subject.can_view_assigned_to_me?).to be true
      expect(subject.can_view_all?).to be true
      expect(subject.can_view_unassigned?).to be true
      expect(subject.can_view_pending?).to be true
      expect(subject.can_view_processing?).to be true
      expect(subject.can_view_closed?).to be true
      expect(subject.can_view_with_unread_updates?).to be true
    end

    it 'shows all UI elements' do
      expect(subject.show_import_button?).to be true
      expect(subject.show_manual_override_section?).to be true
      expect(subject.show_assignment_controls?).to be true
      expect(subject.show_batch_actions?).to be true
      expect(subject.show_action_buttons?).to eq('primary_action')
    end

    it 'returns correct role display name' do
      expect(subject.role_display_name).to eq('超级管理员')
    end
  end

  context 'when user is regular admin' do
    let(:user) { admin }

    it 'allows basic read operations' do
      expect(subject.can_index?).to be true
      expect(subject.can_show?).to be true
      expect(subject.can_create?).to be false
      expect(subject.can_update?).to be false
      expect(subject.can_destroy?).to be false
    end

    it 'disallows assignment operations' do
      expect(subject.can_assign?).to be false
      expect(subject.can_batch_assign?).to be false
      expect(subject.can_transfer_assignment?).to be false
      expect(subject.can_unassign?).to be false
    end

    it 'disallows manual override operations' do
      expect(subject.can_manual_override?).to be false
      expect(subject.can_set_pending?).to be false
      expect(subject.can_set_processing?).to be false
      expect(subject.can_set_closed?).to be false
      expect(subject.can_reset_override?).to be false
    end

    it 'disallows attachment operations' do
      expect(subject.can_upload_attachment?).to be false
    end

    it 'allows export but not import' do
      expect(subject.can_import?).to be false
      expect(subject.can_export?).to be true
    end

    it 'allows basic scope views' do
      expect(subject.can_view_assigned_to_me?).to be true
      expect(subject.can_view_all?).to be false
      expect(subject.can_view_unassigned?).to be false
      expect(subject.can_view_pending?).to be true
      expect(subject.can_view_processing?).to be true
      expect(subject.can_view_closed?).to be true
      expect(subject.can_view_with_unread_updates?).to be true
    end

    it 'hides admin-only UI elements' do
      expect(subject.show_import_button?).to be false
      expect(subject.show_manual_override_section?).to be false
      expect(subject.show_assignment_controls?).to be false
      expect(subject.show_batch_actions?).to be false
      expect(subject.show_action_buttons?).to eq('disabled_action')
    end

    it 'returns correct role display name' do
      expect(subject.role_display_name).to eq('管理员')
    end
  end

  
  context 'when user is nil' do
    let(:user) { nil }

    it 'disallows all operations' do
      expect(subject.can_index?).to be false
      expect(subject.can_show?).to be false
      expect(subject.can_create?).to be false
      expect(subject.can_update?).to be false
      expect(subject.can_destroy?).to be false
    end

    it 'returns unknown role display name' do
      expect(subject.role_display_name).to eq('未知角色')
    end
  end

  describe 'authorization error messages' do
    let(:user) { admin }

    it 'returns appropriate error messages for different actions' do
      expect(subject.authorization_error_message(action: :assign))
        .to eq('您没有权限执行分配操作，请联系超级管理员')
      expect(subject.authorization_error_message(action: :manual_override))
        .to eq('您没有权限执行手动状态覆盖操作，请联系超级管理员')
      expect(subject.authorization_error_message(action: :create))
        .to eq('您没有权限执行此操作，请联系超级管理员')
      expect(subject.authorization_error_message(action: :upload_attachment))
        .to eq('您没有权限上传附件，请联系超级管理员')
    end
  end

  describe 'class methods' do
    it 'provides quick permission checks' do
      expect(described_class.can_index?(super_admin)).to be true
      expect(described_class.can_show?(super_admin, reimbursement)).to be true
      expect(described_class.can_assign?(super_admin)).to be true
      expect(described_class.can_manual_override?(super_admin)).to be true
      expect(described_class.can_import?(super_admin)).to be true

      expect(described_class.can_assign?(admin)).to be false
      expect(described_class.can_manual_override?(admin)).to be false
      expect(described_class.can_import?(admin)).to be false
    end
  end
end