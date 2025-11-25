#!/usr/bin/env ruby

puts '=== 数据库连接调试脚本 ==='
puts "时间: #{Time.now}"
puts

# 检查环境变量
puts '1. 检查数据库环境变量:'
puts "   DATABASE_USERNAME: #{ENV.fetch('DATABASE_USERNAME') { 'sci2_test (默认)' }}"
puts "   DATABASE_PASSWORD: #{ENV.fetch('DATABASE_PASSWORD') { 'test_password_123 (默认)' }}"
puts "   DATABASE_HOST: #{ENV.fetch('DATABASE_HOST') { 'localhost (默认)' }}"
puts "   DATABASE_PORT: #{ENV.fetch('DATABASE_PORT') { 5432 }}"
puts "   RAILS_ENV: #{ENV.fetch('RAILS_ENV') { 'development (默认)' }}"
puts

# 检查端口连接
puts '2. 检查端口连接状态:'
require 'socket'

def check_port(host, port)
  Socket.tcp(host, port, connect_timeout: 2) do |socket|
    puts "   ✓ #{host}:#{port} - 连接成功"
    return true
  end
rescue Errno::ECONNREFUSED
  puts "   ✗ #{host}:#{port} - 连接被拒绝"
  false
rescue SocketError => e
  puts "   ✗ #{host}:#{port} - 主机名解析失败: #{e.message}"
  false
rescue StandardError => e
  puts "   ✗ #{host}:#{port} - 其他错误: #{e.message}"
  false
end

check_port('localhost', 5432)
check_port('127.0.0.1', 5432)
check_port('::1', 5432)
check_port('localhost', 55_000) # Docker映射的端口
puts

# 检查Docker容器
puts '3. 检查Docker容器状态:'
begin
  docker_output = `docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep postgres`
  if docker_output.empty?
    puts '   没有找到PostgreSQL相关的Docker容器'
  else
    puts docker_output
  end
rescue StandardError => e
  puts "   检查Docker容器时出错: #{e.message}"
end
puts

# 尝试直接连接PostgreSQL
puts '4. 尝试直接PostgreSQL连接:'
begin
  require 'pg'

  # 尝试默认配置
  connection_params = {
    host: ENV.fetch('DATABASE_HOST') { 'localhost' },
    port: ENV.fetch('DATABASE_PORT') { 5432 },
    user: ENV.fetch('DATABASE_USERNAME') { 'sci2_test' },
    password: ENV.fetch('DATABASE_PASSWORD') { 'test_password_123' },
    dbname: 'sci2_development',
    connect_timeout: 5
  }

  puts "   尝试连接参数: #{connection_params.except(:password)}"

  conn = PG.connect(connection_params)
  puts '   ✓ PostgreSQL连接成功!'
  puts "   数据库版本: #{conn.server_version}"
  puts "   当前数据库: #{conn.current_database}"
  conn.close
rescue LoadError
  puts '   ✗ PG gem未安装'
rescue PG::ConnectionBad => e
  puts "   ✗ PostgreSQL连接失败: #{e.message}"
rescue StandardError => e
  puts "   ✗ 其他错误: #{e.message}"
end
puts

# 检查Rails数据库配置
puts '5. 检查Rails数据库配置:'
begin
  require_relative 'config/environment'

  puts "   Rails环境: #{Rails.env}"
  puts '   数据库配置:'
  db_config = ActiveRecord::Base.connection_config
  puts "     适配器: #{db_config[:adapter]}"
  puts "     主机: #{db_config[:host]}"
  puts "     端口: #{db_config[:port]}"
  puts "     数据库: #{db_config[:database]}"
  puts "     用户名: #{db_config[:username]}"

  # 尝试连接
  ActiveRecord::Base.connection
  puts '   ✓ ActiveRecord连接成功!'
rescue StandardError => e
  puts "   ✗ ActiveRecord连接失败: #{e.message}"
  puts "   错误类型: #{e.class.name}"
end

puts
puts '=== 调试完成 ==='
