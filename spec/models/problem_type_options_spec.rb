# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProblemTypeOptions, type: :model do
  describe '.all' do
    it 'returns all problem type options' do
      options = described_class.all

      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes expected problem type options' do
      options = described_class.all

      expect(options).to include('发票问题')
      expect(options).to include('金额错误')
      expect(options).to include('费用类型错误')
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
