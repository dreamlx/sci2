require 'rails_helper'

RSpec.describe AdminUserRepository, type: :repository do
  let!(:admin_user1) { create(:admin_user, name: 'John Doe') }
  let!(:admin_user2) { create(:admin_user, name: 'Jane Smith') }
  let!(:admin_user3) { create(:admin_user, name: 'Bob Johnson') }

  describe '.find_by_name_substring' do
    context 'when the string contains the exact admin user name' do
      it 'returns the admin user' do
        result = AdminUserRepository.find_by_name_substring('John Doe')
        expect(result).to eq(admin_user1)
      end
    end

    context 'when the string contains the admin user name as a substring' do
      it 'returns the admin user when name is embedded in larger string' do
        result = AdminUserRepository.find_by_name_substring('Dr. John Doe Jr.')
        expect(result).to eq(admin_user1)
      end

      it 'returns the admin user when name is in the middle' do
        result = AdminUserRepository.find_by_name_substring('Bob Johnson Esq.')
        expect(result).to eq(admin_user3)
      end
    end

    context 'when name_substring does not match any user' do
      it 'returns nil' do
        result = AdminUserRepository.find_by_name_substring('Nonexistent User')
        expect(result).to be_nil
      end
    end

    context 'when name_substring is blank' do
      it 'returns nil' do
        result = AdminUserRepository.find_by_name_substring('')
        expect(result).to be_nil
      end

      it 'returns nil when nil' do
        result = AdminUserRepository.find_by_name_substring(nil)
        expect(result).to be_nil
      end
    end

    context 'when multiple users match' do
      let!(:admin_user4) { create(:admin_user, name: 'Jane') }

      it 'returns the first matching user (by database order)' do
        result = AdminUserRepository.find_by_name_substring('Jane Smith and Jane Doe')
        expect([admin_user2, admin_user4]).to include(result)
      end
    end
  end

  describe '.available_users' do
    let!(:deleted_user) { create(:admin_user, :deleted) }
    let!(:suspended_user) { create(:admin_user, :suspended) }

    it 'returns users who are not deleted' do
      result = AdminUserRepository.available_users

      expect(result).to include(admin_user1, admin_user2, admin_user3, suspended_user)
      expect(result).not_to include(deleted_user)
    end
  end

  describe '.active_users' do
    let!(:inactive_user) { create(:admin_user, :inactive) }
    let!(:deleted_user) { create(:admin_user, :deleted) }

    it 'returns only active users' do
      result = AdminUserRepository.active_users

      expect(result).to include(admin_user1, admin_user2, admin_user3)
      expect(result).not_to include(inactive_user, deleted_user)
    end
  end

  describe '.users_with_workload' do
    let!(:reimbursement1) { create(:reimbursement) }
    let!(:reimbursement2) { create(:reimbursement) }
    let!(:reimbursement3) { create(:reimbursement) }

    before do
      create(:reimbursement_assignment, reimbursement: reimbursement1, assignee: admin_user1)
      create(:reimbursement_assignment, reimbursement: reimbursement2, assignee: admin_user1)
      create(:reimbursement_assignment, reimbursement: reimbursement3, assignee: admin_user2)
    end

    it 'returns users with their workload count' do
      result = AdminUserRepository.users_with_workload

      user_with_workload = result.find { |u| u.id == admin_user1.id }
      expect(user_with_workload.workload.to_i).to eq(2)

      user_with_workload = result.find { |u| u.id == admin_user2.id }
      expect(user_with_workload.workload.to_i).to eq(1)
    end
  end

  describe '.by_role' do
    let!(:admin_user) { create(:admin_user, role: 'admin') }
    let!(:super_admin_user) { create(:admin_user, role: 'super_admin') }

    it 'returns users filtered by role' do
      result = AdminUserRepository.by_role('admin')
      expect(result).to include(admin_user)
      expect(result).not_to include(super_admin_user)
    end
  end

  describe '.available_for_assignment' do
    let!(:inactive_user) { create(:admin_user, :inactive) }
    let!(:deleted_user) { create(:admin_user, :deleted) }

    it 'returns only active users who can be assigned work' do
      result = AdminUserRepository.available_for_assignment

      expect(result).to include(admin_user1, admin_user2, admin_user3)
      expect(result).not_to include(inactive_user, deleted_user)
    end
  end
end