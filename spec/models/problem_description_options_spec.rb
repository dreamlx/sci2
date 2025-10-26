# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProblemDescriptionOptions, type: :model do
  describe '.all' do
    it 'returns all problem description options' do
      options = described_class.all

      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes expected description options' do
      options = described_class.all

      expect(options).to include('发票信息不完整')
      expect(options).to include('费用类型选择错误')
      expect(options).to include('缺少必要证明材料')
    end

    it 'returns frozen strings' do
      options = described_class.all

      options.each do |option|
        expect(option).to be_a(String)
      end
    end

    it 'returns consistent results on multiple calls' do
      first_call = described_class.all
      second_call = described_class.all

      expect(first_call).to eq(second_call)
    end
  end
end
