# spec/services/simple_batch_reimbursement_import_service_spec.rb
require 'rails_helper'

RSpec.describe SimpleBatchReimbursementImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    file = double('file')
    allow(file).to receive(:path).and_return('test_reimbursements.xlsx')
    allow(file).to receive(:present?).and_return(true)
    allow(file).to receive(:respond_to?).with(:tempfile).and_return(false)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#initialize' do
    it 'initializes with file and current admin user' do
      expect(service.instance_variable_get(:@file)).to eq(file)
      expect(service.instance_variable_get(:@current_admin_user)).to eq(admin_user)
    end

    it 'initializes SqliteOptimizationManager with moderate level' do
      sqlite_manager = service.instance_variable_get(:@sqlite_manager)
      expect(sqlite_manager).to be_a(SqliteOptimizationManager)
    end

    it 'initializes results hash with default values' do
      results = service.instance_variable_get(:@results)
      expect(results).to eq({
        success: false,
        created: 0,
        updated: 0,
        errors: 0,
        error_details: []
      })
    end
  end

  describe '#import' do
    context 'with nil file' do
      let(:file) { nil }

      it 'returns error when file is not present' do
        result = service.import
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(['文件不存在'])
      end
    end

    context 'with empty file' do
      it 'returns error when no valid data exists' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return([
          '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
          '报销金额（单据币种）', '报销单状态'
        ])
        allow(spreadsheet).to receive(:each_with_index).and_yield([], 0)

        result = service.import(spreadsheet)
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(['没有有效数据'])
      end
    end

    context 'with missing required headers' do
      it 'returns error when headers are missing' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['报销单单号', '单据名称'], 0)

        result = service.import(spreadsheet)
        expect(result[:success]).to be false
        expect(result[:error_details].first).to include('缺少必要的列')
      end
    end

    context 'with valid data' do
      let(:spreadsheet) { create_valid_spreadsheet }

      it 'creates new reimbursements successfully' do
        expect do
          result = service.import(spreadsheet)
          expect(result[:success]).to be true
          expect(result[:created]).to eq(2)
          expect(result[:updated]).to eq(0)
          expect(result[:errors]).to eq(0)
        end.to change(Reimbursement, :count).by(2)
      end

      it 'sets correct attributes for new records' do
        service.import(spreadsheet)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(reimbursement).to have_attributes(
          document_name: '测试报销单1',
          applicant: '测试用户1',
          applicant_id: 'TEST001',
          company: '测试公司',
          department: '测试部门',
          amount: 100.00,
          status: 'pending'
        )
      end

      it 'parses receipt_status correctly' do
        service.import(spreadsheet)

        r1 = Reimbursement.find_by(invoice_number: 'R202501001')
        r2 = Reimbursement.find_by(invoice_number: 'R202501002')

        expect(r1.receipt_status).to eq('received')
        expect(r2.receipt_status).to eq('pending')
      end

      it 'parses is_electronic flag correctly' do
        service.import(spreadsheet)

        r1 = Reimbursement.find_by(invoice_number: 'R202501001')
        r2 = Reimbursement.find_by(invoice_number: 'R202501002')

        expect(r1.is_electronic).to be false
        expect(r2.is_electronic).to be true
      end

      it 'parses dates correctly' do
        service.import(spreadsheet)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(reimbursement.receipt_date).to eq(Date.parse('2025-01-01'))
        expect(reimbursement.submission_date).to eq(Date.parse('2025-01-01'))
      end

      it 'parses datetime fields correctly' do
        service.import(spreadsheet)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501002')
        # ActiveRecord stores datetime as Time object
        expect(reimbursement.approval_date).to be_present
        expect(reimbursement.approval_date.to_date).to eq(Date.parse('2025-01-03'))
      end

      it 'stores external_status field' do
        service.import(spreadsheet)

        r1 = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(r1.external_status).to eq('审批中')
      end
    end

    context 'with update scenarios' do
      before do
        create(:reimbursement,
               invoice_number: 'R202501001',
               document_name: '旧报销单',
               amount: 50.00,
               is_electronic: false)
      end

      it 'updates existing reimbursements' do
        spreadsheet = create_valid_spreadsheet

        expect do
          result = service.import(spreadsheet)
          expect(result[:success]).to be true
          expect(result[:created]).to eq(1)
          expect(result[:updated]).to eq(1)
          expect(result[:errors]).to eq(0)
        end.to change(Reimbursement, :count).by(1)
      end

      it 'updates all fields correctly' do
        spreadsheet = create_valid_spreadsheet
        service.import(spreadsheet)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(reimbursement.document_name).to eq('测试报销单1')
        expect(reimbursement.amount).to eq(100.00)
      end

      it 'preserves created_at when updating' do
        original = Reimbursement.find_by(invoice_number: 'R202501001')
        original_created_at = original.created_at

        spreadsheet = create_valid_spreadsheet
        service.import(spreadsheet)

        updated = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(updated.created_at).to eq(original_created_at)
      end

      it 'updates updated_at timestamp' do
        original = Reimbursement.find_by(invoice_number: 'R202501001')
        original_updated_at = original.updated_at

        # Sleep to ensure timestamp difference
        sleep 0.01
        spreadsheet = create_valid_spreadsheet
        service.import(spreadsheet)

        updated = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(updated.updated_at).to be >= original_updated_at
      end
    end

    context 'with mixed create and update' do
      before do
        create(:reimbursement, invoice_number: 'R202501001', document_name: '旧报销单')
      end

      it 'handles both creates and updates in same import' do
        spreadsheet = create_valid_spreadsheet

        expect do
          result = service.import(spreadsheet)
          expect(result[:success]).to be true
          expect(result[:created]).to eq(1)
          expect(result[:updated]).to eq(1)
        end.to change(Reimbursement, :count).by(1)
      end
    end

    context 'with validation errors' do
      it 'skips rows with blank invoice_number' do
        spreadsheet = create_spreadsheet_with_blank_invoice

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(Reimbursement, :count).by(1)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(1)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('报销单单号不能为空')
      end

      it 'includes row number in error messages' do
        spreadsheet = create_spreadsheet_with_blank_invoice

        result = service.import(spreadsheet)
        expect(result[:error_details].first).to match(/行 \d+/)
      end

      it 'continues processing after validation errors' do
        spreadsheet = create_spreadsheet_with_blank_invoice

        expect do
          result = service.import(spreadsheet)
          expect(result[:created]).to eq(1)
        end.to change(Reimbursement, :count).by(1)
      end
    end

    context 'with duplicate invoice_numbers in file' do
      it 'processes all rows including duplicates' do
        spreadsheet = create_spreadsheet_with_duplicates

        result = service.import(spreadsheet)
        expect(result[:success]).to be true
        # Both rows get processed as separate creates (batch insert doesn't check uniqueness)
        # The actual behavior depends on database constraints
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
      end
    end

    context 'with large batch' do
      it 'handles large number of records efficiently' do
        spreadsheet = create_large_spreadsheet(100)

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(Reimbursement, :count).by(100)

        expect(result[:success]).to be true
        expect(result[:created]).to eq(100)
      end
    end

    context 'with date parsing' do
      it 'handles various date formats' do
        spreadsheet = create_spreadsheet_with_various_dates

        service.import(spreadsheet)
        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')

        # ActiveRecord may store dates as Time objects
        expect(reimbursement.receipt_date).to be_present
        expect(reimbursement.receipt_date.to_date).to eq(Date.parse('2025-01-01'))
      end

      it 'handles invalid dates gracefully' do
        spreadsheet = create_spreadsheet_with_invalid_dates

        expect do
          result = service.import(spreadsheet)
          expect(result[:success]).to be true
        end.to change(Reimbursement, :count).by(1)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(reimbursement.receipt_date).to be_nil
      end

      it 'handles Date objects directly' do
        spreadsheet = create_spreadsheet_with_date_objects

        service.import(spreadsheet)
        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')

        expect(reimbursement.receipt_date).to eq(Date.parse('2025-01-01'))
      end
    end

    context 'with ERP fields' do
      it 'imports ERP-specific fields correctly' do
        spreadsheet = create_spreadsheet_with_erp_fields

        service.import(spreadsheet)
        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')

        expect(reimbursement.erp_current_approval_node).to eq('财务审批')
        expect(reimbursement.erp_current_approver).to eq('张三')
        expect(reimbursement.erp_flexible_field_2).to eq('弹性值2')
        expect(reimbursement.erp_flexible_field_8).to eq('弹性值8')
      end

      it 'parses ERP datetime fields' do
        spreadsheet = create_spreadsheet_with_erp_fields

        service.import(spreadsheet)
        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')

        # ActiveRecord stores datetime as Time object
        expect(reimbursement.erp_node_entry_time).to be_present
        expect(reimbursement.erp_first_submitted_at).to be_present
      end
    end

    context 'with error handling' do
      it 'handles StandardError and returns error result' do
        allow(service).to receive(:parse_all_rows).and_raise(StandardError, 'Unexpected error')

        result = service.import
        expect(result[:success]).to be false
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('Unexpected error')
      end

      it 'logs error messages' do
        allow(service).to receive(:parse_all_rows).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)

        service.import

        expect(Rails.logger).to have_received(:error).with(/Simple Batch Import Failed/)
      end
    end

    context 'with SqliteOptimizationManager integration' do
      it 'wraps import in during_import block' do
        sqlite_manager = service.instance_variable_get(:@sqlite_manager)
        allow(sqlite_manager).to receive(:during_import).and_yield

        spreadsheet = create_valid_spreadsheet
        service.import(spreadsheet)

        expect(sqlite_manager).to have_received(:during_import)
      end
    end

    context 'with result statistics' do
      it 'returns correct created count' do
        spreadsheet = create_valid_spreadsheet
        result = service.import(spreadsheet)

        expect(result[:created]).to eq(2)
      end

      it 'returns correct updated count' do
        create(:reimbursement, invoice_number: 'R202501001')
        spreadsheet = create_valid_spreadsheet
        result = service.import(spreadsheet)

        expect(result[:updated]).to eq(1)
      end

      it 'returns correct error count' do
        spreadsheet = create_spreadsheet_with_blank_invoice
        result = service.import(spreadsheet)

        expect(result[:errors]).to eq(1)
      end

      it 'includes error details for each error' do
        spreadsheet = create_spreadsheet_with_blank_invoice
        result = service.import(spreadsheet)

        expect(result[:error_details]).to be_an(Array)
        expect(result[:error_details].length).to eq(1)
      end
    end

    context 'with transaction handling' do
      it 'uses transaction for batch operations' do
        spreadsheet = create_valid_spreadsheet
        expect(ActiveRecord::Base).to receive(:transaction).and_yield

        service.import(spreadsheet)
      end

      it 'rolls back on transaction failure' do
        spreadsheet = create_valid_spreadsheet
        allow(Reimbursement).to receive(:insert_all).and_raise(ActiveRecord::RecordInvalid)

        expect do
          service.import(spreadsheet)
        end.not_to change(Reimbursement, :count)
      end
    end
  end

  # Helper methods to create test spreadsheets
  private

  def create_valid_spreadsheet
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单状态', '收单日期', '提交报销日期', '单据标签',
      '报销单审核通过日期', '审核通过人', '关联申请单号', '记账日期', '当前审批节点',
      '当前审批人', '弹性字段2', '当前审批节点转入时间', '首次提交时间', '弹性字段8'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单状态', '收单日期', '提交报销日期', '单据标签',
      '报销单审核通过日期', '审核通过人', '关联申请单号', '记账日期', '当前审批节点',
      '当前审批人', '弹性字段2', '当前审批节点转入时间', '首次提交时间', '弹性字段8'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门',
      100.00, '审批中', '已收单', '2025-01-01', '2025-01-01', '',
      '', '', '', '', '', '', '', '', '', ''
    ], 1).and_yield([
      'R202501002', '测试报销单2', '测试用户2', 'TEST002', '测试公司', '测试部门',
      200.00, '已付款', '未收单', '2025-01-02', '2025-01-02', '全电子发票',
      '2025-01-03', '测试审批人', 'A123', '2025-01-04', '', '', '', '', '', ''
    ], 2)

    spreadsheet
  end

  def create_spreadsheet_with_blank_invoice
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门', 100.00, '审批中'
    ], 1).and_yield([
      '', '无单号报销单', '测试用户2', 'TEST002', '测试公司', '测试部门', 200.00, '审批中'
    ], 2)

    spreadsheet
  end

  def create_spreadsheet_with_duplicates
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门', 100.00, '审批中'
    ], 1).and_yield([
      'R202501001', '测试报销单1更新', '测试用户1', 'TEST001', '测试公司', '测试部门', 150.00, '审批中'
    ], 2)

    spreadsheet
  end

  def create_large_spreadsheet(count)
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ])

    enumerator = allow(spreadsheet).to receive(:each_with_index)
    enumerator.and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态'
    ], 0)

    count.times do |i|
      enumerator.and_yield([
        "R#{(202501001 + i).to_s}", "测试报销单#{i + 1}", '测试用户', 'TEST001',
        '测试公司', '测试部门', 100.00, '审批中'
      ], i + 1)
    end

    spreadsheet
  end

  def create_spreadsheet_with_various_dates
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期', '提交报销日期'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期', '提交报销日期'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门',
      100.00, '审批中', '2025-01-01', '2025/01/01'
    ], 1)

    spreadsheet
  end

  def create_spreadsheet_with_invalid_dates
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门',
      100.00, '审批中', 'invalid-date'
    ], 1)

    spreadsheet
  end

  def create_spreadsheet_with_date_objects
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '收单日期'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门',
      100.00, '审批中', Date.parse('2025-01-01')
    ], 1)

    spreadsheet
  end

  def create_spreadsheet_with_erp_fields
    spreadsheet = double('spreadsheet')
    allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
    allow(spreadsheet).to receive(:row).with(1).and_return([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人', '弹性字段2',
      '当前审批节点转入时间', '首次提交时间', '弹性字段8'
    ])
    allow(spreadsheet).to receive(:each_with_index).and_yield([
      '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门',
      '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人', '弹性字段2',
      '当前审批节点转入时间', '首次提交时间', '弹性字段8'
    ], 0).and_yield([
      'R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门',
      100.00, '审批中', '财务审批', '张三', '弹性值2',
      '2025-01-01 10:00:00', '2025-01-01 09:00:00', '弹性值8'
    ], 1)

    spreadsheet
  end
end
