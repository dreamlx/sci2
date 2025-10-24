# spec/services/reimbursement_import_service_spec.rb
require 'rails_helper'
require 'tempfile'

RSpec.describe ReimbursementImportService do
  let(:admin_user) { create(:admin_user) }
  let(:file) do
    # Create a mock file object that responds to path and present?
    file = double('file')
    allow(file).to receive(:path).and_return('test_reimbursements.csv')
    allow(file).to receive(:present?).and_return(true)
    file
  end
  let(:service) { described_class.new(file, admin_user) }

  describe '#import' do
    context 'with valid file' do
      let(:csv_content) do
        <<~CSV
          报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,收单状态,收单日期,提交报销日期,报销单状态,单据标签,报销单审核通过日期,审核通过人
          R202501001,测试报销单1,测试用户1,TEST001,测试公司,测试部门,100.00,已收单,2025-01-01,2025-01-01,审批中,,,
          R202501002,测试报销单2,测试用户2,TEST002,测试公司,测试部门,200.00,已收单,2025-01-02,2025-01-02,已付款,全电子发票,2025-01-03,测试审批人
          ,无单号报销单,测试用户3,TEST003,测试公司,测试部门,300.00,未收单,,2025-01-03,审批中,,,
        CSV
      end

      it 'creates new reimbursements' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                '申请人部门', '报销金额（单据币种）', '收单状态', '收单日期', '提交报销日期', '报销单状态', '单据标签', '报销单审核通过日期', '审核通过人'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门', '100.00', '已收单', '2025-01-01', '2025-01-01', '审批中', '', '', ''], 1)
                                                       .and_yield(['R202501002', '测试报销单2', '测试用户2', 'TEST002', '测试公司',
                                                                   '测试部门', '200.00', '已收单', '2025-01-02', '2025-01-02', '已付款', '全电子发票', '2025-01-03', '测试审批人'], 2)
                                                       .and_yield(['', '无单号报销单', '测试用户3', 'TEST003', '测试公司', '测试部门',
                                                                   '300.00', '未收单', '', '2025-01-03', '审批中', '', '', ''], 3)

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.to change(Reimbursement, :count).by(2)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('报销单单号不能为空')
      end

      it 'sets is_electronic based on 单据标签' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                '申请人部门', '报销金额（单据币种）', '收单状态', '收单日期', '提交报销日期', '报销单状态', '单据标签', '报销单审核通过日期', '审核通过人'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门', '100.00', '已收单', '2025-01-01', '2025-01-01', '审批中', '', '', ''], 1)
                                                       .and_yield(['R202501002', '测试报销单2', '测试用户2', 'TEST002', '测试公司',
                                                                   '测试部门', '200.00', '已收单', '2025-01-02', '2025-01-02', '已付款', '全电子发票', '2025-01-03', '测试审批人'], 2)

        service.import(spreadsheet)

        reimbursement1 = Reimbursement.find_by(invoice_number: 'R202501001')
        reimbursement2 = Reimbursement.find_by(invoice_number: 'R202501002')

        expect(reimbursement1.is_electronic).to be false
        expect(reimbursement2.is_electronic).to be true
      end

      it 'sets status according to external_status for new records' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                '申请人部门', '报销金额（单据币种）', '收单状态', '收单日期', '提交报销日期', '报销单状态', '单据标签', '报销单审核通过日期', '审核通过人'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(['R202501001', '测试报销单1', '测试用户1', 'TEST001', '测试公司', '测试部门', '100.00', '已收单', '2025-01-01', '2025-01-01', '审批中', '', '', ''], 1)
                                                       .and_yield(['R202501002', '测试报销单2', '测试用户2', 'TEST002', '测试公司',
                                                                   '测试部门', '200.00', '已收单', '2025-01-02', '2025-01-02', '已付款', '全电子发票', '2025-01-03', '测试审批人'], 2)

        service.import(spreadsheet)

        reimbursement1 = Reimbursement.find_by(invoice_number: 'R202501001')
        reimbursement2 = Reimbursement.find_by(invoice_number: 'R202501002')

        # For new records, internal status should be determined by external status
        expect(reimbursement1.status).to eq('pending') # '审批中' -> pending
        expect(reimbursement2.status).to eq('closed')  # '已付款' -> closed
      end
    end

    context 'with existing reimbursements' do
      before do
        create(:reimbursement, invoice_number: 'R202501001', document_name: '旧报销单', is_electronic: false)
      end

      it 'updates existing reimbursements' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                '申请人部门', '报销金额（单据币种）', '收单状态', '收单日期', '提交报销日期', '报销单状态', '单据标签', '报销单审核通过日期', '审核通过人'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['R202501001', '新报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '已收单', '2025-01-01', '2025-01-01', '审批中', '全电子发票',
           '2025-01-03', '测试审批人'], 1
        )

        result = nil
        expect do
          result = service.import(spreadsheet)
        end.not_to change(Reimbursement, :count)

        # Test passed successfully
        expect(result[:success]).to be true
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(1)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501001')
        expect(reimbursement.document_name).to eq('新报销单')
        expect(reimbursement.is_electronic).to be true
      end
    end
    context 'internal status handling' do
      let(:base_headers) { ['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司', '申请人部门', '报销金额（单据币种）', '报销单状态'] }

      # Helper to create a mock spreadsheet for a single row
      def mock_spreadsheet(row_data)
        spreadsheet = double('spreadsheet')
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(base_headers)
        allow(spreadsheet).to receive(:each_with_index).and_yield(row_data, 1)
        spreadsheet
      end

      it 'sets internal status to pending for new records regardless of external status' do
        # Scenario: New record, external status is '审批中' (processing)
        row_data = ['R202501003', '新报销单', '新用户', 'NEW001', '新公司', '新部门', '500.00', '审批中']
        spreadsheet = mock_spreadsheet(row_data)

        expect do
          service.import(spreadsheet)
        end.to change(Reimbursement, :count).by(1)

        reimbursement = Reimbursement.find_by(invoice_number: 'R202501003')
        expect(reimbursement.external_status).to eq('审批中')
        expect(reimbursement.status).to eq(Reimbursement::STATUS_PENDING)
      end

      it 'updates internal status for existing records when external status changes to paid status' do
        # Create an existing reimbursement without manual override
        existing_reimbursement = create(:reimbursement,
                                        invoice_number: 'R202501004',
                                        status: Reimbursement::STATUS_PROCESSING,
                                        external_status: '处理中',
                                        manual_override: false)

        # Scenario: External status changes to '已付款' which should map to closed
        row_data = ['R202501004', '更新报销单', '更新用户', 'UPD001', '更新公司', '更新部门', '600.00', '已付款']
        spreadsheet = mock_spreadsheet(row_data)

        expect do
          service.import(spreadsheet)
        end.not_to change(Reimbursement, :count)

        existing_reimbursement.reload
        expect(existing_reimbursement.external_status).to eq('已付款')
        expect(existing_reimbursement.status).to eq(Reimbursement::STATUS_CLOSED) # Should update to closed
      end

      it 'updates internal status for existing records when external status changes to pending payment status' do
        # Create an existing reimbursement without manual override
        existing_reimbursement = create(:reimbursement,
                                        invoice_number: 'R202501005',
                                        status: Reimbursement::STATUS_PENDING,
                                        external_status: '审批中',
                                        manual_override: false)

        # Scenario: External status changes to '待付款' which should map to closed
        row_data = ['R202501005', '更新报销单', '更新用户', 'UPD002', '更新公司', '更新部门', '700.00', '待付款']
        spreadsheet = mock_spreadsheet(row_data)

        expect do
          service.import(spreadsheet)
        end.not_to change(Reimbursement, :count)

        existing_reimbursement.reload
        expect(existing_reimbursement.external_status).to eq('待付款')
        expect(existing_reimbursement.status).to eq(Reimbursement::STATUS_CLOSED) # Should update to closed
      end

      it 'does not change internal status when manual override is enabled' do
        # Create an existing reimbursement with manual override enabled
        existing_reimbursement = create(:reimbursement,
                                        invoice_number: 'R202501006',
                                        status: Reimbursement::STATUS_PROCESSING,
                                        external_status: '处理中',
                                        manual_override: true)

        # Scenario: External status changes to '已付款' but manual override should prevent status change
        row_data = ['R202501006', '更新报销单', '更新用户', 'UPD003', '更新公司', '更新部门', '800.00', '已付款']
        spreadsheet = mock_spreadsheet(row_data)

        expect do
          service.import(spreadsheet)
        end.not_to change(Reimbursement, :count)

        existing_reimbursement.reload
        expect(existing_reimbursement.external_status).to eq('已付款')
        expect(existing_reimbursement.status).to eq(Reimbursement::STATUS_PROCESSING) # Should remain unchanged due to manual override
      end
    end

    context 'with invalid data' do
      it 'handles errors' do
        # Create a test spreadsheet
        spreadsheet = double('spreadsheet')

        # Mock the spreadsheet behavior
        allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
        allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                '申请人部门', '报销金额（单据币种）', '收单状态', '收单日期', '提交报销日期', '报销单状态', '单据标签', '报销单审核通过日期', '审核通过人'])
        allow(spreadsheet).to receive(:each_with_index).and_yield(
          ['', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '已收单', '2025-01-01', '2025-01-01', '审批中', '', '',
           ''], 1
        )

        result = service.import(spreadsheet)

        expect(result[:success]).to be true # 整体导入仍然成功
        expect(result[:created]).to eq(0)
        expect(result[:updated]).to eq(0)
        expect(result[:errors]).to eq(1)
        expect(result[:error_details].first).to include('报销单单号不能为空')
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
        tempfile = double('tempfile', path: '/tmp/test.csv', to_path: '/tmp/test.csv')
        file = double('file', tempfile: tempfile)
        service = described_class.new(file, admin_user)
        allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new('测试错误'))

        result = service.import

        expect(result[:success]).to be false
        expect(result[:error_details].first).to include('导入过程中发生错误')
      end

      describe 'automatic auditor assignment' do
        let!(:auditor1) { create(:admin_user, name: '张三') }
        let!(:auditor2) { create(:admin_user, name: '李四') }

        context 'when current approval node is "审核" and approver matches admin user' do
          let(:csv_content) do
            <<~CSV
              报销单单号,单据名称,报销单申请人,报销单申请人工号,申请人公司,申请人部门,报销金额（单据币种）,报销单状态,当前审批节点,当前审批人
              R202501010,测试报销单,测试用户,TEST001,测试公司,测试部门,100.00,审批中,审核,张三
            CSV
          end

          it 'automatically assigns the reimbursement to the matching auditor' do
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                    '申请人部门', '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield(
              ['R202501010', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '审批中', '审核', '张三'], 1
            )

            expect do
              service.import(spreadsheet)
            end.to change(ReimbursementAssignment, :count).by(1)

            reimbursement = Reimbursement.find_by(invoice_number: 'R202501010')
            assignment = reimbursement.active_assignment

            expect(assignment).to be_present
            expect(assignment.assignee).to eq(auditor1)
            expect(assignment.assigner).to eq(admin_user)
            expect(assignment.is_active).to be true
            expect(assignment.notes).to include('自动分配：导入时检测到审核节点和审核人匹配')
          end

          it 'handles approver name with extra content' do
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                    '申请人部门', '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield(
              ['R202501011', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '审批中', '审核', '财务经理张三'], 1
            )

            expect do
              service.import(spreadsheet)
            end.to change(ReimbursementAssignment, :count).by(1)

            reimbursement = Reimbursement.find_by(invoice_number: 'R202501011')
            assignment = reimbursement.active_assignment

            expect(assignment).to be_present
            expect(assignment.assignee).to eq(auditor1)
          end
        end

        context 'when current approval node is not "审核"' do
          it 'does not assign the reimbursement' do
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                    '申请人部门', '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield(
              ['R202501012', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '审批中', '提交', '张三'], 1
            )

            expect do
              service.import(spreadsheet)
            end.not_to change(ReimbursementAssignment, :count)

            reimbursement = Reimbursement.find_by(invoice_number: 'R202501012')
            expect(reimbursement.active_assignment).to be_nil
          end
        end

        context 'when approver does not match any admin user' do
          it 'does not assign the reimbursement' do
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                    '申请人部门', '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield(
              ['R202501013', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '审批中', '审核', '王五'], 1
            )

            expect do
              service.import(spreadsheet)
            end.not_to change(ReimbursementAssignment, :count)

            reimbursement = Reimbursement.find_by(invoice_number: 'R202501013')
            expect(reimbursement.active_assignment).to be_nil
          end
        end

        context 'when approver field is blank' do
          it 'does not assign the reimbursement' do
            spreadsheet = double('spreadsheet')
            allow(spreadsheet).to receive(:respond_to?).with(:sheet).and_return(false)
            allow(spreadsheet).to receive(:row).with(1).and_return(['报销单单号', '单据名称', '报销单申请人', '报销单申请人工号', '申请人公司',
                                                                    '申请人部门', '报销金额（单据币种）', '报销单状态', '当前审批节点', '当前审批人'])
            allow(spreadsheet).to receive(:each_with_index).and_yield(
              ['R202501014', '测试报销单', '测试用户', 'TEST001', '测试公司', '测试部门', '100.00', '审批中', '审核', ''], 1
            )

            expect do
              service.import(spreadsheet)
            end.not_to change(ReimbursementAssignment, :count)

            reimbursement = Reimbursement.find_by(invoice_number: 'R202501014')
            expect(reimbursement.active_assignment).to be_nil
          end
        end
      end
    end
  end
end
