# spec/integration/models/processing_opinion_status_spec.rb
require 'rails_helper'

RSpec.describe 'Processing Opinion and Status Relationship', type: :model do
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_detail) { create(:fee_detail, document_number: reimbursement.invoice_number) }

  describe 'for AuditWorkOrder' do
    let(:audit_work_order) { build(:audit_work_order, reimbursement: reimbursement) }

    before do
      puts "Setting @fee_detail_ids_to_select to [#{fee_detail.id}]"
      audit_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      puts 'Saving audit_work_order'
      audit_work_order.save!
      puts 'Processing fee detail selections'
      audit_work_order.process_fee_detail_selections

      # Check if the association was created correctly
      puts 'Checking associations'
      puts "Fee detail ID: #{fee_detail.id}"
      puts "Audit work order ID: #{audit_work_order.id}"
      puts "Fee detail selections count: #{FeeDetailSelection.count}"
      puts "Fee detail selections for this work order: #{FeeDetailSelection.where(work_order_id: audit_work_order.id).count}"
      puts "Fee details for this work order: #{audit_work_order.fee_details.count}"
      puts "Fee detail IDs for this work order: #{audit_work_order.fee_details.pluck(:id).inspect}"
    end

    it "sets status to approved when processing_opinion is '审核通过'" do
      # Enable debug logging
      old_logger = Rails.logger
      begin
        Rails.logger = Logger.new(STDOUT)
        Rails.logger.level = Logger::DEBUG

        puts "Setting processing_opinion to '审核通过'"
        audit_work_order.processing_opinion = '审核通过'
        puts 'Saving audit_work_order'
        audit_work_order.save!
        puts 'Reloading audit_work_order'
        audit_work_order.reload
      ensure
        Rails.logger = old_logger
      end

      expect(audit_work_order.status).to eq('approved')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end

    it "sets status to rejected when processing_opinion is '否决'" do
      audit_work_order.processing_opinion = '否决'
      audit_work_order.problem_type = 'documentation_issue' # Required for rejected state
      audit_work_order.save!
      audit_work_order.reload

      expect(audit_work_order.status).to eq('rejected')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end

    it "sets status to processing when processing_opinion is not empty and not '审核通过' or '否决'" do
      audit_work_order.processing_opinion = '需要补充材料'
      audit_work_order.save!
      audit_work_order.reload

      expect(audit_work_order.status).to eq('processing')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end

    it 'keeps status as pending when processing_opinion is empty' do
      audit_work_order.processing_opinion = ''
      audit_work_order.save!
      audit_work_order.reload

      expect(audit_work_order.status).to eq('pending')

      # Fee detail status should remain unchanged
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('pending')
    end
  end

  describe 'for CommunicationWorkOrder' do
    let(:communication_work_order) { build(:communication_work_order, reimbursement: reimbursement) }

    before do
      communication_work_order.instance_variable_set('@fee_detail_ids_to_select', [fee_detail.id])
      communication_work_order.save!
      communication_work_order.process_fee_detail_selections
    end

    it "sets status to approved when processing_opinion is '审核通过'" do
      communication_work_order.processing_opinion = '审核通过'
      communication_work_order.resolution_summary = '测试通过原因' # Required for approved state
      communication_work_order.save!
      communication_work_order.reload

      expect(communication_work_order.status).to eq('approved')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('verified')
    end

    it "sets status to rejected when processing_opinion is '否决'" do
      communication_work_order.processing_opinion = '否决'
      communication_work_order.problem_type = 'documentation_issue' # Required for rejected state
      communication_work_order.resolution_summary = '测试拒绝原因' # Required for rejected state
      communication_work_order.save!
      communication_work_order.reload

      expect(communication_work_order.status).to eq('rejected')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end

    it "sets status to processing when processing_opinion is not empty and not '审核通过' or '否决'" do
      communication_work_order.processing_opinion = '需要补充材料'
      communication_work_order.save!
      communication_work_order.reload

      expect(communication_work_order.status).to eq('processing')

      # 检查费用明细状态 - 现在应该自动更新
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('problematic')
    end

    it 'keeps status as pending when processing_opinion is empty' do
      communication_work_order.processing_opinion = ''
      communication_work_order.save!
      communication_work_order.reload

      expect(communication_work_order.status).to eq('pending')

      # Fee detail status should remain unchanged
      fee_detail.reload
      expect(fee_detail.verification_status).to eq('pending')
    end

    it 'allows needs_communication flag to be set independently of status' do
      # Set to processing first
      communication_work_order.processing_opinion = '需要补充材料'
      communication_work_order.save!

      # Now set needs_communication flag
      communication_work_order.needs_communication = true
      communication_work_order.save!
      communication_work_order.reload

      # Status should still be processing
      expect(communication_work_order.status).to eq('processing')
      # But needs_communication should be true
      expect(communication_work_order.needs_communication).to be true

      # Now approve the work order
      communication_work_order.processing_opinion = '审核通过'
      communication_work_order.resolution_summary = '测试通过原因'
      communication_work_order.save!
      communication_work_order.reload

      # Status should be approved
      expect(communication_work_order.status).to eq('approved')
      # And needs_communication should still be true
      expect(communication_work_order.needs_communication).to be true
    end
  end
end
