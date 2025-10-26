# spec/services/unified_express_receipt_import_service_simple_spec.rb
require 'rails_helper'

RSpec.describe UnifiedExpressReceiptImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:csv_file) { double('csv_file', present?: true, tempfile: nil, path: '/tmp/test.csv') }
  let(:service) { described_class.new(csv_file, admin_user) }

  describe '#initialize' do
    it 'inherits from BaseImportService' do
      expect(service).to be_a(BaseImportService)
    end

    it 'initializes with required attributes' do
      expect(service.file).to eq(csv_file)
      expect(service.current_admin_user).to eq(admin_user)
    end
  end

  describe '#import with invalid data' do
    context 'with missing file' do
      let(:csv_file) { double('csv_file', present?: false) }

      it 'returns error for missing file' do
        result = service.import
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context 'with missing required fields in headers' do
      let(:test_spreadsheet) do
        sheet = [['单据编号', '操作意见']] # Missing 快递单号
        mock_sheet = double('sheet')
        allow(mock_sheet).to receive(:row).with(1).and_return(sheet[0])

        double('spreadsheet').tap do |spreadsheet|
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(mock_sheet)
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
        allow(File).to receive(:extname).and_return('.csv')
        allow(Roo::Spreadsheet).to receive(:open).and_return(test_spreadsheet)
      end

      it 'returns validation error for missing fields' do
        result = service.import(test_spreadsheet)
        expect(result[:success]).to be false
        expect(result[:errors].first).to include('缺少必需字段: 快递单号')
      end
    end
  end

  describe 'helper methods' do
    describe '#extract_receipt_number' do
      context 'with direct tracking number field' do
        let(:row_data) { { '快递单号' => 'SF123456789' } }

        it 'extracts tracking number directly' do
          receipt_number = service.send(:extract_receipt_number, row_data, 1)
          expect(receipt_number).to eq('SF123456789')
        end
      end

      context 'with tracking number in operation notes' do
        let(:row_data) { { '操作意见' => '快递单号：SF123456789 已签收' } }

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

    describe '#find_reimbursement' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'INV001') }

      it 'finds reimbursement by invoice number' do
        result = service.send(:find_reimbursement, 'INV001')
        expect(result).to eq(reimbursement)
      end

      it 'returns nil for non-existent invoice number' do
        result = service.send(:find_reimbursement, 'NONEXISTENT')
        expect(result).to be_nil
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
        expect(parsed_date).to be_a(Date).or(be_a(Time)).or(be_a(DateTime))
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
    end
  end

  describe 'integration with BaseImportService' do
    it 'inherits from BaseImportService' do
      expect(service.class.ancestors).to include(BaseImportService)
    end

    it 'has access to BaseImportService functionality' do
      # Test that we can access protected methods through inheritance
      expect(service.respond_to?(:validate_file, true)).to be true
      expect(service.respond_to?(:handle_error, true)).to be true
      expect(service.respond_to?(:format_result, true)).to be true
    end
  end

  describe 'constants and configuration' do
    it 'defines tracking number regex' do
      expect(described_class::TRACKING_NUMBER_REGEX).to be_a(Regexp)
    end

    it 'defines field mappings' do
      expect(described_class::FIELD_MAPPINGS).to be_a(Hash)
      expect(described_class::FIELD_MAPPINGS[:document_number]).to include('单据编号')
    end
  end
end