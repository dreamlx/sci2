require 'rails_helper'

RSpec.describe OptimizedUnifiedFeeDetailImportService do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:fee_type) { create(:fee_type, name: '差旅费') }
  let(:valid_csv_content) do
    CSV.generate do |csv|
      csv << ['报销单单号', '费用类型', '原始金额', '费用发生日期', '费用说明']
      csv << [reimbursement.invoice_number, fee_type.name, '100.00', '2025-01-01', '差旅费-交通费']
      csv << [reimbursement.invoice_number, fee_type.name, '200.00', '2025-01-02', '差旅费-住宿费']
    end
  end

  let(:valid_csv_file) { Tempfile.new(['test_fee_details', '.csv']) }

  before do
    valid_csv_file.write(valid_csv_content)
    valid_csv_file.rewind
    Current.admin_user = admin_user
  end

  after do
    valid_csv_file.close
    valid_csv_file.unlink
  end

  describe '#initialize' do
    it '正确初始化服务实例' do
      service = described_class.new(valid_csv_file, admin_user)

      expect(service).to be_a(described_class)
      expect(service).to be_a(BaseImportService)
      expect(service.file).to eq(valid_csv_file)
      expect(service.current_admin_user).to eq(admin_user)
    end

    it '初始化性能组件' do
      service = described_class.new(valid_csv_file, admin_user)

      expect(service.instance_variable_get(:@batch_manager)).to be_a(BatchImportManager)
      expect(service.instance_variable_get(:@sqlite_optimizer)).to be_a(SqliteOptimizationManager)
    end

    it '支持选项参数' do
      service = described_class.new(valid_csv_file, admin_user, skip_existing: true)

      expect(service.instance_variable_get(:@skip_existing)).to be true
    end
  end

  describe '#import' do
    context '成功导入' do
      it '导入有效的CSV文件' do
        service = described_class.new(valid_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true
        expect(result[:created]).to eq(2)
        expect(result[:errors]).to eq(0)

        # 验证数据库记录
        expect(FeeDetail.count).to eq(2)
        expect(FeeDetail.pluck(:amount)).to contain_exactly(100.0, 200.0)
      end

      it '正确设置费用明细属性' do
        service = described_class.new(valid_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true

        fee_detail = FeeDetail.first
        expect(fee_detail.document_number).to eq(reimbursement.invoice_number)
        expect(fee_detail.fee_type).to eq(fee_type.name)
        expect(fee_detail.amount).to eq(100.0)
        expect(fee_detail.fee_date).to eq(Date.parse('2025-01-01'))
        expect(fee_detail.notes).to eq('差旅费-交通费')
        expect(fee_detail.verification_status).to eq('pending')
      end

      it '返回性能统计信息' do
        service = described_class.new(valid_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true
        expect(result[:performance_stats]).to be_a(Hash)
        expect(result[:performance_stats]).to have_key(:total_processed)
        expect(result[:performance_stats]).to have_key(:duration)
        expect(result[:performance_stats]).to have_key(:records_per_second)
      end

      it '批量更新相关报销单状态' do
        service = described_class.new(valid_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true

        # 验证报销单状态更新
        reimbursement.reload
        expect(reimbursement.status).to eq('processing')
      end
    end

    context '字段映射测试' do
      let(:alternative_csv_content) do
        CSV.generate do |csv|
          csv << ['单据编号', '费用名称', '金额', '日期', '备注']
          csv << [reimbursement.invoice_number, fee_type.name, '150.00', '2025-01-03', '其他费用']
        end
      end

      let(:alternative_csv_file) { Tempfile.new(['alternative_fee_details', '.csv']) }

      before do
        alternative_csv_file.write(alternative_csv_content)
        alternative_csv_file.rewind
      end

      after do
        alternative_csv_file.close
        alternative_csv_file.unlink
      end

      it '支持多种字段名变体' do
        service = described_class.new(alternative_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true
        expect(result[:created]).to eq(1)

        fee_detail = FeeDetail.first
        expect(fee_detail.amount).to eq(150.0)
        expect(fee_detail.notes).to eq('其他费用')
      end
    end

    context '数据验证测试' do
      let(:invalid_csv_content) do
        CSV.generate do |csv|
          csv << ['报销单单号', '费用类型', '原始金额', '费用发生日期']
          csv << ['INVALID_INVOICE', fee_type.name, '100.00', '2025-01-01'] # 无效报销单号
          csv << [reimbursement.invoice_number, 'INVALID_TYPE', '200.00', '2025-01-02'] # 无效费用类型
          csv << [reimbursement.invoice_number, fee_type.name, 'invalid_amount', '2025-01-03'] # 无效金额
          csv << [reimbursement.invoice_number, fee_type.name, '300.00', 'invalid_date'] # 无效日期
        end
      end

      let(:invalid_csv_file) { Tempfile.new(['invalid_fee_details', '.csv']) }

      before do
        invalid_csv_file.write(invalid_csv_content)
        invalid_csv_file.rewind
      end

      after do
        invalid_csv_file.close
        invalid_csv_file.unlink
      end

      it '正确处理无效数据' do
        service = described_class.new(invalid_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to be > 0
        expect(result[:error_details]).to include(/报销单不存在/)
        expect(result[:error_details]).to include(/费用类型不存在/)
        expect(result[:error_details]).to include(/无效的金额格式/)
        expect(result[:error_details]).to include(/无效的日期格式/)
      end
    end

    context '必需字段验证' do
      let(:missing_fields_csv_content) do
        CSV.generate do |csv|
          csv << ['报销单单号', '费用类型'] # 缺少必需字段
          csv << [reimbursement.invoice_number, fee_type.name]
        end
      end

      let(:missing_fields_csv_file) { Tempfile.new(['missing_fields', '.csv']) }

      before do
        missing_fields_csv_file.write(missing_fields_csv_content)
        missing_fields_csv_file.rewind
      end

      after do
        missing_fields_csv_file.close
        missing_fields_csv_file.unlink
      end

      it '验证必需字段存在' do
        service = described_class.new(missing_fields_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/缺少必需字段/)
      end
    end

    context '文件验证' do
      it '处理不存在的文件' do
        service = described_class.new(nil, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/文件不存在/)
      end

      it '处理空文件' do
        empty_file = Tempfile.new(['empty', '.csv'])
        empty_file.rewind

        service = described_class.new(empty_file, admin_user)
        result = service.import

        expect(result[:success]).to be false
        expect(result[:errors]).to include(/缺少必需字段/)

        empty_file.close
        empty_file.unlink
      end
    end

    context '性能优化测试' do
      let(:large_csv_content) do
        CSV.generate do |csv|
          csv << ['报销单单号', '费用类型', '原始金额', '费用发生日期', '费用说明']
          50.times do |i|
            csv << [reimbursement.invoice_number, fee_type.name, "#{i + 1}.00", "2025-01-#{(i % 28) + 1}", "费用项#{i + 1}"]
          end
        end
      end

      let(:large_csv_file) { Tempfile.new(['large_fee_details', '.csv']) }

      before do
        large_csv_file.write(large_csv_content)
        large_csv_file.rewind
      end

      after do
        large_csv_file.close
        large_csv_file.unlink
      end

      it '处理大量数据时保持性能' do
        service = described_class.new(large_csv_file, admin_user)
        start_time = Time.current

        result = service.import
        end_time = Time.current

        expect(result[:success]).to be true
        expect(result[:created]).to eq(50)

        # 验证性能统计
        expect(result[:performance_stats][:total_processed]).to eq(50)
        expect(result[:performance_stats][:duration]).to be < 5.0 # 应该在5秒内完成
        expect(result[:performance_stats][:records_per_second]).to be > 10 # 每秒至少处理10条记录
      end

      it '使用批量处理优化' do
        service = described_class.new(large_csv_file, admin_user)
        result = service.import

        expect(result[:success]).to be true

        # 验证批量处理被使用
        stats = result[:performance_stats]
        expect(stats[:batches_processed]).to be > 0
      end
    end

    context 'SQLite优化测试' do
      it '应用SQLite优化设置' do
        service = described_class.new(valid_csv_file, admin_user)

        # 验证优化器被正确初始化
        optimizer = service.instance_variable_get(:@sqlite_optimizer)
        expect(optimizer).to be_a(SqliteOptimizationManager)
        expect(optimizer.level).to eq(:moderate)
      end
    end
  end

  describe '私有方法测试' do
    let(:service) { described_class.new(valid_csv_file, admin_user) }

    describe '#extract_field_value' do
      it '根据映射提取字段值' do
        row_data = {
          '报销单单号' => 'INV001',
          '费用类型' => '差旅费',
          '原始金额' => '100.00'
        }

        expect(service.send(:extract_field_value, row_data, :document_number)).to eq('INV001')
        expect(service.send(:extract_field_value, row_data, :fee_type)).to eq('差旅费')
        expect(service.send(:extract_field_value, row_data, :original_amount)).to eq('100.00')
      end

      it '处理空值和缺失字段' do
        row_data = { '报销单单号' => 'INV001' }

        expect(service.send(:extract_field_value, row_data, :document_number)).to eq('INV001')
        expect(service.send(:extract_field_value, row_data, :fee_type)).to be_nil
      end
    end

    describe '#parse_amount' do
      it '解析各种金额格式' do
        expect(service.send(:parse_amount, '100.00')).to eq(100.0)
        expect(service.send(:parse_amount, '￥100.00')).to eq(100.0)
        expect(service.send(:parse_amount, '$100.00')).to eq(100.0)
        expect(service.send(:parse_amount, '1,000.00')).to eq(1000.0)
        expect(service.send(:parse_amount, '100')).to eq(100.0)
      end

      it '处理无效金额格式' do
        expect(service.send(:parse_amount, 'invalid')).to be_nil
        expect(service.send(:parse_amount, '')).to be_nil
        expect(service.send(:parse_amount, nil)).to be_nil
      end
    end
  end
end