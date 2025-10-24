# frozen_string_literal: true

# FactoryHelpers - 统一的Factory使用模式
# 提供标准化的数据创建和管理方法
module FactoryHelpers
  extend ActiveSupport::Concern

  included do
    # 基础用户Factory
    let(:super_admin) { create(:admin_user, role: 'super_admin') }
    let(:admin) { create(:admin_user, role: 'admin') }
    let(:regular_admin) { create(:admin_user, role: 'admin') }

    # 基础业务对象Factory
    let(:reimbursement) { create(:reimbursement) }
    let(:pending_reimbursement) { create(:reimbursement, status: 'pending') }
    let(:processing_reimbursement) { create(:reimbursement, status: 'processing') }
    let(:closed_reimbursement) { create(:reimbursement, status: 'closed') }

    let(:fee_detail) { create(:fee_detail) }
    let(:reimbursement_assignment) { create(:reimbursement_assignment) }

    # 文件上传Factory
    let(:test_file) { fixture_file_upload('test.pdf', 'application/pdf') }
    let(:test_csv_file) { fixture_file_upload('test_reimbursements.csv', 'text/csv') }

    # 通用参数Factory
    let(:valid_reimbursement_params) do
      {
        invoice_number: "INV-#{Time.current.to_i}",
        amount: 100.00,
        status: 'pending'
      }
    end

    let(:attachment_params) do
      {
        attachments: [test_file]
      }
    end
  end

  class_methods do
    # 批量创建测试数据的辅助方法
    def create_reimbursements_with_statuses(statuses)
      statuses.map { |status| create(:reimbursement, status: status) }
    end

    def create_admin_users_with_roles(roles)
      roles.map { |role| create(:admin_user, role: role) }
    end

    # 创建特定场景的数据组合
    def create_assignment_scenario
      assigner = create(:admin_user, role: 'super_admin')
      assignee = create(:admin_user, role: 'admin')
      reimbursement = create(:reimbursement, status: 'pending')

      assignment = create(:reimbursement_assignment,
                          reimbursement: reimbursement,
                          assigner: assigner,
                          assignee: assignee)

      { assigner: assigner, assignee: assignee, reimbursement: reimbursement, assignment: assignment }
    end

    def create_import_scenario(file_type: :reimbursements)
      case file_type
      when :reimbursements
        {
          file: fixture_file_upload('test_reimbursements.csv', 'text/csv'),
          import_type: 'reimbursements'
        }
      when :fee_details
        {
          file: fixture_file_upload('test_fee_details.csv', 'text/csv'),
          import_type: 'fee_details'
        }
      when :express_receipts
        {
          file: fixture_file_upload('test_express_receipts.csv', 'text/csv'),
          import_type: 'express_receipts'
        }
      else
        raise ArgumentError, "Unknown file type: #{file_type}"
      end
    end
  end

  # 实例方法 - 动态数据创建
  def create_user_with_role(role)
    create(:admin_user, role: role)
  end

  def create_reimbursement_with_status(status, overrides = {})
    create(:reimbursement, overrides.merge(status: status))
  end

  def create_reimbursement_with_assignment(overrides = {})
    assigner = overrides[:assigner] || create(:admin_user, role: 'super_admin')
    assignee = overrides[:assignee] || create(:admin_user, role: 'admin')
    reimbursement = create(:reimbursement, overrides.except(:assigner, :assignee))

    assignment = create(:reimbursement_assignment,
                        reimbursement: reimbursement,
                        assigner: assigner,
                        assignee: assignee)

    { reimbursement: reimbursement, assignment: assignment, assigner: assigner, assignee: assignee }
  end

  def create_fee_detail_with_attachment(reimbursement: nil, file: nil)
    reimbursement ||= create(:reimbursement)
    file ||= fixture_file_upload('test.pdf', 'application/pdf')

    create(:fee_detail, reimbursement: reimbursement, attachments: [file])
  end

  # 时间相关的数据创建
  def create_reimbursement_created_at(time)
    create(:reimbursement, created_at: time)
  end

  def create_reimbursements_in_date_range(start_date, end_date, count: 3)
    Array.new(count) do |i|
      time = start_date + ((end_date - start_date) * (i.to_f / (count - 1)))
      create(:reimbursement, created_at: time)
    end
  end

  # 批量操作辅助方法
  def create_batch_reimbursements(count: 5, status: 'pending')
    create_list(:reimbursement, count, status: status)
  end

  def create_batch_assignments(assignments_data)
    assignments_data.map do |data|
      create(:reimbursement_assignment, data)
    end
  end

  # 数据清理辅助方法
  def cleanup_test_data
    # 在测试结束时清理特定数据
    Reimbursement.delete_all
    FeeDetail.delete_all
    ReimbursementAssignment.delete_all
    # 注意：保留AdminUser数据，因为其他测试可能依赖
  end

  # 验证数据状态的辅助方法
  def verify_reimbursement_count(expected_count, status: nil)
    scope = Reimbursement.all
    scope = scope.where(status: status) if status
    expect(scope.count).to eq(expected_count)
  end

  def verify_assignment_count(expected_count)
    expect(ReimbursementAssignment.count).to eq(expected_count)
  end

  # 数据关联验证
  def verify_assignment_relationships(assignment)
    aggregate_failures do
      expect(assignment.reimbursement).to be_present
      expect(assignment.assigner).to be_present
      expect(assignment.assignee).to be_present
      expect(assignment.assigner.role).to eq('super_admin')
    end
  end

  # 文件验证辅助方法
  def verify_file_attachment(attachable, attachment_name: :attachments)
    expect(attachable.send(attachment_name)).to be_attached
  end

  def verify_file_content(attachable, expected_filename: nil, expected_content_type: nil)
    attachment = attachable.attachments.first
    expect(attachment.filename.to_s).to include(expected_filename) if expected_filename
    expect(attachment.content_type).to eq(expected_content_type) if expected_content_type
  end
end
