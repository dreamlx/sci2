# spec/services/unified_express_receipt_import_service_spec.rb
require 'rails_helper'

RSpec.describe UnifiedExpressReceiptImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, document_number: 'DOC001') }
  let(:fee_detail) { create(:fee_detail, reimbursement: reimbursement, receipt_number: 'SF123456789') }
  let(:csv_file) { double('csv_file') }
  let(:service) { described_class.new(csv_file, admin_user) }

  describe '#import' do
    context 'with valid file containing express receipt data' do
      let(:test_spreadsheet) do
        sheet = [
          ['快递单号', '单据编号', '操作意见', '操作时间'],
          ['SF123456789', 'DOC001', '审核通过', '2024-01-15 10:30:00'],
          ['SF987654321', 'DOC002', '需要补充材料', '2024-01-16 14:20:00']
        ]

        double('spreadsheet', sheet: sheet).tap do |spreadsheet|
          allow(spreadsheet).to receive(:each_with_index) do |&block|
            sheet.each_with_index(&block)
          end
          allow(spreadsheet).to receive(:row).with(1).and_return(sheet[0])
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
      end

      it 'processes express receipts successfully' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(1) # Only one matches existing fee_detail
        expect(result[:errors]).to eq(0)
      end

      it 'creates ExpressReceipt records' do
        expect { service.import(test_spreadsheet) }
          .to change { ExpressReceipt.count }.by(1)
      end

      it 'handles unmatched receipts' do
        result = service.import(test_spreadsheet)

        expect(result[:unmatched_receipts]).to be_present
        expect(result[:unmatched_receipts].length).to eq(1)
        expect(result[:unmatched_receipts].first[:receipt_number]).to eq('SF987654321')
      end
    end

    context 'with missing required fields' do
      let(:test_spreadsheet) do
        sheet = [
          ['单据编号', '操作意见'], # Missing 快递单号
          ['DOC001', '审核通过']
        ]

        double('spreadsheet', sheet: sheet).tap do |spreadsheet|
          allow(spreadsheet).to receive(:each_with_index) do |&block|
            sheet.each_with_index(&block)
          end
          allow(spreadsheet).to receive(:row).with(1).and_return(sheet[0])
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
      end

      it 'returns validation error' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be false
        expect(result[:errors]).to include('缺少必需字段: 快递单号')
      end
    end

    context 'with file processing errors' do
      let(:csv_file) { double('csv_file', present?: false) }

      it 'handles missing file error' do
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context 'with tracking number in text field' do
      let(:test_spreadsheet) do
        sheet = [
          ['备注', '单据编号'],
          ['快递单号：SF123456789 已签收', 'DOC001']
        ]

        double('spreadsheet', sheet: sheet).tap do |spreadsheet|
          allow(spreadsheet).to receive(:each_with_index) do |&block|
            sheet.each_with_index(&block)
          end
          allow(spreadsheet).to receive(:row).with(1).and_return(sheet[0])
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
      end

      it 'extracts tracking number from text using regex' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(1)
      end
    end
  end

  private

  describe '#validate_required_fields' do
    let(:headers_with_tracking) { ['快递单号', '单据编号'] }
    let(:headers_without_tracking) { ['单据编号', '操作意见'] }

    it 'returns success when required fields are present' do
      result = service.send(:validate_required_fields, headers_with_tracking)
      expect(result[:success]).to be true
    end

    it 'returns error when required fields are missing' do
      result = service.send(:validate_required_fields, headers_without_tracking)
      expect(result[:success]).to be false
      expect(result[:errors]).to include('缺少必需字段: 快递单号')
    end
  end

  describe '#extract_receipt_number' do
    context 'with direct tracking number field' do
      let(:row_data) { { '快递单号' => 'SF123456789' } }

      it 'extracts tracking number directly' do
        receipt_number = service.send(:extract_receipt_number, row_data, 1)
        expect(receipt_number).to eq('SF123456789')
      end
    end

    context 'with tracking number in text field' do
      let(:row_data) { { '备注' => '快递单号：SF123456789 已签收' } }

      it 'extracts tracking number using regex' do
        receipt_number = service.send(:extract_receipt_number, row_data, 1)
        expect(receipt_number).to eq('SF123456789')
      end
    end

    context 'with no tracking number found' do
      let(:row_data) { { '备注' => '普通备注信息' } }

      it 'adds error and returns nil' do
        receipt_number = service.send(:extract_receipt_number, row_data, 1)
        expect(receipt_number).to be_nil
        expect(service.errors).to include('第1行: 无法找到有效的快递单号')
      end
    end
  end

  describe '#find_matching_fee_detail' do
    context 'with matching document number and receipt number' do
      let(:row_data) { { '单据编号' => 'DOC001' } }

      it 'finds fee detail by both criteria' do
        fee_detail = service.send(:find_matching_fee_detail, 'SF123456789', row_data)
        expect(fee_detail).to eq(fee_detail)
      end
    end

    context 'with only receipt number match' do
      let(:row_data) { { '单据编号' => 'DIFFERENT_DOC' } }

      it 'finds fee detail by receipt number only' do
        fee_detail = service.send(:find_matching_fee_detail, 'SF123456789', row_data)
        expect(fee_detail).to eq(fee_detail)
      end
    end

    context 'with no matching fee detail' do
      let(:row_data) { { '单据编号' => 'DOC001' } }

      it 'returns nil' do
        fee_detail = service.send(:find_matching_fee_detail, 'NONEXISTENT', row_data)
        expect(fee_detail).to be_nil
      end
    end
  end

  describe '#extract_field_value' do
    let(:row_data) do
      {
        '单据编号' => 'DOC001',
        '报销单号' => 'DOC001_ALT',
        '操作意见' => '审核意见',
        '备注' => '备注信息'
      }
    end

    it 'extracts value using primary field name' do
      value = service.send(:extract_field_value, row_data, :document_number)
      expect(value).to eq('DOC001')
    end

    it 'extracts value using alternative field names' do
      value = service.send(:extract_field_value, row_data, :operation_notes)
      expect(value).to eq('审核意见')
    end

    it 'returns nil when no matching fields found' do
      value = service.send(:extract_field_value, row_data, :received_at)
      expect(value).to be_nil
    end
  end

  describe '#parse_date_field' do
    it 'parses valid date string' do
      date_string = '2024-01-15'
      parsed_date = service.send(:parse_date_field, date_string)
      expect(parsed_date).to eq(Date.new(2024, 1, 15))
    end

    it 'parses valid datetime string' do
      datetime_string = '2024-01-15 10:30:00'
      parsed_date = service.send(:parse_date_field, datetime_string)
      expect(parsed_date).to be_a(Time)
    end

    it 'returns nil for blank string' do
      result = service.send(:parse_date_field, '')
      expect(result).to be_nil
    end

    it 'returns nil for invalid date format' do
      invalid_date = 'invalid-date'
      result = service.send(:parse_date_field, invalid_date)
      expect(result).to be_nil
    end

    it 'logs warning for invalid date format' do
      invalid_date = 'invalid-date'
      expect(Rails.logger).to receive(:warn).with("无法解析日期格式: #{invalid_date}")
      service.send(:parse_date_field, invalid_date)
    end
  end

  describe '#create_or_update_express_receipt' do
    let(:row_data) do
      {
        '操作意见' => '审核通过',
        '操作时间' => '2024-01-15 10:30:00',
        'Filling ID' => 'FILLING001'
      }
    end

    context 'with new express receipt' do
      it 'creates new express receipt' do
        expect {
          service.send(:create_or_update_express_receipt, fee_detail, row_data, 1)
        }.to change { ExpressReceipt.count }.by(1)

        express_receipt = ExpressReceipt.last
        expect(express_receipt.fee_detail).to eq(fee_detail)
        expect(express_receipt.operation_notes).to eq('审核通过')
        expect(express_receipt.admin_user).to eq(admin_user)
      end
    end

    context 'with existing express receipt' do
      let!(:existing_receipt) { create(:express_receipt, fee_detail: fee_detail) }

      it 'updates existing express receipt' do
        expect {
          service.send(:create_or_update_express_receipt, fee_detail, row_data, 1)
        }.not_to change { ExpressReceipt.count }

        existing_receipt.reload
        expect(existing_receipt.operation_notes).to eq('审核通过')
      end
    end

    context 'with invalid data' do
      let(:invalid_row_data) { { '操作意见' => 'x' * 1000 } } # Too long

      it 'handles save errors gracefully' do
        expect {
          service.send(:create_or_update_express_receipt, fee_detail, invalid_row_data, 1)
        }.not_to change { ExpressReceipt.count }

        expect(service.errors).to be_present
        expect(service.error_count).to eq(1)
      end
    end
  end

  describe '#handle_unmatched_receipt' do
    let(:row_data) do
      {
        '单据编号' => 'DOC001',
        '其他字段' => 'value'
      }
    end

    it 'adds receipt to unmatched list' do
      service.send(:handle_unmatched_receipt, 'SF123456789', row_data, 1)

      expect(service.unmatched_receipts.length).to eq(1)
      unmatched = service.unmatched_receipts.first
      expect(unmatched[:receipt_number]).to eq('SF123456789')
      expect(unmatched[:row_number]).to eq(1)
      expect(unmatched[:document_number]).to eq('DOC001')
      expect(unmatched[:row_data]).to eq(row_data)
    end

    it 'logs unmatched receipt' do
      expect(Rails.logger).to receive(:info).with('未匹配的快递单号: SF123456789 (第1行)')
      service.send(:handle_unmatched_receipt, 'SF123456789', row_data, 1)
    end
  end
end