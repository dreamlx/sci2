namespace :assets do
  desc 'Verify assets precompilation and critical files'
  task :verify do
    on roles(:app) do
      within release_path do
        info '验证资源预编译...'

        # 检查关键的 Active Admin 资源文件是否存在
        critical_assets = [
          'active_admin.css',
          'active_admin.js',
          'application.css',
          'application.js'
        ]

        # 检查 manifest.json 文件
        manifest_path = "#{shared_path}/public/assets/.sprockets-manifest-*.json"
        manifest_files = capture(:ls, manifest_path, raise_on_non_zero_exit: false).strip

        if manifest_files.empty?
          error '❌ 未找到资源清单文件！'
          invoke 'assets:fix_precompilation'
        else
          info "✅ 找到资源清单文件: #{manifest_files.split.first}"

          # 读取 manifest 内容并检查关键资源
          manifest_file = manifest_files.split.first
          manifest_content = capture(:cat, manifest_file)

          missing_assets = []
          critical_assets.each do |asset|
            missing_assets << asset unless manifest_content.include?(asset)
          end

          if missing_assets.any?
            error "❌ 缺失关键资源文件: #{missing_assets.join(', ')}"
            invoke 'assets:fix_precompilation'
          else
            info '✅ 所有关键资源文件都已正确预编译'

            # 验证实际文件是否存在
            verify_physical_files(critical_assets, manifest_content)
          end
        end
      end
    end
  end

  desc 'Fix assets precompilation issues'
  task :fix_precompilation do
    on roles(:app) do
      within release_path do
        info '🔧 修复资源预编译问题...'

        # 1. 确保 npm 依赖项已安装
        info '检查并安装 npm 依赖项...'
        execute :npm, :install

        # 2. 检查关键的 npm 包
        required_packages = ['@hotwired/stimulus', '@hotwired/turbo-rails', 'esbuild']
        required_packages.each do |package|
          package_exists = test("npm list #{package} > /dev/null 2>&1")
          unless package_exists
            warn "⚠️  缺失 npm 包: #{package}，正在安装..."
            execute :npm, :install, package
          end
        end

        # 3. 清理旧的资源文件
        info '清理旧的资源文件...'
        execute :rm, '-rf', "#{shared_path}/public/assets/*"

        # 4. 重新预编译资源
        info '重新预编译资源...'
        with rails_env: fetch(:rails_env) do
          execute :rvm, fetch(:rvm_ruby_version), :do, :bundle, :exec, :rake, 'assets:precompile'
        end

        # 5. 验证预编译结果
        info '验证预编译结果...'
        invoke 'assets:verify_after_fix'
      end
    end
  end

  desc 'Verify assets after fix attempt'
  task :verify_after_fix do
    on roles(:app) do
      within release_path do
        # 检查是否有资源文件生成
        assets_count = capture(:ls, "#{shared_path}/public/assets/", '|', :wc, '-l').to_i

        if assets_count > 5 # 应该有多个资源文件
          info "✅ 资源预编译修复成功！生成了 #{assets_count} 个资源文件"

          # 列出生成的 Active Admin 相关文件
          aa_files = capture(:ls, "#{shared_path}/public/assets/", '|', :grep, 'active_admin',
                             raise_on_non_zero_exit: false)
          if aa_files.strip.empty?
            error '❌ 仍然缺失 Active Admin 资源文件'
            raise '资源预编译修复失败：Active Admin 文件未生成'
          else
            info '✅ Active Admin 资源文件已生成:'
            aa_files.strip.split("\n").each { |file| info "  - #{file}" }
          end
        else
          error "❌ 资源预编译修复失败！只生成了 #{assets_count} 个文件"
          raise '资源预编译修复失败'
        end
      end
    end
  end

  private

  def verify_physical_files(critical_assets, manifest_content)
    info '验证物理文件是否存在...'

    # 从 manifest 中提取实际的文件名（带哈希）
    require 'json'
    manifest_data = JSON.parse(manifest_content)

    missing_files = []
    critical_assets.each do |logical_name|
      next unless manifest_data['assets'] && manifest_data['assets'][logical_name]

      physical_name = manifest_data['assets'][logical_name]
      file_path = "#{shared_path}/public/assets/#{physical_name}"

      missing_files << physical_name unless test("[ -f #{file_path} ]")
    end

    if missing_files.any?
      error "❌ 物理文件缺失: #{missing_files.join(', ')}"
      invoke 'assets:fix_precompilation'
    else
      info '✅ 所有物理文件都存在'
    end
  rescue JSON::ParserError => e
    warn "⚠️  无法解析 manifest 文件: #{e.message}"
    info '跳过物理文件验证'
  end
end

# 在资源预编译后自动运行验证
after 'deploy:assets:precompile', 'assets:verify'

# 如果验证失败，在重启前再次尝试修复
before 'deploy:restart', 'assets:verify'
