require 'rails_helper'

RSpec.describe FeeDetailImportService, type: :service do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement, invoice_number: 'ER14269496') }

  describe '弹性字段导入测试' do
    let(:csv_content) do
      <<~CSV
        所属月,费用类型,申请人名称,申请人工号,申请人公司,申请人部门,费用发生日期,原始金额,单据名称,报销单单号,关联申请单号,计划/预申请,产品,弹性字段11,弹性字段6(报销单),弹性字段7(报销单),费用id,首次提交日期,费用对应计划,费用关联申请单
        2024-06,会议讲课费,彭肖军,20150620,SPC,OBU-E1,2024-06-17 11:12:29,2000.00,学术会议报销单,ER14269496,,300116793_OBU-E-ZM2-202406-001_肿瘤骨健康病例分享会/ OBU-E-ZM2-202406-001,,,ZMT-乳腺癌,圆桌讨论会,1807613410305753090,2024-07-02 18:23:31,,
        2024-05,电话费,梅文达,20181101,SPC,FIN,2024-06-02 00:00:00,323.86,个人日常和差旅（含小沟会）报销单,ER14269496,EA08588801,,,个人卡,,,1806265772805390337,2024-07-01 16:13:33,,
      CSV
    end

    let(:csv_file) do
      file = Tempfile.new(['test_fee_details', '.csv'])
      file.write(csv_content)
      file.rewind

      # 模拟上传文件对象
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: file,
        filename: 'test_fee_details.csv',
        type: 'text/csv'
      )
      uploaded_file
    end

    before do
      reimbursement # 确保报销单存在
    end

    after do
      csv_file.tempfile.close
      csv_file.tempfile.unlink
    end

    it '正确导入弹性字段数据' do
      service = FeeDetailImportService.new(csv_file, admin_user)
      result = service.import

      expect(result[:success]).to be true
      expect(result[:created]).to eq 2

      # 验证第一条记录的弹性字段
      fee_detail_1 = FeeDetail.find_by(external_fee_id: '1807613410305753090')
      expect(fee_detail_1).to be_present
      expect(fee_detail_1.flex_field_6).to eq 'ZMT-乳腺癌'
      expect(fee_detail_1.flex_field_7).to eq '圆桌讨论会'
      expect(fee_detail_1.flex_field_11).to be_blank

      # 验证第二条记录的弹性字段
      fee_detail_2 = FeeDetail.find_by(external_fee_id: '1806265772805390337')
      expect(fee_detail_2).to be_present
      expect(fee_detail_2.flex_field_6).to be_blank
      expect(fee_detail_2.flex_field_7).to be_blank
      expect(fee_detail_2.flex_field_11).to eq '个人卡'
    end

    it '弹性字段影响meeting_type_context方法' do
      service = FeeDetailImportService.new(csv_file, admin_user)
      service.import

      # 测试包含"圆桌讨论会"的记录
      fee_detail_1 = FeeDetail.find_by(external_fee_id: '1807613410305753090')
      expect(fee_detail_1.meeting_type_context).to eq '学术论坛'

      # 测试不包含会议关键词的记录
      fee_detail_2 = FeeDetail.find_by(external_fee_id: '1806265772805390337')
      expect(fee_detail_2.meeting_type_context).to eq '个人'
    end

    it '处理空白弹性字段' do
      csv_with_blanks = <<~CSV
        所属月,费用类型,申请人名称,申请人工号,申请人公司,申请人部门,费用发生日期,原始金额,单据名称,报销单单号,关联申请单号,计划/预申请,产品,弹性字段11,弹性字段6(报销单),弹性字段7(报销单),费用id,首次提交日期,费用对应计划,费用关联申请单
        2024-06,会议讲课费,彭肖军,20150620,SPC,OBU-E1,2024-06-17 11:12:29,2000.00,学术会议报销单,ER14269496,,,,,,,1807613410305753091,2024-07-02 18:23:31,,
      CSV

      file = Tempfile.new(['test_blanks', '.csv'])
      file.write(csv_with_blanks)
      file.rewind

      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: file,
        filename: 'test_blanks.csv',
        type: 'text/csv'
      )

      service = FeeDetailImportService.new(uploaded_file, admin_user)
      result = service.import

      expect(result[:success]).to be true

      fee_detail = FeeDetail.find_by(external_fee_id: '1807613410305753091')
      expect(fee_detail.flex_field_6).to be_blank
      expect(fee_detail.flex_field_7).to be_blank
      expect(fee_detail.flex_field_11).to be_blank

      file.close
      file.unlink
    end
  end
end
