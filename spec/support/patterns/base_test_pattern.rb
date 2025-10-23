# frozen_string_literal: true

# BaseTestPattern - 所有测试模式的基础模板
# 提供通用的测试结构、工具方法和最佳实践
module TestPatterns
  module BaseTestPattern
    extend ActiveSupport::Concern

    included do
      # 标准化文件头部
      # frozen_string_literal: true
      # require 'rails_helper'

      # 通用metadata
      metadata[:type] ||= :service
      metadata[:test_pattern] = :base
    end

    class_methods do
      # 定义标准的测试结构模板
      def standard_describe(class_name, type: nil, &block)
        type ||= infer_type_from_class_name(class_name)
        RSpec.describe class_name, type: type, &block
      end

      # 推断测试类型
      def infer_type_from_class_name(class_name)
        case class_name.to_s
        when /Command$/ then :command
        when /Service$/ then :service
        when /Policy$/ then :policy
        when /Repository$/ then :repository
        else :service
        end
      end

      # 标准的let定义模式
      def define_base_lets(class_name)
        let(:instance) { described_class.new }
        let(:class_symbol) { class_name.to_s.underscore.to_sym }
      end

      # 标准的测试上下文结构
      def define_standard_contexts(&block)
        describe '#initialize' do
          it 'initializes with default values' do
            expect(instance).to be_a(described_class)
          end
        end

        instance_eval(&block) if block_given?
      end
    end

    # 实例方法 - 通用的测试辅助方法
    def expect_successful_result(result, expected_data_type = nil)
      aggregate_failures do
        expect(result).to respond_to(:success?)
        expect(result.success?).to be true
        expect(result.failure?).to be false

        if expected_data_type
          expect(result.data).to be_a(expected_data_type) if result.respond_to?(:data)
        end

        if result.respond_to?(:message) && result.message
          expect(result.message).to be_a(String)
        end
      end
    end

    def expect_failure_result(result, expected_errors = nil)
      aggregate_failures do
        expect(result).to respond_to(:success?)
        expect(result.success?).to be false
        expect(result.failure?).to be true

        if expected_errors
          errors = result.respond_to?(:errors) ? result.errors : [result.message]
          expected_errors.each do |error|
            expect(errors).to include(error)
          end
        end
      end
    end

    def expect_no_database_change(&block)
      expect { block.call }.not_to change { described_class.count if described_class.respond_to?(:count) }
    end

    def expect_database_change_by(count = 1, model_class = nil, &block)
      target_model = model_class || infer_model_class
      expect { block.call }.to change { target_model.count }.by(count)
    end

    private

    def infer_model_class
      # 从类名推断对应的模型类
      class_name = described_class.name
      case class_name
      when /Reimbursement.*Service/
        Reimbursement
      when /FeeDetail.*Service/
        FeeDetail
      when /AdminUser.*Service/
        AdminUser
      else
        begin
          class_name.gsub(/Service|Command|Policy|Repository/, '').constantize
        rescue NameError
          described_class
        end
      end
    end

    # 标准的Mock设置方法
    def setup_service_mock(service_class, method, return_value)
      allow_any_instance_of(service_class).to receive(method).and_return(return_value)
    end

    def setup_service_failure(service_class, method, error_message = 'Service failed')
      allow_any_instance_of(service_class).to receive(method).and_raise(StandardError.new(error_message))
    end

    # 标准的错误测试模式
    def test_validation_errors(field, value, expected_error)
      instance.send("#{field}=", value)
      expect(instance.valid?).to be false
      expect(instance.errors[field]).to include(expected_error)
    end

    # 标准的权限测试模式
    def test_permission(user, action, expected_result)
      policy = described_class.new(user, subject_record)
      expect(policy.send("can_#{action}?")).to be expected_result
    end

    # 标准的Factory创建模式
    def create_instance(traits = {})
      create(described_class.name.demodulize.underscore.to_sym, traits)
    end

    def build_instance(traits = {})
      build(described_class.name.demodulize.underscore.to_sym, traits)
    end
  end
end