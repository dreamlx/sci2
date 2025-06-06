require 'rails_helper'

RSpec.describe ProblemCodeImportService do
  let(:csv_path) { Rails.root.join('docs', 'user_data', '个人问题code.csv') }
  let(:meeting_type) { "个人" }
  let(:service) { ProblemCodeImportService.new(csv_path, meeting_type) }

  describe "#import" do
    before do
      # Clear existing data
      ProblemType.delete_all
      FeeType.delete_all
      
      # Run import
      @result = service.import
    end

    it "creates all expected FeeTypes" do
      expect(FeeType.count).to be > 0
      expect(FeeType.pluck(:title)).to include(
        '月度交通费（销售/SMO/CO）',
        '电话费',
        '交通费-市内',
        '工作餐',
        '办公用品'
      )
    end

    it "creates all expected ProblemTypes" do
      expect(ProblemType.count).to be > 0
      expect(ProblemType.pluck(:title)).to include(
        '燃油费行程问题',
        '手机号未备案', 
        '单次超500问题',
        '套餐超350元'
      )
    end

    it "properly associates ProblemTypes with FeeTypes" do
      # Verify specific associations
      transport_fee = FeeType.find_by(title: '月度交通费（销售/SMO/CO）')
      phone_fee = FeeType.find_by(title: '电话费')
      
      expect(ProblemType.find_by(title: '燃油费行程问题').fee_type).to eq(transport_fee)
      expect(ProblemType.find_by(title: '手机号未备案').fee_type).to eq(phone_fee)
    end

    it "returns correct import statistics" do
      expect(@result[:imported_fee_types]).to be > 0
      expect(@result[:imported_problem_types]).to be > 0
      expect(@result[:details][:fee_types].size).to eq(@result[:imported_fee_types] + @result[:updated_fee_types])
      expect(@result[:details][:problem_types].size).to eq(@result[:imported_problem_types] + @result[:updated_problem_types])
    end
  end
end