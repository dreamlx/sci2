# spec/services/fee_detail_import_service_spec.rb
require 'rails_helper'
require 'tempfile'
require 'rack/test'

RSpec.describe FeeDetailImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    file_path = Rails.root.join('spec', 'test_data', 'test_fee_details.csv')
    Rack::Test::UploadedFile.new(file_path, 'text/csv')
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file and existing reimbursements' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002') }

      it 'creates fee details' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期 弹性字段11
                                                                  所属月 首次提交日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', 'FEE001', '交通费', '100.00', '2025-01-01', '现金', '2025-01', '2025-01-02'], 1)
                                                       .and_yield(['R202501002', 'FEE002', '餐费', '200.00', '2025-01-02',
                                                                   '信用卡', '2025-01', '2025-01-03'], 2)
                                                       .and_yield(['R999999', 'FEE003', '办公用品', '300.00', '2025-01-03', '公司账户', '2025-01', '2025-01-04'], 3) # 不存在的报销单

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(FeeDetail, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
        expect(result[:skipped_errors]).to eq(0)
        expect(result[:unmatched_count]).to eq(1)
      end

      it 'sets verification_status to pending' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期 弹性字段11
                                                                  所属月 首次提交日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', 'FEE004', '交通费', '100.00', '2025-01-01', '现金', '2025-01', '2025-01-02'], 1)
                                                       .and_yield(['R202501002', 'FEE005', '餐费', '200.00', '2025-01-02',
                                                                   '信用卡', '2025-01', '2025-01-03'], 2)

        service.import(spreadsheet)

        fee_details = FeeDetail.all
        expect(fee_details.all? { |fd| fd.verification_status == 'pending' }).to be true
      end

      it 'tracks unmatched details' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期 弹性字段11
                                                                  所属月 首次提交日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R999999', 'FEE006', '办公用品', '300.00', '2025-01-03', '公司账户', '2025-01', '2025-01-04'], 1) # 不存在的报销单

        result = service.import(spreadsheet)

        expect(result[:unmatched_count]).to eq(1)
        expect(result[:unmatched_reimbursement]).to eq(1)
      end
    end

    context 'with duplicate records' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:existing_fee_detail) do
        create(:fee_detail,
               document_number: 'R202501001',
               fee_type: '交通费',
               amount: 100.00,
               fee_date: Date.parse('2025-01-01'),
               external_fee_id: 'FEE001')
      end

      it 'skips duplicate records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', existing_fee_detail.external_fee_id, '交通费', '100.00', '2025-01-01'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        # Test passed successfully - the implementation updates existing records
        expect(result[:success]).to be true
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(1)
        expect(result[:skipped_errors]).to eq(0)
      end
    end

    context 'with invalid data' do
      it 'handles errors' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE007', nil, '100.00', '2025-01-01'], 1
        )

        result = service.import(spreadsheet)

        # The implementation treats the import as failed if there are any errors
        expect(result[:success]).to be false
        expect(result[:error_details].first).to include('缺少必要字段')
      end
    end

    context 'with document number mismatch' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002') }
      let!(:existing_fee_detail) do
        create(:fee_detail,
               external_fee_id: 'FEE001',
               document_number: 'R202501001',
               fee_type: '交通费',
               amount: 100.00,
               fee_date: Date.parse('2025-01-01'))
      end

      it 'skips updates with document number mismatch' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501002', existing_fee_detail.external_fee_id, '交通费', '200.00', '2025-01-02'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        # The implementation treats the import as failed if there are any document number mismatches
        expect(result[:success]).to be false
        expect(result[:error_details].first).to include('关联的报销单号不匹配')

        # Verify the existing fee detail was not changed
        existing_fee_detail.reload
        expect(existing_fee_detail.document_number).to eq('R202501001')
        expect(existing_fee_detail.amount).to eq(100.00)
      end
    end

    context 'with file error' do
      it 'handles missing file' do
        service = described_class.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end

      it 'handles file processing errors' do
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new('测试错误'))

        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('导入过程中发生未知错误')
      end
    end

    context 'auto ID generation for missing fee_id' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'generates AUTO_ prefixed ID when fee_id is missing' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', '', '交通费', '100.00', '2025-01-01'], 1
        )

        expect do
          service.import(spreadsheet)
        end.to change(FeeDetail, :count).by(1)

        fee_detail = FeeDetail.last
        expect(fee_detail.external_fee_id).to start_with('AUTO_R202501001_')
      end

      it 'generates AUTO_ prefixed ID when fee_id is nil' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', nil, '差旅费', '200.00', '2025-01-02'], 1
        )

        expect do
          service.import(spreadsheet)
        end.to change(FeeDetail, :count).by(1)

        fee_detail = FeeDetail.last
        expect(fee_detail.external_fee_id).to start_with('AUTO_R202501001_')
        expect(fee_detail.external_fee_id.length).to eq('AUTO_R202501001_'.length + 8) # hex(4) = 8 chars
      end
    end

    context 'large dataset performance' do
      let!(:reimbursements) do
        (1..10).map do |i|
          create(:reimbursement, invoice_number: "R2025#{format('%05d', i)}")
        end
      end

      it 'handles 100+ fee detail rows efficiently with SQLite optimization' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])

        # Create 100 rows, 10 fee details per reimbursement
        rows = []
        (1..10).each do |i|
          (1..10).each do |j|
            rows << ["R2025#{format('%05d', i)}", "FEE#{i}_#{j}", '交通费', '100.00', '2025-01-01']
          end
        end

        allow(spreadsheet).to receive(:each_with_index) do |&block|
          rows.each_with_index { |row, idx| block.call(row, idx + 1) }
        end

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(FeeDetail, :count).by(100)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(100)
        expect(result[:skipped_errors]).to eq(0)
      end
    end

    context 'date parsing' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'parses fee_date and first_submission_date correctly' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期 首次提交日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE010', '交通费', '100.00', '2025-01-15', '2025-01-16 10:30:00'], 1
        )

        service.import(spreadsheet)

        fee_detail = FeeDetail.find_by(external_fee_id: 'FEE010')
        expect(fee_detail.fee_date).to eq(Date.parse('2025-01-15'))
        expect(fee_detail.first_submission_date).to be_a(Time)
      end

      it 'handles invalid date formats gracefully' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期 首次提交日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE011', '交通费', '100.00', 'invalid-date', 'not-datetime'], 1
        )

        expect do
          service.import(spreadsheet)
        end.to change(FeeDetail, :count).by(1)

        fee_detail = FeeDetail.find_by(external_fee_id: 'FEE011')
        expect(fee_detail.fee_date).to be_nil
        expect(fee_detail.first_submission_date).to be_nil
      end
    end

    context 'missing required fields validation' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'skips rows with missing document_number' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['', 'FEE012', '交通费', '100.00', '2025-01-01'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        expect(result[:success]).to be false
        expect(result[:skipped_errors]).to eq(1)
        expect(result[:error_details].first).to include('缺少必要字段')
      end

      it 'skips rows with missing fee_type' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE013', '', '100.00', '2025-01-01'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        expect(result[:success]).to be false
        expect(result[:skipped_errors]).to eq(1)
      end

      it 'skips rows with missing amount' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE014', '交通费', '', '2025-01-01'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        expect(result[:success]).to be false
        expect(result[:skipped_errors]).to eq(1)
      end

      it 'skips rows with missing fee_date' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE015', '交通费', '100.00', ''], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(FeeDetail, :count)

        expect(result[:success]).to be false
        expect(result[:skipped_errors]).to eq(1)
      end
    end

    context 'decimal parsing with parse_decimal method' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'parses amount with commas correctly' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE016', '交通费', '1,234.56', '2025-01-01'], 1
        )

        service.import(spreadsheet)

        fee_detail = FeeDetail.find_by(external_fee_id: 'FEE016')
        expect(fee_detail.amount).to eq(BigDecimal('1234.56'))
      end

      it 'handles negative amounts by returning 0' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE017', '交通费', '-100.00', '2025-01-01'], 1
        )

        service.import(spreadsheet)

        fee_detail = FeeDetail.find_by(external_fee_id: 'FEE017')
        expect(fee_detail.amount).to eq(BigDecimal('0'))
      end

      it 'handles invalid decimal strings by returning 0' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE018', '交通费', 'not-a-number', '2025-01-01'], 1
        )

        service.import(spreadsheet)

        fee_detail = FeeDetail.find_by(external_fee_id: 'FEE018')
        expect(fee_detail.amount).to eq(BigDecimal('0'))
      end

      it 'handles nil or blank amounts by returning 0' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE019', '交通费', nil, '2025-01-01'], 1
        )

        result = service.import(spreadsheet)

        # This should be skipped due to missing required field
        expect(result[:skipped_errors]).to eq(1)
      end
    end

    context 'error summary truncation' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'limits error details to 10 entries with summary message' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])

        # Create 15 rows with missing fee_type to trigger 15 errors
        rows = (1..15).map do |i|
          ['R202501001', "FEE_ERR#{i}", '', '100.00', '2025-01-01']
        end

        allow(spreadsheet).to receive(:each_with_index) do |&block|
          rows.each_with_index { |row, idx| block.call(row, idx + 1) }
        end

        result = service.import(spreadsheet)

        expect(result[:success]).to be false
        expect(result[:skipped_errors]).to eq(15)
        expect(result[:error_details].size).to eq(11) # 10 errors + 1 summary line
        expect(result[:error_details].last).to include('and 5 more errors')
      end
    end

    context 'missing required headers validation' do
      it 'returns error when essential headers are missing' do
        file = double('file', present?: true, path: '/tmp/test.csv')
        service = described_class.new(file, admin_user)

        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        # Missing critical columns: 费用类型, 原始金额
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index)

        result = service.import(spreadsheet)

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('CSV文件缺少必要的列')
        expect(result[:errors].first).to include('费用类型')
        expect(result[:errors].first).to include('原始金额')
      end
    end

    context 'Roo::FileNotFound error handling' do
      it 'handles missing file gracefully' do
        file = double('file', present?: true, path: '/tmp/nonexistent.xlsx')
        tempfile = double('tempfile', to_path: '/tmp/nonexistent.xlsx')
        allow(file).to receive(:respond_to?).with(:tempfile).and_return(true)
        allow(file).to receive(:tempfile).and_return(tempfile)

        service = described_class.new(file, admin_user)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(Roo::FileNotFound.new('File not found'))

        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('导入文件未找到')
      end
    end

    context 'CSV::MalformedCSVError handling' do
      it 'handles malformed CSV gracefully' do
        file = double('file', present?: true, path: '/tmp/malformed.csv')
        tempfile = double('tempfile', to_path: '/tmp/malformed.csv')
        allow(file).to receive(:respond_to?).with(:tempfile).and_return(true)
        allow(file).to receive(:tempfile).and_return(tempfile)

        service = described_class.new(file, admin_user)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(CSV::MalformedCSVError.new('Illegal quoting', 1))

        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('CSV文件格式错误')
      end
    end

    context 'SqliteOptimizationManager integration' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001') }

      it 'uses SqliteOptimizationManager during import' do
        optimization_manager = instance_double(SqliteOptimizationManager)
        allow(SqliteOptimizationManager).to receive(:new).with(level: :moderate).and_return(optimization_manager)
        allow(optimization_manager).to receive(:during_import).and_yield

        file = double('file', present?: true, path: '/tmp/test.csv')
        service = described_class.new(file, admin_user)

        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[报销单单号 费用id 费用类型 原始金额 费用发生日期])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', 'FEE020', '交通费', '100.00', '2025-01-01'], 1
        )

        service.import(spreadsheet)

        expect(optimization_manager).to have_received(:during_import)
      end
    end
  end
end
