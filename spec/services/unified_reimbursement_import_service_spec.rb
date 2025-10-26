# spec/services/unified_reimbursement_import_service_spec.rb
require 'rails_helper'

RSpec.describe UnifiedReimbursementImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:csv_file) { double('csv_file', present?: true, tempfile: nil, path: '/tmp/test.csv') }
  let(:service) { described_class.new(csv_file, admin_user) }

  describe '#initialize' do
    it 'inherits from BaseImportService' do
      expect(service).to be_a(BaseImportService)
    end

    it 'initializes with SQLite optimization manager' do
      expect(service.instance_variable_get(:@sqlite_manager)).to be_a(SqliteOptimizationManager)
    end

    it 'initializes with results hash' do
      results = service.instance_variable_get(:@results)
      expect(results).to have_key(:success)
      expect(results).to have_key(:created)
      expect(results).to have_key(:updated)
      expect(results).to have_key(:errors)
    end
  end

  describe '#import' do
    context 'with missing file' do
      let(:csv_file) { double('csv_file', present?: false) }

      it 'returns error for missing file' do
        result = service.import
        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context 'with valid reimbursement data' do
      let(:test_spreadsheet) do
        sheet = [
          ['发票号', '申请人姓名', '部门', '金额', '描述', '申请日期'],
          ['INV001', '张三', '技术部', '1000.50', '差旅费', '2024-01-15'],
          ['INV002', '李四', '市场部', '2500.00', '客户招待', '2024-01-16']
        ]

        mock_sheet = double('sheet')
        allow(mock_sheet).to receive(:row).with(1).and_return(sheet[0])
        allow(mock_sheet).to receive(:each_with_index) do |&block|
          sheet.each_with_index(&block)
        end

        double('spreadsheet').tap do |spreadsheet|
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(mock_sheet)
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
        allow(File).to receive(:extname).and_return('.csv')
        allow(Roo::Spreadsheet).to receive(:open).and_return(test_spreadsheet)
        allow(SqliteOptimizationManager).to receive_message_chain(:new, :during_import).and_yield
        # Mock the insert_all method to avoid database issues in tests
        allow(Reimbursement).to receive(:insert_all)
      end

      it 'processes reimbursement records successfully' do
        result = service.import(test_spreadsheet)
        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
      end

      it 'returns success with correct counts' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
        expect(result[:total_processed]).to eq(2)
      end
    end

    context 'with existing reimbursement records' do
      let!(:existing_reimbursement) { create(:reimbursement, invoice_number: 'INV001', amount: 500.00) }
      let(:test_spreadsheet) do
        sheet = [
          ['发票号', '申请人姓名', '部门', '金额', '描述'],
          ['INV001', '张三', '技术部', '1200.00', '更新后的差旅费']
        ]

        mock_sheet = double('sheet')
        allow(mock_sheet).to receive(:row).with(1).and_return(sheet[0])
        allow(mock_sheet).to receive(:each_with_index) do |&block|
          sheet.each_with_index(&block)
        end

        double('spreadsheet').tap do |spreadsheet|
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(mock_sheet)
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
        allow(File).to receive(:extname).and_return('.csv')
        allow(Roo::Spreadsheet).to receive(:open).and_return(test_spreadsheet)
        allow(SqliteOptimizationManager).to receive_message_chain(:new, :during_import).and_yield
        allow(Reimbursement).to receive(:insert_all)
      end

      it 'updates existing records' do
        expect { service.import(test_spreadsheet) }
          .not_to change { Reimbursement.count }

        existing_reimbursement.reload
        expect(existing_reimbursement.amount).to eq(1200.00)
      end

      it 'returns correct update counts' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(1)
      end
    end

    context 'with validation errors' do
      let(:test_spreadsheet) do
        sheet = [
          ['发票号', '申请人姓名', '部门', '金额'],
          ['', '张三', '技术部', '1000.00'], # Missing invoice number
          ['INV002', '', '技术部', '1000.00'], # Missing applicant name
          ['INV003', '张三', '技术部', '0'] # Invalid amount
        ]

        mock_sheet = double('sheet')
        allow(mock_sheet).to receive(:row).with(1).and_return(sheet[0])
        allow(mock_sheet).to receive(:each_with_index) do |&block|
          sheet.each_with_index(&block)
        end

        double('spreadsheet').tap do |spreadsheet|
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(mock_sheet)
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
        allow(File).to receive(:extname).and_return('.csv')
        allow(Roo::Spreadsheet).to receive(:open).and_return(test_spreadsheet)
        allow(SqliteOptimizationManager).to receive_message_chain(:new, :during_import).and_yield
        allow(Reimbursement).to receive(:insert_all)
      end

      it 'handles validation errors gracefully' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be false
        expect(service.errors.join).to include('发票号为必填项')
        expect(service.errors.join).to include('申请人为必填项')
        expect(service.errors.join).to include('金额必须大于0')
      end
    end

    context 'with duplicate invoice numbers' do
      let(:test_spreadsheet) do
        sheet = [
          ['发票号', '申请人姓名', '部门', '金额'],
          ['INV001', '张三', '技术部', '1000.00'],
          ['INV001', '李四', '技术部', '2000.00'] # Duplicate
        ]

        mock_sheet = double('sheet')
        allow(mock_sheet).to receive(:row).with(1).and_return(sheet[0])
        allow(mock_sheet).to receive(:each_with_index) do |&block|
          sheet.each_with_index(&block)
        end

        double('spreadsheet').tap do |spreadsheet|
          allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(true)
          allow(spreadsheet).to receive(:sheet).with(0).and_return(mock_sheet)
        end
      end

      before do
        allow(csv_file).to receive(:present?).and_return(true)
        allow(File).to receive(:extname).and_return('.csv')
        allow(Roo::Spreadsheet).to receive(:open).and_return(test_spreadsheet)
        allow(SqliteOptimizationManager).to receive_message_chain(:new, :during_import).and_yield
        allow(Reimbursement).to receive(:insert_all)
      end

      it 'detects and reports duplicate invoice numbers' do
        result = service.import(test_spreadsheet)

        expect(result[:success]).to be false
        expect(service.errors).to include('发现重复的发票号: INV001')
      end
    end
  end

  describe 'helper methods' do
    describe '#extract_field_value' do
      let(:row_data) do
        {
          '发票号' => 'INV001',
          '发票编号' => 'INV001_ALT',
          'invoice_number' => 'INV001_EN',
          '申请人姓名' => '张三',
          '其他字段' => 'value'
        }
      end

      it 'extracts value using primary field name' do
        value = service.send(:extract_field_value, row_data, :invoice_number)
        expect(value).to eq('INV001')
      end

      it 'extracts value using alternative field names' do
        value = service.send(:extract_field_value, row_data, :applicant_name)
        expect(value).to eq('张三')
      end

      it 'returns nil when no matching fields found' do
        value = service.send(:extract_field_value, row_data, :department)
        expect(value).to be_nil
      end
    end

    describe '#parse_amount' do
      it 'parses valid decimal amount' do
        amount = service.send(:parse_amount, '1,234.56')
        expect(amount).to eq(1234.56)
      end

      it 'parses integer amount' do
        amount = service.send(:parse_amount, '1000')
        expect(amount).to eq(1000.0)
      end

      it 'handles amount with currency symbols' do
        amount = service.send(:parse_amount, '$1,234.56')
        expect(amount).to eq(1234.56)
      end

      it 'returns nil for blank input' do
        result = service.send(:parse_amount, '')
        expect(result).to be_nil
      end

      it 'returns nil for invalid amount' do
        result = service.send(:parse_amount, 'invalid')
        expect(result).to be_nil
      end
    end

    describe '#parse_date_field' do
      it 'parses ISO date format' do
        date_string = '2024-01-15'
        parsed_date = service.send(:parse_date_field, date_string)
        expect(parsed_date).to eq(Date.new(2024, 1, 15))
      end

      it 'parses datetime string' do
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

  describe 'constants and configuration' do
    it 'defines field mappings' do
      expect(described_class::FIELD_MAPPINGS).to be_a(Hash)
      expect(described_class::FIELD_MAPPINGS[:invoice_number]).to include('发票号', '发票编号')
      expect(described_class::FIELD_MAPPINGS[:applicant_name]).to include('申请人姓名', '申请人')
    end
  end

  private

  def create_mock_sheet(data)
    sheet = double('sheet')
    allow(sheet).to receive(:each_with_index) do |&block|
      data.each_with_index(&block)
    end
    sheet
  end
end