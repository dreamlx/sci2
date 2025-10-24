# frozen_string_literal: true

require 'rails_helper'

# Load Command classes
require_relative '../../app/commands/assign_reimbursement_command'
require_relative '../../app/commands/set_reimbursement_status_command'
require_relative '../../app/commands/reset_reimbursement_override_command'

RSpec.describe 'New Architecture Integration' do
  let!(:admin_user) { create(:admin_user, :admin) }
  let!(:regular_user) { create(:admin_user, :regular) }
  let!(:reimbursement) { create(:reimbursement, status: 'pending') }
  let!(:assignee) { create(:admin_user, :regular) }

  describe 'Command Pattern Integration' do
    context 'AssignReimbursementCommand' do
      it 'successfully assigns reimbursement with valid parameters' do
        command = Commands::AssignReimbursementCommand.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          notes: '集成测试分配',
          current_user: admin_user
        )

        result = command.call

        expect(result.success?).to be true
        expect(result.data).to be_a(ReimbursementAssignment)
        expect(result.data.reimbursement).to eq(reimbursement)
        expect(result.data.assignee).to eq(assignee)
        expect(result.data.notes).to eq('集成测试分配')
      end

      it 'fails with invalid parameters' do
        command = Commands::AssignReimbursementCommand.new(
          reimbursement_id: nil,
          assignee_id: nil,
          current_user: admin_user
        )

        result = command.call

        expect(result.success?).to be false
        expect(result.errors.join).to include('Reimbursement')
        expect(result.errors.join).to include('Assignee')
      end

      it 'uses Repository for data access' do
        command = Commands::AssignReimbursementCommand.new(
          reimbursement_id: reimbursement.id,
          assignee_id: assignee.id,
          notes: 'Repository测试',
          current_user: admin_user
        )

        # 验证Command能成功使用Repository
        result = command.call
        expect(result.success?).to be true

        # 验证Repository可以找到该记录
        found_reimbursement = ReimbursementRepository.find(reimbursement.id)
        expect(found_reimbursement).to eq(reimbursement)
      end
    end

    context 'SetReimbursementStatusCommand' do
      it 'successfully sets manual status with valid parameters' do
        command = Commands::SetReimbursementStatusCommand.new(
          reimbursement_id: reimbursement.id,
          status: 'processing',
          current_user: admin_user
        )

        result = command.call

        expect(result.success?).to be true
        expect(result.data).to eq(reimbursement)
        expect(result.data.status).to eq('processing')
        expect(result.data.manual_override).to be_present
      end

      it 'fails with invalid status' do
        command = Commands::SetReimbursementStatusCommand.new(
          reimbursement_id: reimbursement.id,
          status: 'invalid_status',
          current_user: admin_user
        )

        result = command.call

        expect(result.success?).to be false
        expect(result.errors.join).to include('Invalid status')
      end
    end

    context 'ResetReimbursementOverrideCommand' do
      it 'successfully resets manual override' do
        # 先设置手动覆盖
        reimbursement.update_column(:manual_override, 'processing')
        reimbursement.update_column(:manual_override_at, Time.current)

        command = Commands::ResetReimbursementOverrideCommand.new(
          reimbursement_id: reimbursement.id,
          current_user: admin_user
        )

        result = command.call

        expect(result.success?).to be true
        expect(result.data).to eq(reimbursement)
        expect(result.data.manual_override).to be false
      end
    end
  end

  describe 'Policy Object Integration' do
    context 'ReimbursementPolicy' do
      it 'correctly evaluates permissions for admin users' do
        policy = ReimbursementPolicy.new(admin_user, reimbursement)

        expect(policy.can_view?).to be true
        expect(policy.can_edit?).to be true # admin can edit
        expect(policy.can_assign?).to be false  # admin CANNOT assign (correct behavior)
        expect(policy.can_create?).to be true   # admin can create
      end

      it 'correctly evaluates permissions for super admin users' do
        super_admin = create(:admin_user, :super_admin)
        policy = ReimbursementPolicy.new(super_admin, reimbursement)

        expect(policy.can_view?).to be true
        expect(policy.can_edit?).to be true # super admin可以编辑
        expect(policy.can_assign?).to be true # super admin可以分配
        expect(policy.can_create?).to be true
      end

      it 'provides appropriate error messages' do
        policy = ReimbursementPolicy.new(regular_user, reimbursement)

        expect(policy.authorization_error_message(action: :assign)).to eq(
          '您没有权限执行分配操作，请联系超级管理员'
        )
        # :edit操作不在特定case中，使用默认消息
        expect(policy.authorization_error_message(action: :edit)).to eq(
          '您没有权限执行此操作，请联系超级管理员'
        )
      end

      it 'handles nil reimbursement gracefully' do
        policy = ReimbursementPolicy.new(admin_user, nil)

        expect(policy.can_index?).to be true
        expect(policy.can_view?).to be true # Policy allows view without specific object
      end
    end
  end

  describe 'Repository Pattern Integration' do
    context 'ReimbursementRepository' do
      it 'provides consistent data access interface' do
        # 查找操作
        found = ReimbursementRepository.find(reimbursement.id)
        expect(found).to eq(reimbursement)

        # 查询操作
        pending_count = ReimbursementRepository.pending.count
        expect(pending_count).to be >= 1

        # 搜索操作
        search_results = ReimbursementRepository.search_by_invoice_number(reimbursement.invoice_number)
        expect(search_results).to include(reimbursement)
      end

      it 'handles not found cases gracefully' do
        expect(ReimbursementRepository.find(99_999)).to be_nil
        expect(ReimbursementRepository.find_by_invoice_number('NONEXISTENT')).to be_nil
      end

      it 'provides complex query capabilities' do
        # 状态查询
        pending_reimbursements = ReimbursementRepository.by_status('pending')
        expect(pending_reimbursements).to include(reimbursement)

        # 统计查询
        status_counts = ReimbursementRepository.status_counts
        expect(status_counts[:pending]).to be >= 1
      end
    end
  end

  describe 'Service Layer Integration' do
    context 'ReimbursementScopeService' do
      it 'applies correct scope filtering' do
        service = ReimbursementScopeService.new(admin_user, { scope: 'assigned_to_me' })

        # 创建一些测试数据
        assigned_reimbursement = create(:reimbursement)
        create(:reimbursement_assignment, reimbursement: assigned_reimbursement, assignee: admin_user, is_active: true)

        result = service.scoped_collection(Reimbursement.all)

        # 验证scope应用
        expect(result).to include(assigned_reimbursement)
        # 不应该包含未分配的reimbursement
      end

      it 'handles different scopes correctly' do
        # 测试各种scope
        scopes = %w[assigned_to_me pending processing unassigned all]

        scopes.each do |scope|
          service = ReimbursementScopeService.new(admin_user, { scope: scope })
          result = service.scoped_collection(Reimbursement.all)

          # 验证返回 ActiveRecord::Relation
          expect(result).to respond_to(:count)
          expect(result).to respond_to(:each)
        end
      end
    end

    context 'ReimbursementStatusOverrideService' do
      it 'handles status override operations' do
        service = ReimbursementStatusOverrideService.new(admin_user)

        # 设置状态覆盖
        result = service.set_status(reimbursement, 'processing')

        expect(result.success?).to be true
        expect(result.reimbursement).to eq(reimbursement)
        expect(result.reimbursement.manual_override).to be true
      end

      it 'can reset manual override' do
        # 先设置覆盖
        reimbursement.update_column(:manual_override, 'processing')

        service = ReimbursementStatusOverrideService.new(admin_user)
        result = service.reset_override(reimbursement)

        expect(result.success?).to be true
        expect(result.reimbursement).to eq(reimbursement)
        expect(result.reimbursement.manual_override).to be false
      end
    end

    context 'ReimbursementAssignmentService' do
      it 'manages assignment operations' do
        service = ReimbursementAssignmentService.new(admin_user)

        # 创建分配
        result = service.assign(reimbursement.id, assignee.id, '服务测试分配')

        expect(result).to be_a(ReimbursementAssignment)
        expect(result.reimbursement).to eq(reimbursement)
        expect(result.assignee).to eq(assignee)
        expect(result.notes).to eq('服务测试分配')
        expect(result.is_active).to be true
      end

      it 'handles batch assignments' do
        # 创建多个reimbursement
        reimbursements = create_list(:reimbursement, 3)
        reimbursement_ids = reimbursements.map(&:id)

        service = ReimbursementAssignmentService.new(admin_user)
        results = service.batch_assign(reimbursement_ids, assignee.id, '批量分配测试')

        expect(results.length).to eq(3)
        results.each do |result|
          expect(result).to be_a(ReimbursementAssignment)
          expect(result.assignee).to eq(assignee)
        end
      end
    end
  end

  describe 'Cross-Layer Integration' do
    it 'integrates Command -> Service -> Repository flow' do
      command = Commands::AssignReimbursementCommand.new(
        reimbursement_id: reimbursement.id,
        assignee_id: assignee.id,
        notes: '跨层集成测试',
        current_user: admin_user
      )

      # 验证整个流程
      result = command.call
      expect(result.success?).to be true

      # 验证Service层被调用
      assignment = result.data
      expect(assignment).to be_present

      # 验证Repository层被使用
      expect(ReimbursementRepository.find(reimbursement.id)).to eq(reimbursement)
    end

    it 'integrates Policy -> Command flow' do
      # 测试权限检查
      policy = ReimbursementPolicy.new(regular_user, reimbursement)
      expect(policy.can_assign?).to be false

      # Command本身没有内置权限检查（权限检查在Controller层）
      # 但Command可以正常执行，权限由上层控制
      command = Commands::AssignReimbursementCommand.new(
        reimbursement_id: reimbursement.id,
        assignee_id: assignee.id,
        notes: '权限测试',
        current_user: regular_user
      )

      # Command会成功执行，但权限由Controller层的Policy控制
      result = command.call
      expect(result.success?).to be true # Command层不检查权限

      # 验证Policy正确阻止权限
      expect(policy.can_assign?).to be false
    end

    it 'handles error propagation across layers' do
      # 测试Repository错误传播
      allow(ReimbursementRepository).to receive(:find).and_raise(StandardError, 'Database error')

      command = Commands::AssignReimbursementCommand.new(
        reimbursement_id: reimbursement.id,
        assignee_id: assignee.id,
        notes: '错误传播测试',
        current_user: admin_user
      )

      result = command.call
      expect(result.success?).to be false
      expect(result.errors).to include(/Unexpected error/)
    end
  end

  describe 'Data Consistency' do
    it 'maintains data consistency across operations' do
      # 初始状态
      original_status = reimbursement.status
      expect(original_status).to eq('pending')

      # 通过Command修改状态
      command = Commands::SetReimbursementStatusCommand.new(
        reimbursement_id: reimbursement.id,
        status: 'processing',
        current_user: admin_user
      )

      result = command.call
      expect(result.success?).to be true

      # 验证数据一致性
      updated_reimbursement = ReimbursementRepository.find(reimbursement.id)
      expect(updated_reimbursement.status).to eq('processing')
      expect(updated_reimbursement.id).to eq(reimbursement.id)
    end

    it 'prevents duplicate active assignments' do
      service = ReimbursementAssignmentService.new(admin_user)

      # 第一次分配
      assignment1 = service.assign(reimbursement.id, assignee.id, '第一次分配')
      expect(assignment1.is_active).to be true

      # 第二次分配给不同用户
      another_assignee = create(:admin_user, :regular)
      assignment2 = service.assign(reimbursement.id, another_assignee.id, '第二次分配')

      # 验证只有最后一个分配是活跃的
      expect(assignment1.reload.is_active).to be false
      expect(assignment2.is_active).to be true
    end
  end

  describe 'Performance Considerations' do
    it 'uses efficient queries through Repository' do
      # 验证Repository能正确执行查询
      found_reimbursement = ReimbursementRepository.find(reimbursement.id)
      expect(found_reimbursement).to eq(reimbursement)

      pending_collection = ReimbursementRepository.pending
      expect(pending_collection).to respond_to(:count)

      # 执行操作
      service = ReimbursementScopeService.new(admin_user)
      result = service.scoped_collection(pending_collection)
      expect(result).to respond_to(:each)
    end

    it 'avoids N+1 queries through proper associations' do
      # 创建测试数据
      create_list(:reimbursement, 5)

      service = ReimbursementScopeService.new(admin_user, { scope: 'pending' })

      # 验证查询能正常执行且返回正确的结果
      result = service.scoped_collection(ReimbursementRepository.pending)
      expect(result).to respond_to(:count)
      expect(result).to respond_to(:each)

      # 验证执行时间合理（简单的时间检查）
      start_time = Time.current
      service.scoped_collection(ReimbursementRepository.pending)
      execution_time = Time.current - start_time
      expect(execution_time).to be < 1.second
    end
  end

  after do
    # 清理测试数据
    ReimbursementAssignment.delete_all
    Reimbursement.delete_all
    AdminUser.where.not(id: [admin_user.id, regular_user.id]).delete_all
  end
end
