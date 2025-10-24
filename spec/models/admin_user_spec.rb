require 'rails_helper'

# Complex query logic has been migrated to AdminUserRepository
# See: spec/repositories/admin_user_repository_spec.rb
#
# The following functionality is now tested in the repository layer:
# - find_by_name_substring method and all its edge cases
# - Complex queries for user filtering and workload management
#
# This model test now focuses on core model behavior:
# - Validations
# - Associations
# - Basic model methods
# - Devise integration
# Following the new architecture pattern of separating concerns across layers

RSpec.describe AdminUser, type: :model do
  describe 'associations' do
    it { should have_many(:work_order_operations).dependent(:nullify) }
    it { should have_many(:assigned_reimbursements).class_name('ReimbursementAssignment').with_foreign_key('assignee_id') }
    it { should have_many(:active_assigned_reimbursements).class_name('ReimbursementAssignment').with_foreign_key('assignee_id') }
    it { should have_many(:reimbursements_to_process).through(:active_assigned_reimbursements).source(:reimbursement) }
    it { should have_many(:reimbursement_assignments_made).class_name('ReimbursementAssignment').with_foreign_key('assigner_id') }
  end

  describe 'enums' do
    it 'defines role enum' do
      expect(AdminUser.roles).to include('admin' => 'admin', 'super_admin' => 'super_admin', 'regular' => 'regular')
    end

    it 'defines status enum' do
      expect(AdminUser.statuses).to include('active' => 'active', 'inactive' => 'inactive', 'suspended' => 'suspended', 'deleted' => 'deleted')
    end
  end

  describe 'scopes' do
    let!(:active_user) { create(:admin_user, :active) }
    let!(:inactive_user) { create(:admin_user, :inactive) }
    let!(:suspended_user) { create(:admin_user, :suspended) }
    let!(:deleted_user) { create(:admin_user, :deleted) }

    describe '.available' do
      it 'returns users who are not deleted' do
        result = AdminUser.available
        expect(result).to include(active_user, inactive_user, suspended_user)
        expect(result).not_to include(deleted_user)
      end
    end

    describe '.active_users' do
      it 'returns only active users' do
        result = AdminUser.active_users
        expect(result).to include(active_user)
        expect(result).not_to include(inactive_user, suspended_user, deleted_user)
      end
    end
  end

  describe 'instance methods' do
    let(:admin_user) { create(:admin_user) }

    describe '#status_display' do
      it 'returns Chinese display names for statuses' do
        admin_user.update!(status: 'active')
        expect(admin_user.status_display).to eq('活跃')

        admin_user.update!(status: 'inactive')
        expect(admin_user.status_display).to eq('非活跃')

        admin_user.update!(status: 'suspended')
        expect(admin_user.status_display).to eq('暂停')

        admin_user.update!(status: 'deleted')
        expect(admin_user.status_display).to eq('已删除')
      end
    end

    describe '#soft_delete' do
      it 'marks user as deleted and sets deleted_at' do
        expect {
          admin_user.soft_delete
        }.to change { admin_user.status }.to('deleted')
         .and change { admin_user.deleted_at }.from(nil)
      end
    end

    describe '#restore' do
      before { admin_user.update!(status: 'deleted', deleted_at: 1.day.ago) }

      it 'restores user to active status and clears deleted_at' do
        expect {
          admin_user.restore
        }.to change { admin_user.status }.to('active')
         .and change { admin_user.deleted_at }.to(nil)
      end
    end

    describe '#deleted?' do
      it 'returns true when status is deleted' do
        admin_user.update!(status: 'deleted')
        expect(admin_user.deleted?).to be true
      end

      it 'returns true when deleted_at is present' do
        admin_user.update!(deleted_at: 1.day.ago)
        expect(admin_user.deleted?).to be true
      end

      it 'returns false when user is not deleted' do
        expect(admin_user.deleted?).to be false
      end
    end

    describe '#active_for_authentication?' do
      it 'returns true for active users' do
        admin_user.update!(status: 'active')
        expect(admin_user.active_for_authentication?).to be true
      end

      it 'returns false for non-active users' do
        admin_user.update!(status: 'inactive')
        expect(admin_user.active_for_authentication?).to be false
      end
    end
  end

  describe 'callbacks' do
    context 'when creating first user in non-test environment' do
      it 'assigns super admin role' do
        allow(Rails.env).to receive(:test?).and_return(false)

        user = build(:admin_user, role: 'admin')

        expect {
          user.save!
        }.to change { user.role }.from('admin').to('super_admin')
      end
    end

    describe '#set_default_role' do
      it 'sets default role to admin when role is not specified' do
        user = build(:admin_user, role: nil)

        expect {
          user.save!
        }.to change { user.role }.to('admin')
      end
    end
  end

  describe 'ransackable attributes' do
    it 'returns searchable attributes' do
      expected_attributes = %w[created_at email encrypted_password id id_value name telephone
                               remember_created_at reset_password_sent_at reset_password_token
                               updated_at role status deleted_at]
      expect(AdminUser.ransackable_attributes).to match_array(expected_attributes)
    end
  end

  describe 'ransackable associations' do
    it 'returns searchable associations' do
      expected_associations = %w[active_assigned_reimbursements assigned_reimbursements
                                 reimbursement_assignments_made reimbursements_to_process
                                 work_order_operations]
      expect(AdminUser.ransackable_associations).to match_array(expected_associations)
    end
  end
end
