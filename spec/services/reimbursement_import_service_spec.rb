require 'rails_helper'

RSpec.describe ReimbursementImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:file_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_reimbursements.xlsx') }
  let(:file) { fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

  # 准备测试文件
  before do
    # 确保测试目录存在
    FileUtils.mkdir_p(Rails.root.join('spec', 'fixtures', 'files'))

    # 创建测试Excel文件（如果不存在）
    unless File.exist?(file_path)
      workbook = Roo::Excelx.new(file_path)
      worksheet = workbook.sheets.first

      # 添加表头
      headers = ['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '报销金额', '收单状态', '报销单状态', '收单日期', '提交报销日期', '单据标签']
      headers.each_with_index do |header, index|
        worksheet.set(0, index, header)
      end

      # 添加数据行
      data = [
        ['R20250101001', '测试报销单1', '张三', 'EMP001', '测试公司', '测试部门', 1000, '已收单', '处理中', '2025-01-01', '2025-01-01', '全电子发票'],
        ['R20250101002', '测试报销单2', '李四', 'EMP002', '测试公司', '财务部', 2000, '待收单', '处理中', nil, '2025-01-02', ''],
        ['R20250101003', '测试报销单3', '王五', 'EMP003', '测试公司', '市场部', 3000, '已收单', '已付款', '2025-01-03', '2025-01-03', '']
      ]

      data.each_with_index do |row, row_index|
        row.each_with_index do |value, col_index|
          worksheet.set(row_index + 1, col_index, value)
        end
      end

      workbook.save
    end
  end

  describe '#import' do
    context '当文件不存在时' do
      it '返回错误信息' do
        service = ReimbursementImportService.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be_falsey
        expect(result[:errors]).to include('文件不存在')
      end
    end

    context '当文件格式不支持时' do
      let(:invalid_file) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'test.txt'), 'text/plain') }

      it '返回错误信息' do
        allow(File).to receive(:extname).and_return('.txt')

        service = ReimbursementImportService.new(invalid_file, admin_user)
        expect { service.import }.to raise_error(/未知的文件类型/)
      end
    end

    context '当文件有效时' do
      it '导入报销单数据' do
        service = ReimbursementImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(3)
          expect(result[:updated]).to eq(0)
        }.to change(Reimbursement, :count).by(3)
      end

      it '为非电子发票报销单创建审核工单' do
        service = ReimbursementImportService.new(file, admin_user)

        expect {
          service.import
        }.to change(AuditWorkOrder, :count).by(3) # 根据07_refactoring_adjustments调整，无论是否为电子发票都创建审核工单
      end

      it '更新已存在的报销单' do
        create(:reimbursement, invoice_number: 'R20250101001', document_name: '旧名称')

        service = ReimbursementImportService.new(file, admin_user)

        expect {
          result = service.import
          expect(result[:success]).to be_truthy
          expect(result[:created]).to eq(2)
          expect(result[:updated]).to eq(1)
        }.to change(Reimbursement, :count).by(2)

        reimbursement = Reimbursement.find_by(invoice_number: 'R20250101001')
        expect(reimbursement.document_name).to eq('测试报销单1')
      end

      it '处理缺少必要字段的行' do
        # 创建一个缺少报销单号的测试文件
        invalid_file_path = Rails.root.join('spec', 'fixtures', 'files', 'invalid_reimbursements.xlsx')
        workbook = Roo::Excelx.new(invalid_file_path)
        worksheet = workbook.sheets.first

        # 添加表头
        headers = ['报销单单号', '单据名称', '报销单申请人']
        headers.each_with_index do |header, index|
          worksheet.set(0, index, header)
        end

        # 添加数据行（缺少报销单号）
        worksheet.set(1, 0, nil)
        worksheet.set(1, 1, '测试报销单')
        worksheet.set(1, 2, '张三')

        workbook.save

        invalid_file = fixture_file_upload(invalid_file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        service = ReimbursementImportService.new(invalid_file, admin_user)

        result = service.import
        expect(result[:success]).to be_truthy
        expect(result[:created]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details]).to include(/行 2: 报销单单号不能为空/)
      end
    end

    describe '私有方法' do
      let(:service) { ReimbursementImportService.new(file, admin_user) }

      describe '#parse_receipt_status' do
        it '解析收单状态' do
          expect(service.send(:parse_receipt_status, '已收单')).to eq('received')
          expect(service.send(:parse_receipt_status, 'received')).to eq('received')
          expect(service.send(:parse_receipt_status, '待收单')).to eq('pending')
          expect(service.send(:parse_receipt_status, 'pending')).to eq('pending')
          expect(service.send(:parse_receipt_status, nil)).to be_nil
        end
      end

      describe '#parse_reimbursement_status' do
        it '解析报销单状态' do
          expect(service.send(:parse_reimbursement_status, '已付款')).to eq('closed')
          expect(service.send(:parse_reimbursement_status, '已完成')).to eq('closed')
          expect(service.send(:parse_reimbursement_status, 'closed')).to eq('closed')
          expect(service.send(:parse_reimbursement_status, '处理中')).to eq('processing')
          expect(service.send(:parse_reimbursement_status, 'processing')).to eq('processing')
          expect(service.send(:parse_reimbursement_status, nil)).to be_nil
        end
      end

      describe '#parse_date' do
        it '解析日期' do
          expect(service.send(:parse_date, '2025-01-01')).to eq(Date.parse('2025-01-01'))
          expect(service.send(:parse_date, Date.parse('2025-01-01'))).to eq(Date.parse('2025-01-01'))
          expect(service.send(:parse_date, 'invalid date')).to be_nil
          expect(service.send(:parse_date, nil)).to be_nil
        end
      end

      describe '#parse_is_electronic' do
        it '解析是否为电子发票' do
          expect(service.send(:parse_is_electronic, '全电子发票')).to be_truthy
          expect(service.send(:parse_is_electronic, 'electronic')).to be_truthy
          expect(service.send(:parse_is_electronic, '纸质发票')).to be_falsey
          expect(service.send(:parse_is_electronic, nil)).to be_nil
        end
      end

      describe '#parse_is_complete' do
        it '解析是否完成' do
          expect(service.send(:parse_is_complete, '已付款')).to be_truthy
          expect(service.send(:parse_is_complete, '已完成')).to be_truthy
          expect(service.send(:parse_is_complete, 'closed')).to be_truthy
          expect(service.send(:parse_is_complete, '处理中')).to be_falsey
          expect(service.send(:parse_is_complete, nil)).to be_nil
        end
      end
    end
  end
end