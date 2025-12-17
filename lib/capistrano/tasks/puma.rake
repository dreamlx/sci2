# lib/capistrano/tasks/puma.rake
# Puma management via systemd

namespace :puma do
  # systemd 服务名称
  def puma_service_name
    "puma-#{fetch(:application)}"
  end

  desc 'Setup systemd service for Puma'
  task :setup_systemd do
    on roles(:app) do
      info "Setting up systemd service: #{puma_service_name}"

      # 生成服务文件内容
      template_path = File.expand_path('../../deploy/templates/puma.service.erb', __dir__)

      if File.exist?(template_path)
        template = ERB.new(File.read(template_path))
        service_content = template.result(binding)
      else
        # 内联模板作为后备
        service_content = <<~SERVICE
          [Unit]
          Description=Puma HTTP Server for #{fetch(:application)}
          After=network.target

          [Service]
          Type=simple
          User=#{fetch(:puma_user, host.user)}
          WorkingDirectory=#{current_path}
          Environment=RAILS_ENV=#{fetch(:rails_env)}
          Environment=PATH=/usr/local/rvm/gems/ruby-#{fetch(:rvm_ruby_version)}/bin:/usr/local/rvm/gems/ruby-#{fetch(:rvm_ruby_version)}@global/bin:/usr/local/rvm/rubies/ruby-#{fetch(:rvm_ruby_version)}/bin:/usr/local/rvm/bin:/usr/bin:/bin
          Environment=GEM_HOME=/usr/local/rvm/gems/ruby-#{fetch(:rvm_ruby_version)}
          Environment=GEM_PATH=/usr/local/rvm/gems/ruby-#{fetch(:rvm_ruby_version)}:/usr/local/rvm/gems/ruby-#{fetch(:rvm_ruby_version)}@global

          ExecStart=/usr/local/rvm/bin/rvm #{fetch(:rvm_ruby_version)} do bundle exec puma -C #{shared_path}/config/puma.rb
          ExecReload=/bin/kill -USR1 $MAINPID
          PIDFile=#{shared_path}/tmp/pids/puma.pid

          Restart=always
          RestartSec=5
          StandardOutput=append:#{shared_path}/log/puma.stdout.log
          StandardError=append:#{shared_path}/log/puma.stderr.log

          [Install]
          WantedBy=multi-user.target
        SERVICE
      end

      # 上传服务文件到临时位置
      upload! StringIO.new(service_content), "/tmp/#{puma_service_name}.service"

      # 移动到 systemd 目录（需要 sudo）
      execute :sudo, :mv, "/tmp/#{puma_service_name}.service", "/etc/systemd/system/#{puma_service_name}.service"
      execute :sudo, :chmod, '644', "/etc/systemd/system/#{puma_service_name}.service"

      # 重新加载 systemd 并启用服务
      execute :sudo, :systemctl, 'daemon-reload'
      execute :sudo, :systemctl, :enable, puma_service_name

      info "✓ systemd service #{puma_service_name} installed and enabled"
    end
  end

  desc 'Start Puma via systemd'
  task :start do
    on roles(:app) do
      info "Starting #{puma_service_name}..."
      execute :sudo, :systemctl, :start, puma_service_name

      sleep 3
      status = capture(:sudo, :systemctl, 'is-active', puma_service_name, raise_on_non_zero_exit: false)
      if status.strip == 'active'
        info "✓ #{puma_service_name} started successfully"
      else
        error "✗ Failed to start #{puma_service_name}"
        error capture(:sudo, :journalctl, '-u', puma_service_name, '-n', '20', '--no-pager')
      end
    end
  end

  desc 'Stop Puma via systemd'
  task :stop do
    on roles(:app) do
      info "Stopping #{puma_service_name}..."
      execute :sudo, :systemctl, :stop, puma_service_name

      sleep 2
      status = capture(:sudo, :systemctl, 'is-active', puma_service_name, raise_on_non_zero_exit: false)
      if status.strip == 'inactive' || status.strip == 'failed'
        info "✓ #{puma_service_name} stopped"
      else
        warn "⚠ #{puma_service_name} may still be running: #{status}"
      end
    end
  end

  desc 'Restart Puma via systemd'
  task :restart do
    on roles(:app) do
      info "Restarting #{puma_service_name}..."
      execute :sudo, :systemctl, :restart, puma_service_name

      sleep 3
      status = capture(:sudo, :systemctl, 'is-active', puma_service_name, raise_on_non_zero_exit: false)
      if status.strip == 'active'
        info "✓ #{puma_service_name} restarted successfully"

        # 验证端口绑定
        port_check = capture("netstat -tuln | grep ':3000 ' || echo 'PORT_NOT_BOUND'")
        if port_check.include?('PORT_NOT_BOUND')
          warn '⚠ Port 3000 is not bound yet, waiting...'
          sleep 3
          port_check = capture("netstat -tuln | grep ':3000 ' || echo 'PORT_NOT_BOUND'")
        end

        if port_check.include?('PORT_NOT_BOUND')
          error '✗ Port 3000 is still not bound!'
        else
          info '✓ Port 3000 is properly bound'
        end
      else
        error "✗ Failed to restart #{puma_service_name}"
        error capture(:sudo, :journalctl, '-u', puma_service_name, '-n', '20', '--no-pager')
      end
    end
  end

  desc 'Reload Puma (graceful restart) via systemd'
  task :reload do
    on roles(:app) do
      info "Reloading #{puma_service_name}..."
      execute :sudo, :systemctl, :reload, puma_service_name
      info "✓ Reload signal sent to #{puma_service_name}"
    end
  end

  desc 'Show Puma status via systemd'
  task :status do
    on roles(:app) do
      info "=== #{puma_service_name} Status ==="

      # systemd 状态
      status_output = capture(:sudo, :systemctl, :status, puma_service_name, '--no-pager', raise_on_non_zero_exit: false)
      info status_output

      # 端口状态
      port_check = capture("netstat -tuln | grep ':3000 ' || echo 'PORT_NOT_BOUND'")
      if port_check.include?('PORT_NOT_BOUND')
        warn '✗ Port 3000 is not bound'
      else
        info "✓ Port binding: #{port_check.strip}"
      end

      info '=== End Status ==='
    end
  end

  desc 'Show Puma logs'
  task :logs do
    on roles(:app) do
      info "=== #{puma_service_name} Recent Logs ==="
      logs = capture(:sudo, :journalctl, '-u', puma_service_name, '-n', '50', '--no-pager')
      info logs
      info '=== End Logs ==='
    end
  end

  desc 'Check if systemd service is installed'
  task :check_systemd do
    on roles(:app) do
      if test(:sudo, :systemctl, 'list-unit-files', "#{puma_service_name}.service", '|', 'grep', '-q', puma_service_name)
        info "✓ systemd service #{puma_service_name} is installed"
        true
      else
        warn "✗ systemd service #{puma_service_name} is NOT installed"
        warn 'Run: cap production puma:setup_systemd'
        false
      end
    end
  end

  # ========== 后备方案：无 systemd 的 nohup 启动 ==========

  desc 'Start Puma without systemd (fallback)'
  task :start_nohup do
    on roles(:app), pty: false do
      within current_path do
        with rails_env: fetch(:rails_env) do
          info 'Starting Puma server via nohup (fallback mode)...'

          # 先停止已有进程
          invoke 'puma:stop_nohup'
          sleep 2

          # 创建启动脚本
          start_script = "#{shared_path}/tmp/start_puma.sh"
          script_content = <<~SCRIPT
            #!/bin/bash
            cd #{current_path}
            export RAILS_ENV=#{fetch(:rails_env)}
            /usr/local/rvm/bin/rvm #{fetch(:rvm_ruby_version)} do bundle exec puma \\
              -C #{shared_path}/config/puma.rb \\
              --pidfile #{shared_path}/tmp/pids/puma.pid \\
              >> #{shared_path}/log/puma.stdout.log \\
              2>> #{shared_path}/log/puma.stderr.log &
          SCRIPT
          upload! StringIO.new(script_content), start_script
          execute "chmod +x #{start_script}"
          execute "nohup #{start_script} > /dev/null 2>&1 &"

          # 等待启动
          max_wait = 30
          waited = 0
          while waited < max_wait
            sleep 2
            waited += 2
            if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
              pid = capture("cat #{shared_path}/tmp/pids/puma.pid").strip
              if test("kill -0 #{pid} 2>/dev/null")
                info "✓ Puma started (PID: #{pid})"
                break
              end
            end
            info "Waiting for Puma to start... (#{waited}s)"
          end

          # 验证
          if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
            pid = capture("cat #{shared_path}/tmp/pids/puma.pid").strip
            if test("kill -0 #{pid} 2>/dev/null")
              info "✓ Puma is running (PID: #{pid})"
            else
              error '✗ Puma process not running'
            end
          else
            error '✗ PID file not created'
          end
        end
      end
    end
  end

  desc 'Stop Puma without systemd (fallback)'
  task :stop_nohup do
    on roles(:app) do
      info 'Stopping Puma (fallback mode)...'

      if test("[ -f #{shared_path}/tmp/pids/puma.pid ]")
        pid = capture("cat #{shared_path}/tmp/pids/puma.pid").strip
        if test("kill -0 #{pid} 2>/dev/null")
          execute "kill -TERM #{pid} 2>/dev/null || true"
          sleep 3
          if test("kill -0 #{pid} 2>/dev/null")
            execute "kill -KILL #{pid} 2>/dev/null || true"
          end
        end
        execute "rm -f #{shared_path}/tmp/pids/puma.pid"
      end

      # 清理所有 puma 进程
      execute "pkill -f 'puma.*#{fetch(:application)}' 2>/dev/null || true"

      info '✓ Puma stopped'
    end
  end

  desc 'Restart Puma without systemd (fallback)'
  task :restart_nohup do
    invoke 'puma:stop_nohup'
    sleep 2
    invoke 'puma:start_nohup'
  end
end
