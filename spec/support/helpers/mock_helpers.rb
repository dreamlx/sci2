# frozen_string_literal: true

# MockHelpers - 统一的Mock/Stub模式
# 提供标准化的Mock和Stub设置方法，确保测试的一致性和可维护性
module MockHelpers
  extend ActiveSupport::Concern

  # 服务Mock设置
  def mock_service_success(service_class, method, return_value = nil)
    if return_value.nil?
      # 如果没有指定返回值，创建一个默认的成功结果
      return_value = double('success_result', success?: true, failure?: false, data: nil, message: 'Success')
    end

    allow_any_instance_of(service_class).to receive(method).and_return(return_value)
  end

  def mock_service_failure(service_class, method, error_message = 'Service failed')
    allow_any_instance_of(service_class).to receive(method).and_raise(StandardError.new(error_message))
  end

  def mock_service_return_nil(service_class, method)
    allow_any_instance_of(service_class).to receive(method).and_return(nil)
  end

  # Repository Mock设置
  def mock_repository_find(repository_class, id, return_value)
    allow(repository_class).to receive(:find).with(id).and_return(return_value)
  end

  def mock_repository_find_by(repository_class, attributes, return_value)
    allow(repository_class).to receive(:find_by).with(attributes).and_return(return_value)
  end

  def mock_repository_where(repository_class, conditions, return_value)
    allow(repository_class).to receive(:where).with(conditions).and_return(return_value)
  end

  # Model Mock设置
  def mock_model_save(model_instance, success: true)
    if success
      allow(model_instance).to receive(:save).and_return(true)
      allow(model_instance).to receive(:persisted?).and_return(true)
      allow(model_instance).to receive(:valid?).and_return(true)
    else
      allow(model_instance).to receive(:save).and_return(false)
      allow(model_instance).to receive(:persisted?).and_return(false)
      allow(model_instance).to receive(:valid?).and_return(false)
    end
  end

  def mock_model_errors(model_instance, error_messages)
    error_list = Array(error_messages)
    errors_double = double('errors', full_messages: error_list, any?: error_list.any?)
    allow(model_instance).to receive(:errors).and_return(errors_double)
  end

  def mock_model_validation(model_instance, field, error_message)
    allow(model_instance).to receive(:valid?).and_return(false)
    mock_model_errors(model_instance, { field => [error_message] })
  end

  # Policy Mock设置
  def mock_policy_permission(policy_class, user, record, permissions)
    policy_double = double('policy')
    permissions.each do |action, allowed|
      allow(policy_double).to receive("can_#{action}?").and_return(allowed)
    end
    allow(policy_class).to receive(:new).with(user, record).and_return(policy_double)
  end

  # 文件上传Mock
  def mock_file_attachment(attachable, attachment_name = :attachments, attached: true)
    attachment_double = double('attachment')
    allow(attachment_double).to receive(:attached?).and_return(attached)

    attachments_double = double('attachments')
    allow(attachments_double).to receive(:attached?).and_return(attached)
    allow(attachments_double).to receive(:count).and_return(attached ? 1 : 0)
    allow(attachments_double).to receive(:first).and_return(attachment_double) if attached

    allow(attachable).to receive(attachment_name).and_return(attachments_double)
  end

  def mock_file_upload(file_path: 'test.pdf', content_type: 'application/pdf')
    double('uploaded_file',
      path: file_path,
      original_filename: File.basename(file_path),
      content_type: content_type,
      size: 1024,
      read: 'file content'
    )
  end

  # 外部API Mock
  def mock_http_request(method, url, response_body = nil, status: 200)
    response_double = double('http_response', body: response_body, status: status, success?: status < 400)
    case method.to_sym
    when :get
      allow(HTTParty).to receive(:get).with(url, anything).and_return(response_double)
    when :post
      allow(HTTParty).to receive(:post).with(url, anything).and_return(response_double)
    when :put
      allow(HTTParty).to receive(:put).with(url, anything).and_return(response_double)
    when :delete
      allow(HTTParty).to receive(:delete).with(url, anything).and_return(response_double)
    end
  end

  # 时间Mock
  def mock_current_time(time)
    allow(Time).to receive(:current).and_return(time)
    allow(Time).to receive(:now).and_return(time)
  end

  def mock_time_travel(duration)
    current_time = Time.current
    mock_current_time(current_time + duration)
  end

  # 随机数Mock
  def mock_random_number(number)
    allow(Kernel).to receive(:rand).and_return(number)
  end

  def mock_secure_random_token(token)
    allow(SecureRandom).to receive(:uuid).and_return(token)
    allow(SecureRandom).to receive(:hex).and_return(token)
  end

  # 日志Mock
  def mock_logger(level = :info)
    logger_double = double('logger')
    %i[debug info warn error fatal].each do |log_level|
      allow(logger_double).to receive(log_level)
    end

    allow(Rails).to receive(:logger).and_return(logger_double)
    logger_double
  end

  def expect_log_message(level, message)
    expect(Rails.logger).to receive(level).with(message)
  end

  # 缓存Mock
  def mock_cache_read(key, value)
    allow(Rails.cache).to receive(:read).with(key).and_return(value)
  end

  def mock_cache_write(key, value, expires_in: nil)
    if expires_in
      allow(Rails.cache).to receive(:write).with(key, value, expires_in: expires_in)
    else
      allow(Rails.cache).to receive(:write).with(key, value)
    end
  end

  # 邮件Mock
  def mock_mailer_delivery(mailer_class, method, *args)
    mail_double = double('mail', deliver_now: true, deliver_later: true)
    allow(mailer_class).to receive(message_method: method).and_return(mail_double)
    mail_double
  end

  # 队列Job Mock
  def mock_job_perform(job_class, *args)
    job_double = double('job', perform_later: true)
    allow(job_class).to receive(:perform_later).with(*args).and_return(job_double)
    job_double
  end

  # 数据库事务Mock
  def mock_transaction(success: true)
    if success
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
    else
      allow(ActiveRecord::Base).to receive(:transaction).and_raise(ActiveRecord::Rollback)
    end
  end

  # 验证Mock调用
  def verify_service_called(service_class, method, times: 1)
    expect_any_instance_of(service_class).to have_received(method).exactly(times).times
  end

  def verify_repository_called(repository_class, method, with_args = nil, times: 1)
    if with_args
      expect(repository_class).to have_received(method).with(*with_args).exactly(times).times
    else
      expect(repository_class).to have_received(method).exactly(times).times
    end
  end

  def verify_model_saved(model_instance, times: 1)
    expect(model_instance).to have_received(:save).exactly(times).times
  end

  def verify_policy_called(policy_class, user, record, times: 1)
    expect(policy_class).to have_received(:new).with(user, record).exactly(times).times
  end

  # 复合Mock设置
  def setup_service_layer_mocks(service_class, primary_method, success: true, return_value: nil)
    if success
      mock_service_success(service_class, primary_method, return_value)
    else
      mock_service_failure(service_class, primary_method)
    end
  end

  def setup_repository_layer_mocks(repository_class, find_method, find_result, additional_mocks = {})
    mock_repository_find(repository_class, find_result.id, find_result)

    additional_mocks.each do |method, result|
      allow(repository_class).to receive(method).and_return(result)
    end
  end

  def setup_model_layer_mocks(model_instance, save_success: true, errors: nil)
    mock_model_save(model_instance, success: save_success)
    mock_model_errors(model_instance, errors) if errors
  end

  # 条件Mock设置
  def mock_conditionally(condition, &block)
    if condition
      block.call
    end
  end

  def mock_based_on_environment(environment, &block)
    block.call if Rails.env == environment.to_s
  end

  # Mock重置
  def reset_all_mocks
    RSpec::Mocks.space.reset_all
  end

  # Mock验证助手
  def verify_mock_expectations
    # 这个方法会在每个测试结束时被RSpec自动调用
    # 这里主要是为了明确表达验证的意图
  end

  # Mock链式调用
  def mock_chain(object, method_chain, return_value)
    chain_parts = method_chain.split('.')
    current_mock = object

    chain_parts[0..-2].each do |method|
      intermediate_double = double(method.to_s)
      allow(current_mock).to receive(method).and_return(intermediate_double)
      current_mock = intermediate_double
    end

    allow(current_mock).to receive(chain_parts.last).and_return(return_value)
  end

  # Mock异常场景
  def setup_exception_scenario(service_class, method, exception_class = StandardError, message = 'Test error')
    allow_any_instance_of(service_class).to receive(method).and_raise(exception_class.new(message))
  end

  # Mock超时场景
  def setup_timeout_scenario(service_class, method)
    timeout_error = Net::TimeoutError.new('Operation timed out')
    setup_exception_scenario(service_class, method, Net::TimeoutError, 'Operation timed out')
  end

  # Mock网络错误场景
  def setup_network_error_scenario(service_class, method)
    network_error = Net::NetworkError.new('Network unreachable')
    setup_exception_scenario(service_class, method, Net::NetworkError, 'Network unreachable')
  end
end