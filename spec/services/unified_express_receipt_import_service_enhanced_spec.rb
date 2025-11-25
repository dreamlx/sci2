# spec/services/unified_express_receipt_import_service_enhanced_spec.rb
require 'rails_helper'

RSpec.describe UnifiedExpressReceiptImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, invoice_number: 'INV001') }
  let(:valid_csv_content) do
    CSV.generate do |csv|
      csv << ['单据编号', '操作意见', '操作时间', 'Filling ID']
      csv << ['INV001', '快递单号：SF123456789', '2025-01-01 10:00:00', 'FILL001']
      csv << ['INV001', '快递单号：JD987654321', '2025-01-02 11:00:00', 'FILL002']
    end
  end

  let(:valid_csv_file) { Tempfile.new(['test_express_receipt', '.csv']) }

  before do
    valid_csv_file.write(valid_csv_content)
    valid_csv_file.rewind
    Current.admin_user = admin_user
  end

  after do
    valid_csv_file.close
    valid_csv_file.unlink
  end

  describe '增强功能测试' do
    let(:service) { described_class.new(valid_csv_file, admin_user) }

    describe '重复记录检查功能' do
      context '存在重复记录时' do
        before do
          # 创建一个已存在的快递收单工单
          create(:express_receipt_work_order,
                 reimbursement: reimbursement,
                 tracking_number: 'SF123456789')
        end

        it '跳过重复记录' do
          result = service.import

          expect(result[:success]).to be true
          expect(result[:created]).to eq(1) # 只创建第二条记录
          expect(result[:skipped]).to eq(1)  # 跳过第一条重复记录
          expect(ExpressReceiptWorkOrder.count).to eq(2) # 原有1条 + 新增1条
        end

        it '记录跳过原因到日志' do
          expect(Rails.logger).to receive(:info).with(/跳过重复记录.*SF123456789/)
          service.import
        end
      end

      context '没有重复记录时' do
        it '正常创建所有记录' do
          result = service.import

          expect(result[:success]).to be true
          expect(result[:created]).to eq(2)
          expect(result[:skipped]).to eq(0)
          expect(ExpressReceiptWorkOrder.count).to eq(2)
        end
      end
    end

    describe '事务保护功能' do
      context '数据验证失败时' do
        let(:invalid_csv_content) do
          CSV.generate do |csv|
            csv << ['单据编号', '操作意见', '操作时间']
            csv << ['INVALID_INVOICE', '快递单号：SF123456789', 'invalid_date'] # 无效数据
          end
        end

        let(:invalid_csv_file) { Tempfile.new(['invalid_express', '.csv']) }

        before do
          invalid_csv_file.write(invalid_csv_content)
          invalid_csv_file.rewind
        end

        after do
          invalid_csv_file.close
          invalid_csv_file.unlink
        end

        it '不创建任何记录' do
          service = described_class.new(invalid_csv_file, admin_user)
          expect { service.import }.not_to change(ExpressReceiptWorkOrder, :count)
        end
      end
    end

    describe '状态管理功能' do
      it '更新报销单状态为已收单' do
        service.import

        reimbursement.reload
        expect(reimbursement.receipt_status).to eq('received')
        expect(reimbursement.received_at).to be_present
      end

      it '重置通知状态' do
        # 设置已查看的通知状态
        reimbursement.update_column(:last_viewed_express_receipts_at, Time.current)

        service.import

        reimbursement.reload
        expect(reimbursement.last_viewed_express_receipts_at).to be_nil
      end

      it '记录通知重置到日志' do
        expect(Rails.logger).to receive(:debug).with(/重置报销单.*通知状态/)
        service.import
      end
    end

    describe '增强时间解析功能' do
      context '各种时间格式支持' do
        let(:time_formats_csv_content) do
          CSV.generate do |csv|
            csv << ['单据编号', '操作意见', '操作时间']
            csv << [reimbursement.invoice_number, '快递单号：SF123', '2025-01-01 10:30:00'] # 标准格式
            csv << [reimbursement.invoice_number, '快递单号：JD456', '2025/01/02 14:20:00'] # 斜杠格式
            csv << [reimbursement.invoice_number, '快递单号：YT789', '2025-01-03']          # 日期格式
          end
        end

        let(:time_formats_file) { Tempfile.new(['time_formats', '.csv']) }

        before do
          time_formats_file.write(time_formats_csv_content)
          time_formats_file.rewind
        end

        after do
          time_formats_file.close
          time_formats_file.unlink
        end

        it '正确解析多种时间格式' do
          service = described_class.new(time_formats_file, admin_user)
          result = service.import

          expect(result[:success]).to be true
          expect(result[:created]).to eq(3)

          work_orders = ExpressReceiptWorkOrder.order(:received_at)
          expect(work_orders[0].received_at.strftime('%Y-%m-%d %H:%M:%S')).to eq('2025-01-01 10:30:00')
          expect(work_orders[1].received_at.strftime('%Y-%m-%d %H:%M:%S')).to eq('2025-01-02 14:20:00')
          expect(work_orders[2].received_at.strftime('%Y-%m-%d')).to eq('2025-01-03')
        end
      end

      context 'Excel序列号格式拒绝' do
        let(:excel_serial_csv) do
          CSV.generate do |csv|
            csv << ['单据编号', '操作意见', '操作时间']
            csv << [reimbursement.invoice_number, '快递单号：SF123', '44726.5'] # Excel序列号
          end
        end

        let(:excel_serial_file) { Tempfile.new(['excel_serial', '.csv']) }

        before do
          excel_serial_file.write(excel_serial_csv)
          excel_serial_file.rewind
        end

        after do
          excel_serial_file.close
          excel_serial_file.unlink
        end

        it '拒绝Excel序列号格式' do
          expect(Rails.logger).to receive(:warn).with(/拒绝Excel序列号格式的时间字符串/)
          service = described_class.new(excel_serial_file, admin_user)
          result = service.import

          expect(result[:success]).to be true # 应该处理成功但时间为nil
          expect(ExpressReceiptWorkOrder.first.received_at).to be_nil
        end
      end
    end

    describe '错误处理增强' do
      context '状态机转换错误' do
        it '处理状态转换错误并记录' do
          # 模拟状态机错误
          allow_any_instance_of(Reimbursement).to receive(:mark_as_received).and_raise(
            StateMachines::InvalidTransition, 'Invalid transition'
          )

          service = described_class.new(valid_csv_file, admin_user)
          result = service.import

          expect(result[:success]).to be true # 第一条记录失败但第二条可能成功
          expect(result[:errors]).to include(/更新报销单状态失败/)
          expect(result[:errors]).to include(/Invalid transition/)
        end
      end

      context '事务处理错误' do
        it '处理事务错误并记录' do
          # 模拟事务错误
          allow(ActiveRecord::Base).to receive(:transaction).and_raise(
            StandardError, 'Transaction failed'
          )

          service = described_class.new(valid_csv_file, admin_user)
          result = service.import

          expect(result[:success]).to be false
          expect(result[:errors]).to include(/事务处理失败/)
        end
      end
    end

    describe '字段映射增强' do
      let(:alternative_fields_csv) do
        CSV.generate do |csv|
          csv << ['报销单号', '备注', '收单时间', '填充ID'] # 使用替代字段名
          csv << [reimbursement.invoice_number, '快递单号：SF_ALTERNATIVE', '2025-01-01 15:00', 'ALT001']
        end
      end

      let(:alternative_fields_file) { Tempfile.new(['alternative_fields', '.csv']) }

      before do
        alternative_fields_file.write(alternative_fields_csv)
        alternative_fields_file.rewind
      end

      after do
        alternative_fields_file.close
        alternative_fields_file.unlink
      end

      it '支持多种字段名变体' do
        service = described_class.new(alternative_fields_file, admin_user)
        result = service.import

        expect(result[:success]).to be true
        expect(result[:created]).to eq(1)

        work_order = ExpressReceiptWorkOrder.first
        expect(work_order.tracking_number).to eq('SF_ALTERNATIVE')
        expect(work_order.received_at.strftime('%Y-%m-%d %H:%M')).to eq('2025-01-01 15:00')
        expect(work_order.filling_id).to eq('ALT001')
      end
    end

    describe '工单状态设置' do
      it '设置工单状态为completed' do
        service.import

        ExpressReceiptWorkOrder.all.each do |work_order|
          expect(work_order.status).to eq('completed')
        end
      end

      it '保留原始数据到data_source字段' do
        service.import

        ExpressReceiptWorkOrder.all.each do |work_order|
          expect(work_order.data_source).to be_present
          expect(work_order.data_source).to be_a(String)
          expect(JSON.parse(work_order.data_source)).to be_a(Hash)
        end
      end
    end
  end

  describe '性能和兼容性测试' do
    describe 'BaseImportService继承' do
      it '正确继承BaseImportService' do
        service = described_class.new(valid_csv_file, admin_user)
        expect(service).to be_a(BaseImportService)
      end

      it '继承BaseImportService的所有方法' do
        service = described_class.new(valid_csv_file, admin_user)

        # 验证基础的验证方法存在
        expect(service).to respond_to(:validate_file, true)
        expect(service).to respond_to(:parse_file, true)
        expect(service).to respond_to(:handle_error, true)
      end
    end

    describe '文件扩展名支持' do
      %w[.csv .xls .xlsx .XLS .XLSX].each do |extension|
        it "支持#{extension}文件格式" do
          allow(File).to receive(:extname).and_return(extension)
          expect(service.send(:supported_extension?, extension.delete('.'))).to be_truthy
        end
      end
    end

    describe '边界条件处理' do
      it '处理空文件' do
        empty_file = Tempfile.new(['empty', '.csv'])
        empty_file.write('')
        empty_file.rewind

        service = described_class.new(empty_file, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/缺少必需字段/)

        empty_file.close
        empty_file.unlink
      end

      it '处理只有表头的文件' do
        headers_only_file = Tempfile.new(['headers_only', '.csv'])
        headers_only_file.write('单据编号,操作意见,操作时间')
        headers_only_file.rewind

        service = described_class.new(headers_only_file, admin_user)
        result = service.import

        expect(result[:success]).to be true # 没有数据行也算成功
        expect(result[:created]).to eq(0)

        headers_only_file.close
        headers_only_file.unlink
      end
    end
  end
end