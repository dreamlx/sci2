# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shared::CommandResult, type: :service do
  describe 'initialization' do
    it 'creates a successful result with data' do
      result = described_class.new(success: true, data: { id: 1 }, message: 'Success')

      expect(result.success).to be true
      expect(result.data).to eq({ id: 1 })
      expect(result.message).to eq('Success')
      expect(result.errors).to be_empty
    end

    it 'creates a failure result with errors' do
      errors = ['Error 1', 'Error 2']
      result = described_class.new(success: false, errors: errors, message: 'Failed')

      expect(result.success).to be false
      expect(result.errors).to eq(errors)
      expect(result.message).to eq('Failed')
      expect(result.data).to be_nil
    end

    it 'converts single error to array' do
      result = described_class.new(success: false, errors: 'Single error')

      expect(result.errors).to eq(['Single error'])
    end

    it 'handles nil errors' do
      result = described_class.new(success: false, errors: nil)

      expect(result.errors).to eq([])
    end
  end

  describe '#success?' do
    it 'returns true for successful result' do
      result = described_class.new(success: true)

      expect(result.success?).to be true
    end

    it 'returns false for failed result' do
      result = described_class.new(success: false)

      expect(result.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns false for successful result' do
      result = described_class.new(success: true)

      expect(result.failure?).to be false
    end

    it 'returns true for failed result' do
      result = described_class.new(success: false)

      expect(result.failure?).to be true
    end
  end

  describe '.success' do
    it 'creates a successful result' do
      result = described_class.success(data: { id: 1 }, message: 'Done')

      expect(result).to be_success
      expect(result.data).to eq({ id: 1 })
      expect(result.message).to eq('Done')
      expect(result.errors).to be_empty
    end

    it 'creates successful result without data or message' do
      result = described_class.success

      expect(result).to be_success
      expect(result.data).to be_nil
      expect(result.message).to be_nil
    end
  end

  describe '.failure' do
    it 'creates a failure result' do
      errors = ['Error 1']
      result = described_class.failure(errors: errors, message: 'Failed')

      expect(result).to be_failure
      expect(result.errors).to eq(errors)
      expect(result.message).to eq('Failed')
      expect(result.data).to be_nil
    end

    it 'creates failure result without errors or message' do
      result = described_class.failure

      expect(result).to be_failure
      expect(result.errors).to be_empty
      expect(result.message).to be_nil
    end
  end

  describe 'attr_readers' do
    let(:result) do
      described_class.new(
        success: true,
        data: { test: 'data' },
        errors: ['error'],
        message: 'message'
      )
    end

    it 'provides read access to success' do
      expect(result.success).to be true
    end

    it 'provides read access to data' do
      expect(result.data).to eq({ test: 'data' })
    end

    it 'provides read access to errors' do
      expect(result.errors).to eq(['error'])
    end

    it 'provides read access to message' do
      expect(result.message).to eq('message')
    end
  end
end
