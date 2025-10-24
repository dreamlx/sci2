require 'rails_helper'

RSpec.describe 'FeeType and ProblemType', type: :model do
  describe 'FeeType' do
    it 'can be created with valid attributes' do
      fee_type = FeeType.new(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )

      expect(fee_type).to be_valid
      expect(fee_type.save).to be true
    end

    it 'requires a unique code' do
      FeeType.create!(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )

      duplicate = FeeType.new(
        code: '00',
        title: 'Another Fee Type',
        meeting_type: '个人',
        active: true
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to include('已经被使用')
    end

    it 'requires a title' do
      fee_type = FeeType.new(
        code: '01',
        meeting_type: '个人',
        active: true
      )

      expect(fee_type).not_to be_valid
      expect(fee_type.errors[:title]).to include('不能为空')
    end

    it 'requires a meeting_type' do
      fee_type = FeeType.new(
        code: '01',
        title: 'Some Fee Type',
        active: true
      )

      expect(fee_type).not_to be_valid
      expect(fee_type.errors[:meeting_type]).to include('不能为空')
    end

    it 'has a display_name that combines code and title' do
      fee_type = FeeType.new(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )

      expect(fee_type.display_name).to eq('00 - 月度交通费（销售/SMO/CO）')
    end
  end

  describe 'ProblemType' do
    let(:fee_type) do
      FeeType.create!(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )
    end

    it 'can be created with valid attributes' do
      problem_type = ProblemType.new(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      expect(problem_type).to be_valid
      expect(problem_type.save).to be true
    end

    it 'requires a unique code within a fee_type' do
      ProblemType.create!(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      duplicate = ProblemType.new(
        code: '01',
        title: 'Another Problem Type',
        sop_description: 'Some SOP',
        standard_handling: 'Some handling',
        fee_type: fee_type,
        active: true
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to include('should be unique within a fee type')
    end

    it 'allows the same code for different fee_types' do
      another_fee_type = FeeType.create!(
        code: '01',
        title: '会议整体费用',
        meeting_type: '学术论坛',
        active: true
      )

      ProblemType.create!(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      problem_type2 = ProblemType.new(
        code: '01',
        title: '会议议程不完整',
        sop_description: '检查会议议程是否完整',
        standard_handling: '要求提供完整议程',
        fee_type: another_fee_type,
        active: true
      )

      expect(problem_type2).to be_valid
      expect(problem_type2.save).to be true
    end

    it 'requires a title' do
      problem_type = ProblemType.new(
        code: '01',
        sop_description: 'Some SOP',
        standard_handling: 'Some handling',
        fee_type: fee_type,
        active: true
      )

      expect(problem_type).not_to be_valid
      expect(problem_type.errors[:title]).to include('不能为空')
    end

    it 'requires a sop_description' do
      problem_type = ProblemType.new(
        code: '01',
        title: 'Some Problem Type',
        standard_handling: 'Some handling',
        fee_type: fee_type,
        active: true
      )

      expect(problem_type).not_to be_valid
      expect(problem_type.errors[:sop_description]).to include('不能为空')
    end

    it 'requires a standard_handling' do
      problem_type = ProblemType.new(
        code: '01',
        title: 'Some Problem Type',
        sop_description: 'Some SOP',
        fee_type: fee_type,
        active: true
      )

      expect(problem_type).not_to be_valid
      expect(problem_type.errors[:standard_handling]).to include('不能为空')
    end

    it 'has a display_name that combines code and title' do
      problem_type = ProblemType.new(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      expect(problem_type.display_name).to eq('01 - 燃油费行程问题')
    end

    it 'has a full_description that includes sop_description and standard_handling' do
      problem_type = ProblemType.new(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      expected = "01 - 燃油费行程问题\n    检查燃油费是否与行程匹配\n    要求提供详细行程单"
      expect(problem_type.full_description).to eq(expected)
    end
  end

  describe 'Associations' do
    it 'allows a fee_type to have many problem_types' do
      fee_type = FeeType.create!(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )

      problem_type1 = ProblemType.create!(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type,
        active: true
      )

      problem_type2 = ProblemType.create!(
        code: '02',
        title: '交通费超标',
        sop_description: '检查交通费是否超过标准',
        standard_handling: '要求提供说明',
        fee_type: fee_type,
        active: true
      )

      expect(fee_type.problem_types).to include(problem_type1, problem_type2)
      expect(fee_type.problem_types.count).to eq(2)
    end

    it 'allows finding problem_types by fee_type' do
      fee_type1 = FeeType.create!(
        code: '00',
        title: '月度交通费（销售/SMO/CO）',
        meeting_type: '个人',
        active: true
      )

      fee_type2 = FeeType.create!(
        code: '01',
        title: '会议整体费用',
        meeting_type: '学术论坛',
        active: true
      )

      problem_type1 = ProblemType.create!(
        code: '01',
        title: '燃油费行程问题',
        sop_description: '检查燃油费是否与行程匹配',
        standard_handling: '要求提供详细行程单',
        fee_type: fee_type1,
        active: true
      )

      problem_type2 = ProblemType.create!(
        code: '01',
        title: '会议议程不完整',
        sop_description: '检查会议议程是否完整',
        standard_handling: '要求提供完整议程',
        fee_type: fee_type2,
        active: true
      )

      expect(ProblemType.by_fee_type(fee_type1.id)).to include(problem_type1)
      expect(ProblemType.by_fee_type(fee_type1.id)).not_to include(problem_type2)

      expect(ProblemType.by_fee_type(fee_type2.id)).to include(problem_type2)
      expect(ProblemType.by_fee_type(fee_type2.id)).not_to include(problem_type1)
    end
  end
end
