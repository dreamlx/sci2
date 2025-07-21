require 'rails_helper'

RSpec.describe ProblemCodeImportService, type: :service do
  let(:csv_content) do
    <<~CSV
      Document Code,Meeting Code,会议类型,Expense Code,费用类型,Issue Code,问题类型,SOP描述,标准处理方法
      EN000101,00,个人,01,月度交通费（销售/SMO/CO),01,燃油费行程问题,根据SOP规定，月度交通费报销燃油费需提供每张燃油费的使用时间区间，行程为医院的需具体到科室,请根据要求在评论区将行程补充完整
      EN000102,00,个人,01,月度交通费（销售/SMO/CO),02,出租车行程问题,根据SOP规定，月度交通费报销出租车费用，需注明具体的行程地点和事由，行程为医院的，应明确注明拜访医院及科室,请根据要求补充至HLY评论区
      EN000201,00,个人,02,交通费-市内,01,出租车行程问题,根据SOP规定，驻地内产生的出租车，公共汽车、地铁等发票，报销时需列明行程和事由,请根据要求补充至HLY评论区
    CSV
  end

  let(:csv_file_path) do
    file = Tempfile.new(['test_problem_codes', '.csv'])
    file.write(csv_content)
    file.close
    file.path
  end

  after do
    File.unlink(csv_file_path) if File.exist?(csv_file_path)
  end

  describe '#import' do
    let(:service) { described_class.new(csv_file_path) }
    
    context '导入新的费用类型和问题类型' do
      it '应该创建新的费用类型，code为Meeting Code + Expense Code的组合' do
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:imported_fee_types]).to be > 0
        }.to change(FeeType, :count)

        # 验证费用类型
        fee_type_0001 = FeeType.find_by(code: '0001')
        expect(fee_type_0001).not_to be_nil
        expect(fee_type_0001.title).to eq('月度交通费（销售/SMO/CO)')
        expect(fee_type_0001.meeting_type).to eq('个人')

        fee_type_0002 = FeeType.find_by(code: '0002')
        expect(fee_type_0002).not_to be_nil
        expect(fee_type_0002.title).to eq('交通费-市内')
        expect(fee_type_0002.meeting_type).to eq('个人')
      end

      it '应该创建新的问题类型并关联到正确的费用类型' do
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:imported_problem_types]).to be > 0
        }.to change(ProblemType, :count)

        # 验证问题类型
        problem_type_1 = ProblemType.find_by(code: 'EN000101')
        expect(problem_type_1).not_to be_nil
        expect(problem_type_1.title).to eq('燃油费行程问题')
        expect(problem_type_1.fee_type.code).to eq('0001')

        problem_type_2 = ProblemType.find_by(code: 'EN000102')
        expect(problem_type_2).not_to be_nil
        expect(problem_type_2.title).to eq('出租车行程问题')
        expect(problem_type_2.fee_type.code).to eq('0001')

        problem_type_3 = ProblemType.find_by(code: 'EN000201')
        expect(problem_type_3).not_to be_nil
        expect(problem_type_3.title).to eq('出租车行程问题')
        expect(problem_type_3.fee_type.code).to eq('0002')
      end
    end

    context '更新已存在的费用类型和问题类型' do
      before do
        # 创建已存在的费用类型，但title不同
        FeeType.create!(
          code: '0001',
          title: '旧的费用类型名称',
          meeting_type: '个人',
          active: true
        )
        
        # 创建已存在的问题类型，但关联的费用类型不同
        ProblemType.create!(
          code: 'EN000101',
          title: '旧的问题类型名称',
          sop_description: '旧的SOP描述',
          standard_handling: '旧的标准处理方法',
          active: true
        )
      end

      it '应该更新已存在的费用类型的title' do
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:updated_fee_types]).to be > 0
        }.not_to change(FeeType, :count)

        # 验证更新
        fee_type = FeeType.find_by(code: '0001')
        expect(fee_type.title).to eq('月度交通费（销售/SMO/CO)')
      end

      it '应该更新已存在的问题类型的关联费用类型和其他属性' do
        expect {
          result = service.import
          expect(result[:success]).to be true
          expect(result[:updated_problem_types]).to be > 0
        }.not_to change { ProblemType.where(code: 'EN000101').count }

        # 验证更新
        problem_type = ProblemType.find_by(code: 'EN000101')
        expect(problem_type.title).to eq('燃油费行程问题')
        expect(problem_type.sop_description).to eq('根据SOP规定，月度交通费报销燃油费需提供每张燃油费的使用时间区间，行程为医院的需具体到科室')
        expect(problem_type.fee_type).not_to be_nil
        expect(problem_type.fee_type.code).to eq('0001')
      end
    end

    context '处理边界情况' do
      let(:invalid_csv_content) do
        <<~CSV
          Document Code,Meeting Code,会议类型,Expense Code,费用类型,Issue Code,问题类型,SOP描述,标准处理方法
          EN000101,,个人,01,月度交通费（销售/SMO/CO),01,燃油费行程问题,根据SOP规定，月度交通费报销燃油费需提供每张燃油费的使用时间区间，行程为医院的需具体到科室,请根据要求在评论区将行程补充完整
          EN000102,00,,01,月度交通费（销售/SMO/CO),02,出租车行程问题,根据SOP规定，月度交通费报销出租车费用，需注明具体的行程地点和事由，行程为医院的，应明确注明拜访医院及科室,请根据要求补充至HLY评论区
          EN000201,00,个人,,交通费-市内,01,出租车行程问题,根据SOP规定，驻地内产生的出租车，公共汽车、地铁等发票，报销时需列明行程和事由,请根据要求补充至HLY评论区
        CSV
      end

      let(:invalid_csv_file_path) do
        file = Tempfile.new(['invalid_problem_codes', '.csv'])
        file.write(invalid_csv_content)
        file.close
        file.path
      end

      after do
        File.unlink(invalid_csv_file_path) if File.exist?(invalid_csv_file_path)
      end

      let(:invalid_service) { described_class.new(invalid_csv_file_path) }

      it '应该跳过缺少必要字段的行' do
        expect {
          result = invalid_service.import
          expect(result[:success]).to be true
          expect(result[:imported_fee_types]).to eq(0)
          expect(result[:imported_problem_types]).to eq(0)
        }.not_to change(FeeType, :count)
      end
    end
  end
end