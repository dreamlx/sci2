# spec/services/filling_id_generator_spec.rb
require 'rails_helper'

RSpec.describe FillingIdGenerator do
  describe '.generate' do
    let(:current_time) { Time.current }
    let(:admin_user) { create(:admin_user) }
    let(:reimbursement) { create(:reimbursement) }

    it '生成正确格式的填充ID（10位数字）' do
      filling_id = described_class.generate(current_time)
      expect(filling_id).to match(/\A\d{10}\z/)
    end

    it '填充ID包含4位年份和2位月份' do
      filling_id = described_class.generate(current_time)
      year_month = current_time.strftime('%Y%m')
      expect(filling_id[0..5]).to eq(year_month)
    end

    it '填充ID包含4位流水号' do
      filling_id = described_class.generate(current_time)
      sequence = filling_id[6..9]
      expect(sequence).to match(/\d{4}/)
      expect(sequence.to_i).to be_between(1, 9999)
    end

    it '同一个月内的多次调用生成递增的流水号' do
      time = Time.new(2025, 9, 15)

      # 设置当前用户以避免外键约束错误
      Current.admin_user = admin_user

      # 创建测试记录来模拟数据库中的现有记录
      reimbursement = create(:reimbursement, invoice_number: 'TEST001')

      # 第一次生成应该返回0001
      id1 = described_class.generate(time)
      sequence1 = id1[6..9].to_i
      expect(sequence1).to eq(1)

      # 创建一个实际记录来保存第一个填充ID
      ExpressReceiptWorkOrder.create!(
        reimbursement: reimbursement,
        tracking_number: 'TEST123',
        received_at: time,
        status: 'completed',
        filling_id: id1,
        created_by: admin_user.id
      )

      # 第二次生成应该返回0002
      id2 = described_class.generate(time)
      sequence2 = id2[6..9].to_i
      expect(sequence2).to eq(2)
    end

    it '不同月份生成不同的年份月份部分' do
      september = Time.new(2025, 9, 15)
      october = Time.new(2025, 10, 15)

      id_sep = described_class.generate(september)
      id_oct = described_class.generate(october)

      expect(id_sep[0..5]).to eq('202509')
      expect(id_oct[0..5]).to eq('202510')
    end

    it '不同月份的流水号从0001重新开始' do
      september = Time.new(2025, 9, 15)
      october = Time.new(2025, 10, 15)

      # 在9月生成一个ID
      described_class.generate(september)

      # 在10月生成ID，流水号应该从0001开始
      id_oct = described_class.generate(october)
      sequence_oct = id_oct[6..9].to_i

      expect(sequence_oct).to eq(1)
    end

    it '处理nil时间参数，使用当前时间' do
      filling_id = described_class.generate(nil)
      expect(filling_id).to match(/\A\d{10}\z/)
    end
  end
end
