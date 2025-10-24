# spec/services/express_receipt_import_service_spec.rb
require 'rails_helper'
require 'tempfile'

RSpec.describe ExpressReceiptImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    # Create a mock file object that responds to path and present?
    file = double('file')
    allow(file).to receive(:path).and_return('test_express_receipts.csv')
    allow(file).to receive(:present?).and_return(true)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file and existing reimbursements' do
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002', status: 'pending') }

      it 'creates express receipt work orders' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                       .and_yield(['R202501002', '快递单号：SF1002',
                                                                   '2025-01-02 10:00:00'], 2)
                                                       .and_yield(['R999999', '快递单号: SF9999', '2025-01-03 10:00:00'], 3) # 不存在的报销单

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(ExpressReceiptWorkOrder, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:unmatched]).to eq(1)
        expect(result[:errors]).to eq(0)
      end

      it 'extracts tracking numbers correctly' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                       .and_yield(['R202501002', '快递单号：SF1002',
                                                                   '2025-01-02 10:00:00'], 2)

        service.import(spreadsheet)

        work_order1 = ExpressReceiptWorkOrder.find_by(reimbursement_id: reimbursement1.id)
        work_order2 = ExpressReceiptWorkOrder.find_by(reimbursement_id: reimbursement2.id)

        expect(work_order1.tracking_number).to eq('SF1001')
        expect(work_order2.tracking_number).to eq('SF1002')
      end

      it 'sets work order status to completed' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                       .and_yield(['R202501002', '快递单号：SF1002',
                                                                   '2025-01-02 10:00:00'], 2)

        service.import(spreadsheet)

        work_orders = ExpressReceiptWorkOrder.all
        expect(work_orders.all? { |wo| wo.status == 'completed' }).to be true
      end

      it 'updates reimbursement receipt status but not internal status' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1)
                                                       .and_yield(['R202501002', '快递单号：SF1002',
                                                                   '2025-01-02 10:00:00'], 2)

        service.import(spreadsheet)

        reimbursement1.reload
        reimbursement2.reload

        # 验证收单状态已更新
        expect(reimbursement1.receipt_status).to eq('received')
        expect(reimbursement2.receipt_status).to eq('received')

        # 验证内部状态保持不变
        expect(reimbursement1.status).to eq('pending')
        expect(reimbursement2.status).to eq('pending')
      end

      it 'tracks unmatched receipts' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R999999', '快递单号: SF9999', '2025-01-03 10:00:00'], 1) # 不存在的报销单

        result = service.import(spreadsheet)

        expect(result[:unmatched]).to eq(1)
        expect(result[:unmatched_details].first[:document_number]).to eq('R999999')
        expect(result[:unmatched_details].first[:tracking_number]).to eq('SF9999')
      end
    end

    context 'with duplicate records' do
      let!(:reimbursement) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:existing_work_order) do
        create(:express_receipt_work_order, reimbursement: reimbursement, tracking_number: 'SF1001')
      end

      it 'skips duplicate records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', '快递单号: SF1001', '2025-01-01 10:00:00'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(ExpressReceiptWorkOrder, :count)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(0)
        expect(result[:skipped]).to eq(1)
      end
    end

    context 'with invalid data' do
      it 'handles errors' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '没有快递单号', '2025-01-01 10:00:00'], 1)

        result = service.import(spreadsheet)

        expect(result[:success]).to be true # 整体导入仍然成功
        expect(result[:created]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('无法找到有效的单号或从操作意见中提取快递单号')
      end
    end

    context 'with file error' do
      it 'handles missing file' do
        service = described_class.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include('文件不存在')
      end

      it 'handles missing user' do
        service = described_class.new(file, nil)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include('导入用户不存在')
      end

      it 'handles file processing errors' do
        tempfile = double('tempfile', path: '/tmp/test.csv', to_path: '/tmp/test.csv')
        file = double('file', tempfile: tempfile)
        service = described_class.new(file, admin_user)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new('测试错误'))

        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors].first).to include('导入过程中发生错误')
      end
    end
    context 'with filling_id based updates' do
      describe '#csv export functionality' do
        let!(:work_order) { create(:express_receipt_work_order, filling_id: '2025010002') }

        it 'includes filling_id in CSV export' do
          # Mock the CSV generation to test the column mapping
          csv_data = CSV.generate(headers: true) do |csv|
            csv << ['Filling ID', '报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人部门', '快递单号', '收单时间', '创建人', '创建时间',
                    'Current Assignee']
            csv << [
              work_order.filling_id,
              work_order.reimbursement&.invoice_number,
              work_order.reimbursement&.document_name,
              work_order.reimbursement&.applicant,
              work_order.reimbursement&.applicant_id,
              work_order.reimbursement&.department,
              work_order.tracking_number,
              work_order.received_at&.strftime('%Y-%m-%d %H:%M:%S'),
              work_order.creator&.name || work_order.creator&.email,
              work_order.created_at.strftime('%Y年%m月%d日 %H:%M'),
              work_order.reimbursement&.current_assignee&.name || work_order.reimbursement&.current_assignee&.email || '未分配'
            ]
          end

          # Parse the CSV to verify the filling_id is included
          parsed_csv = CSV.parse(csv_data, headers: true)
          expect(parsed_csv[0]['Filling ID']).to eq('2025010002')
          expect(parsed_csv[0]['快递单号']).to eq(work_order.tracking_number)
        end
      end
      let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R202501001', status: 'pending') }
      let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R202501002', status: 'pending') }
      let!(:existing_work_order) do
        Current.admin_user = admin_user
        create(:express_receipt_work_order,
               reimbursement: reimbursement1,
               tracking_number: 'OLD123',
               received_at: Time.current - 1.day,
               filling_id: '2025010001')
      end

      before do
        Current.admin_user = admin_user
      end

      it 'updates existing record when filling_id is provided' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间', 'Filling ID'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', '快递单号: NEW123', '2025-01-03 10:00:00', '2025010001'], 1
        )

        result = nil
        # 不创建新记录，只更新
        expect do
          result = service.import(spreadsheet)
        end.to change(ExpressReceiptWorkOrder, :count).by(0)
        expect(result[:success]).to be true
        expect(result[:created]).to eq(1) # 更新计数为1
        expect(result[:skipped]).to eq(0)

        # 验证记录已更新
        existing_work_order.reload
        expect(existing_work_order.tracking_number).to eq('NEW123')
        expect(existing_work_order.reimbursement).to eq(reimbursement1)
        expect(existing_work_order.filling_id).to eq('2025010001') # filling_id 保持不变
        expect(existing_work_order.status).to eq('completed') # 状态保持不变
      end

      it 'returns error when filling_id does not exist' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['单据编号', '操作意见', '操作时间', 'Filling ID'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', '快递单号: NEW123', '2025-01-03 10:00:00', 'INVALID001'], 1
        )

        result = service.import(spreadsheet)

        expect(result[:success]).to be true # 整体导入成功，但具体行有错误
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('找不到对应的填充ID记录')
      end

      it 'creates new record when no filling_id is provided' do
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(%w[单据编号 操作意见 操作时间])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501002', '快递单号: NEW456', '2025-01-03 10:00:00'], 1
        )

        result = nil
        # 创建新记录
        expect do
          result = service.import(spreadsheet)
        end.to change(ExpressReceiptWorkOrder, :count).by(1)
        expect(result[:success]).to be true
        expect(result[:created]).to eq(1)

        # 验证新记录已创建
        new_work_order = ExpressReceiptWorkOrder.last
        expect(new_work_order.tracking_number).to eq('NEW456')
        expect(new_work_order.reimbursement).to eq(reimbursement2)
        expect(new_work_order.filling_id).to be_present # 自动生成filling_id
      end
    end
  end
end
