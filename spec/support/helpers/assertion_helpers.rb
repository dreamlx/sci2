# frozen_string_literal: true

# AssertionHelpers - 标准化断言方法
# 提供可复用的断言模式，提高测试代码的一致性和可读性
module AssertionHelpers
  extend ActiveSupport::Concern

  # 通用结果断言
  def expect_success(result, expected_data_type: nil, expected_message: nil)
    aggregate_failures do
      expect(result).to respond_to(:success?)
      expect(result.success?).to be true
      expect(result.failure?).to be false

      expect(result.data).to be_a(expected_data_type) if expected_data_type && result.respond_to?(:data)

      expect(result.message).to eq(expected_message) if expected_message && result.respond_to?(:message)

      expect(result.errors).to be_empty if result.respond_to?(:errors)
    end
  end

  def expect_failure(result, expected_errors: nil, expected_message: nil)
    aggregate_failures do
      expect(result).to respond_to(:success?)
      expect(result.success?).to be false
      expect(result.failure?).to be true

      if expected_errors
        errors = result.respond_to?(:errors) ? result.errors : [result.message].compact
        expected_errors.each do |error|
          expect(errors).to include(error), "Expected errors #{errors} to include #{error}"
        end
      end

      expect(result.message).to include(expected_message) if expected_message && result.respond_to?(:message)
    end
  end

  # 数据库变化断言
  def expect_no_change(model_class = nil, &block)
    target_class = model_class || infer_model_class
    expect { block.call }.not_to(change { target_class.count })
  end

  def expect_change_by(count, model_class = nil, &block)
    target_class = model_class || infer_model_class
    expect { block.call }.to change { target_class.count }.by(count)
  end

  def expect_change_from_to(from_val, to_val, &block)
    expect { block.call }.to change(&block).from(from_val).to(to_val)
  end

  # 属性断言
  def expect_attributes(object, expected_attributes)
    aggregate_failures do
      expected_attributes.each do |attr, value|
        expect(object.send(attr)).to eq(value), "Expected #{attr} to be #{value}, but got #{object.send(attr)}"
      end
    end
  end

  def expect_attributes_present(object, *attributes)
    aggregate_failures do
      attributes.each do |attr|
        expect(object.send(attr)).to be_present, "Expected #{attr} to be present"
      end
    end
  end

  def expect_attributes_nil(object, *attributes)
    aggregate_failures do
      attributes.each do |attr|
        expect(object.send(attr)).to be_nil, "Expected #{attr} to be nil"
      end
    end
  end

  # 状态断言
  def expect_status(object, expected_status)
    status_field = object.respond_to?(:status) ? :status : :state
    expect(object.send(status_field)).to eq(expected_status)
  end

  def expect_transition(from_status, to_status, &block)
    object = yield
    expect_status(object, from_status)
    block.call if block_given?
    expect_status(object, to_status)
  end

  # 权限断言
  def expect_permission(policy, action, expected_result = true)
    method_name = "can_#{action}?"
    expect(policy).to respond_to(method_name), "Policy does not respond to #{method_name}"
    expect(policy.send(method_name)).to be expected_result
  end

  def expect_permissions(policy, actions, expected_result = true)
    aggregate_failures do
      actions.each do |action|
        expect_permission(policy, action, expected_result)
      end
    end
  end

  def expect_all_permissions(policy, expected_result = true)
    permission_methods = policy.public_methods.select { |m| m.to_s.start_with?('can_') }
    aggregate_failures do
      permission_methods.each do |method|
        expect(policy.send(method)).to be expected_result, "Expected #{method} to be #{expected_result}"
      end
    end
  end

  # 验证断言
  def expect_valid(object)
    expect(object).to be_valid,
                      "Expected #{object.class.name} to be valid, but errors: #{object.errors.full_messages.join(', ')}"
  end

  def expect_invalid(object, expected_errors = {})
    expect(object).not_to be_valid

    return unless expected_errors.any?

    aggregate_failures do
      expected_errors.each do |field, messages|
        messages = Array(messages)
        messages.each do |message|
          expect(object.errors[field]).to include(message), "Expected #{field} errors to include '#{message}'"
        end
      end
    end
  end

  # 关联断言
  def expect_association(object, association_name, expected_type = nil, expected_count: nil)
    association = object.send(association_name)

    if expected_type
      if association.respond_to?(:first)
        expect(association.first).to be_a(expected_type) if association.any?
      elsif association
        expect(association).to be_a(expected_type)
      end
    end

    return unless expected_count

    expect(association.count).to eq(expected_count)
  end

  def expect_belongs_to(object, association_name, expected_object = nil)
    expect(object).to respond_to(association_name)
    associated = object.send(association_name)
    expect(associated).to be_present
    expect(associated).to eq(expected_object) if expected_object
  end

  def expect_has_many(object, association_name, expected_count: nil)
    expect(object).to respond_to(association_name)
    collection = object.send(association_name)
    expect(collection).to respond_to(:count)
    expect(collection.count).to eq(expected_count) if expected_count
  end

  # 文件附件断言
  def expect_attachment(object, attachment_name = :attachments)
    expect(object).to respond_to(attachment_name)
    attachments = object.send(attachment_name)
    expect(attachments).to be_attached
  end

  def expect_no_attachment(object, attachment_name = :attachments)
    expect(object).to respond_to(attachment_name)
    attachments = object.send(attachment_name)
    expect(attachments).not_to be_attached
  end

  def expect_attachment_count(object, expected_count, attachment_name = :attachments)
    attachments = object.send(attachment_name)
    expect(attachments.count).to eq(expected_count)
  end

  # 查询断言
  def expect_query_returns(model_class, method_name, expected_result)
    result = model_class.send(method_name)
    if expected_result.is_a?(Array)
      expect(result).to match_array(expected_result)
    else
      expect(result).to eq(expected_result)
    end
  end

  def expect_query_count(model_class, method_name, expected_count)
    result = model_class.send(method_name)
    expect(result.count).to eq(expected_count)
  end

  # 服务特定断言
  def expect_service_call_success(service, method_name, *args, expected_data_type: nil)
    result = service.send(method_name, *args)
    expect_success(result, expected_data_type: expected_data_type)
  end

  def expect_service_call_failure(service, method_name, *args, expected_errors: nil)
    result = service.send(method_name, *args)
    expect_failure(result, expected_errors: expected_errors)
  end

  # Command特定断言
  def expect_command_success(command, expected_data_type: nil)
    result = command.call
    expect_success(result, expected_data_type: expected_data_type)
  end

  def expect_command_failure(command, expected_errors: nil)
    result = command.call
    expect_failure(result, expected_errors: expected_errors)
  end

  # Repository特定断言
  def expect_repository_find(repository_class, id, expected_object)
    result = repository_class.find(id)
    expect(result).to eq(expected_object)
  end

  def expect_repository_not_found(repository_class, id)
    result = repository_class.find(id)
    expect(result).to be_nil
  end

  # 时间断言
  def expect_recent(object, time_field: :created_at, within: 5.minutes)
    expect(object.send(time_field)).to be_within(within).of(Time.current)
  end

  def expect_time_range(object, start_time, end_time, time_field: :created_at)
    time = object.send(time_field)
    expect(time).to be_between(start_time, end_time)
  end

  # 错误处理断言
  def expect_error_raised(error_class = StandardError, expected_message = nil, &block)
    expect { block.call }.to raise_error(error_class) do |error|
      expect(error.message).to include(expected_message) if expected_message
    end
  end

  # Mock验证断言
  def expect_mock_received(mock_object, method_name, expected_times = 1)
    expect(mock_object).to have_received(method_name).exactly(expected_times).times
  end

  def expect_mock_not_received(mock_object, method_name)
    expect(mock_object).not_to have_received(method_name)
  end

  private

  def infer_model_class
    # 根据测试类推断对应的模型类
    described_class.name.gsub(/Service|Command|Policy|Repository/, '').constantize
  rescue NameError
    described_class
  end
end
