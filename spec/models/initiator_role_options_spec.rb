# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InitiatorRoleOptions, type: :model do
  describe '.all' do
    it 'returns all initiator role options' do
      options = described_class.all

      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes expected role options' do
      options = described_class.all

      expect(options).to include('审核人员')
      expect(options).to include('财务人员')
      expect(options).to include('部门主管')
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
