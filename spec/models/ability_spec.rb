# spec/models/ability_spec.rb
require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability do
  describe 'super_admin role' do
    let(:super_admin) { create(:admin_user, role: 'super_admin') }
    let(:ability) { Ability.new(super_admin) }

    context 'general permissions' do
      it 'can manage all resources' do
        expect(ability).to be_able_to(:manage, :all)
      end

      it 'can manage Reimbursement' do
        expect(ability).to be_able_to(:manage, Reimbursement)
      end

      it 'can manage WorkOrder' do
        expect(ability).to be_able_to(:manage, WorkOrder)
      end

      it 'can manage FeeDetail' do
        expect(ability).to be_able_to(:manage, FeeDetail)
      end

      it 'can manage AdminUser' do
        expect(ability).to be_able_to(:manage, AdminUser)
      end

      it 'can manage FeeType' do
        expect(ability).to be_able_to(:manage, FeeType)
      end

      it 'can manage ProblemType' do
        expect(ability).to be_able_to(:manage, ProblemType)
      end
    end

    context 'self-protection rules' do
      it 'cannot destroy themselves' do
        expect(ability).not_to be_able_to(:destroy, super_admin)
      end

      it 'can destroy other admin users' do
        other_admin = create(:admin_user, role: 'admin')
        expect(ability).to be_able_to(:destroy, other_admin)
      end

      it 'cannot soft_delete themselves' do
        expect(ability).not_to be_able_to(:soft_delete, super_admin)
      end

      it 'can soft_delete other admin users' do
        other_admin = create(:admin_user, role: 'admin')
        expect(ability).to be_able_to(:soft_delete, other_admin)
      end

      it 'cannot restore themselves' do
        expect(ability).not_to be_able_to(:restore, super_admin)
      end

      it 'can restore other admin users' do
        other_admin = create(:admin_user, role: 'admin')
        expect(ability).to be_able_to(:restore, other_admin)
      end
    end

    context 'soft delete permissions' do
      it 'can soft_delete admin users' do
        expect(ability).to be_able_to(:soft_delete, AdminUser)
      end

      it 'can restore admin users' do
        expect(ability).to be_able_to(:restore, AdminUser)
      end
    end

    context 'special operations' do
      it 'can import resources' do
        expect(ability).to be_able_to(:import, Reimbursement)
      end

      it 'can assign reimbursements' do
        reimbursement = create(:reimbursement)
        expect(ability).to be_able_to(:assign, reimbursement)
      end

      it 'can update_status for reimbursements' do
        reimbursement = create(:reimbursement)
        expect(ability).to be_able_to(:update_status, reimbursement)
      end

      it 'can upload_attachment for reimbursements' do
        reimbursement = create(:reimbursement)
        expect(ability).to be_able_to(:upload_attachment, reimbursement)
      end
    end
  end

  describe 'regular admin_user role' do
    let(:admin) { create(:admin_user, role: 'admin') }
    let(:ability) { Ability.new(admin) }

    context 'read permissions' do
      it 'can read all resources' do
        expect(ability).to be_able_to(:read, :all)
      end

      it 'can read Reimbursement' do
        expect(ability).to be_able_to(:read, Reimbursement)
      end

      it 'can read WorkOrder' do
        expect(ability).to be_able_to(:read, WorkOrder)
      end

      it 'can read FeeDetail' do
        expect(ability).to be_able_to(:read, FeeDetail)
      end

      it 'can read AdminUser' do
        expect(ability).to be_able_to(:read, AdminUser)
      end
    end

    context 'Reimbursement permissions' do
      let(:reimbursement) { create(:reimbursement) }

      it 'can create reimbursements' do
        expect(ability).to be_able_to(:create, Reimbursement)
      end

      it 'can update reimbursements' do
        expect(ability).to be_able_to(:update, reimbursement)
      end

      it 'can show reimbursements' do
        expect(ability).to be_able_to(:show, reimbursement)
      end

      it 'cannot destroy reimbursements' do
        expect(ability).not_to be_able_to(:destroy, reimbursement)
      end

      it 'cannot assign reimbursements' do
        expect(ability).not_to be_able_to(:assign, reimbursement)
      end

      it 'cannot update_status for reimbursements' do
        expect(ability).not_to be_able_to(:update_status, reimbursement)
      end

      it 'cannot upload_attachment for reimbursements' do
        expect(ability).not_to be_able_to(:upload_attachment, reimbursement)
      end
    end

    context 'WorkOrder permissions' do
      let(:work_order) { create(:communication_work_order) }

      it 'can create work orders' do
        expect(ability).to be_able_to(:create, WorkOrder)
      end

      it 'can update work orders' do
        expect(ability).to be_able_to(:update, work_order)
      end

      it 'can show work orders' do
        expect(ability).to be_able_to(:show, work_order)
      end

      it 'cannot destroy work orders' do
        expect(ability).not_to be_able_to(:destroy, work_order)
      end
    end

    context 'STI subclass permissions' do
      let(:communication_work_order) { create(:communication_work_order) }
      let(:audit_work_order) { create(:audit_work_order) }

      it 'can manage CommunicationWorkOrder' do
        # The ability definition says "can :manage" but there's also "cannot :destroy, :all"
        # for regular admins. The more specific "cannot :destroy, :all" takes precedence.
        # So regular admins can create, update, read but NOT destroy STI subclasses
        expect(ability).to be_able_to(:create, CommunicationWorkOrder)
        expect(ability).to be_able_to(:update, communication_work_order)
        expect(ability).to be_able_to(:read, communication_work_order)
        expect(ability).not_to be_able_to(:destroy, communication_work_order)
      end

      it 'can manage AuditWorkOrder' do
        # Same as CommunicationWorkOrder - cannot :destroy, :all takes precedence
        expect(ability).to be_able_to(:create, AuditWorkOrder)
        expect(ability).to be_able_to(:update, audit_work_order)
        expect(ability).to be_able_to(:read, audit_work_order)
        expect(ability).not_to be_able_to(:destroy, audit_work_order)
      end
    end

    context 'FeeDetail permissions' do
      let(:fee_detail) { create(:fee_detail) }

      it 'can create fee details' do
        expect(ability).to be_able_to(:create, FeeDetail)
      end

      it 'can update fee details' do
        expect(ability).to be_able_to(:update, fee_detail)
      end

      it 'can show fee details' do
        expect(ability).to be_able_to(:show, fee_detail)
      end

      it 'cannot destroy fee details' do
        expect(ability).not_to be_able_to(:destroy, fee_detail)
      end
    end

    context 'OperationHistory permissions' do
      let(:operation_history) { create(:operation_history) }

      it 'can create operation history' do
        expect(ability).to be_able_to(:create, OperationHistory)
      end

      it 'can update operation history' do
        expect(ability).to be_able_to(:update, operation_history)
      end

      it 'can show operation history' do
        expect(ability).to be_able_to(:show, operation_history)
      end

      it 'cannot destroy operation history' do
        expect(ability).not_to be_able_to(:destroy, operation_history)
      end
    end

    context 'restricted permissions' do
      it 'cannot import resources' do
        expect(ability).not_to be_able_to(:import, :all)
        expect(ability).not_to be_able_to(:import, Reimbursement)
      end

      it 'cannot destroy any resources' do
        expect(ability).not_to be_able_to(:destroy, :all)
      end

      it 'cannot create AdminUser' do
        expect(ability).not_to be_able_to(:create, AdminUser)
      end

      it 'cannot update AdminUser' do
        other_admin = create(:admin_user)
        expect(ability).not_to be_able_to(:update, other_admin)
      end

      it 'cannot destroy AdminUser' do
        other_admin = create(:admin_user)
        expect(ability).not_to be_able_to(:destroy, other_admin)
      end

      it 'cannot create FeeType' do
        expect(ability).not_to be_able_to(:create, FeeType)
      end

      it 'cannot update FeeType' do
        fee_type = create(:fee_type)
        expect(ability).not_to be_able_to(:update, fee_type)
      end

      it 'cannot destroy FeeType' do
        fee_type = create(:fee_type)
        expect(ability).not_to be_able_to(:destroy, fee_type)
      end

      it 'cannot create ProblemType' do
        expect(ability).not_to be_able_to(:create, ProblemType)
      end

      it 'cannot update ProblemType' do
        problem_type = create(:problem_type)
        expect(ability).not_to be_able_to(:update, problem_type)
      end

      it 'cannot destroy ProblemType' do
        problem_type = create(:problem_type)
        expect(ability).not_to be_able_to(:destroy, problem_type)
      end

      it 'cannot soft_delete admin users' do
        expect(ability).not_to be_able_to(:soft_delete, AdminUser)
      end

      it 'cannot restore admin users' do
        expect(ability).not_to be_able_to(:restore, AdminUser)
      end
    end
  end

  describe 'deleted user handling' do
    context 'when user is soft deleted' do
      let(:deleted_admin) do
        admin = create(:admin_user, role: 'super_admin')
        admin.soft_delete
        admin
      end
      let(:ability) { Ability.new(deleted_admin) }

      it 'cannot manage anything' do
        expect(ability).not_to be_able_to(:manage, :all)
      end

      it 'cannot read resources' do
        expect(ability).not_to be_able_to(:read, Reimbursement)
        expect(ability).not_to be_able_to(:read, WorkOrder)
        expect(ability).not_to be_able_to(:read, AdminUser)
      end

      it 'cannot create resources' do
        expect(ability).not_to be_able_to(:create, Reimbursement)
        expect(ability).not_to be_able_to(:create, WorkOrder)
      end

      it 'cannot update resources' do
        reimbursement = create(:reimbursement)
        expect(ability).not_to be_able_to(:update, reimbursement)
      end

      it 'cannot destroy resources' do
        reimbursement = create(:reimbursement)
        expect(ability).not_to be_able_to(:destroy, reimbursement)
      end
    end

    context 'when user has deleted status' do
      let(:deleted_status_admin) { create(:admin_user, role: 'super_admin', status: 'deleted') }
      let(:ability) { Ability.new(deleted_status_admin) }

      it 'cannot manage anything' do
        expect(ability).not_to be_able_to(:manage, :all)
      end

      it 'cannot perform any operations' do
        expect(ability).not_to be_able_to(:read, Reimbursement)
        expect(ability).not_to be_able_to(:create, Reimbursement)
        expect(ability).not_to be_able_to(:update, Reimbursement)
      end
    end
  end

  describe 'nil user handling' do
    let(:ability) { Ability.new(nil) }

    it 'creates a new AdminUser instance' do
      # When nil is passed, a new AdminUser is created with default role 'admin'
      # Default admin users get "can :read, :all" permission
      # So they CAN read but cannot create/update/destroy without specific permissions
      expect(ability).to be_able_to(:read, Reimbursement)
      expect(ability).to be_able_to(:read, WorkOrder)
      expect(ability).not_to be_able_to(:manage, :all)
    end

    it 'has limited operations as default admin' do
      # Default admin (role: 'admin') has read-all permission
      expect(ability).to be_able_to(:read, :all)
      # But specific CRUD operations require explicit permissions
      expect(ability).to be_able_to(:create, Reimbursement)
      expect(ability).to be_able_to(:update, Reimbursement)
      expect(ability).not_to be_able_to(:destroy, :all)
    end
  end

  describe 'edge cases' do
    context 'with inactive admin user' do
      let(:inactive_admin) { create(:admin_user, role: 'admin', status: 'inactive') }
      let(:ability) { Ability.new(inactive_admin) }

      it 'still has regular admin permissions' do
        # Status 'inactive' is different from 'deleted'
        expect(ability).to be_able_to(:read, :all)
        expect(ability).to be_able_to(:create, Reimbursement)
      end
    end

    context 'with suspended admin user' do
      let(:suspended_admin) { create(:admin_user, role: 'admin', status: 'suspended') }
      let(:ability) { Ability.new(suspended_admin) }

      it 'still has regular admin permissions' do
        # Status 'suspended' is different from 'deleted'
        expect(ability).to be_able_to(:read, :all)
        expect(ability).to be_able_to(:create, Reimbursement)
      end
    end

    context 'permission specificity' do
      let(:admin) { create(:admin_user, role: 'admin') }
      let(:ability) { Ability.new(admin) }

      it 'has specific create permission for Reimbursement' do
        expect(ability).to be_able_to(:create, Reimbursement)
      end

      it 'has specific update permission for Reimbursement' do
        reimbursement = create(:reimbursement)
        expect(ability).to be_able_to(:update, reimbursement)
      end

      it 'has specific show permission for Reimbursement' do
        reimbursement = create(:reimbursement)
        expect(ability).to be_able_to(:show, reimbursement)
      end

      it 'does not have destroy permission' do
        reimbursement = create(:reimbursement)
        expect(ability).not_to be_able_to(:destroy, reimbursement)
      end
    end
  end
end
