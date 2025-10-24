# db/scripts/match_approvers_to_admin_users.rb
# Purpose: 将报销单approver_name值与管理员用户匹配并更新分配

class ApproverMatchingService
  def initialize(system_admin_user)
    @system_admin_user = system_admin_user
    @assignment_service = ReimbursementAssignmentService.new(system_admin_user)
    @matched_count = 0
    @unmatched_count = 0
    @error_count = 0
    @log = []
  end

  def run
    admin_users = AdminUser.all.to_a
    puts "加载了 #{admin_users.count} 个管理员用户"

    @admin_user_lookup = {}
    admin_users.each do |admin|
      normalized_name = normalize_name(admin.name)
      @admin_user_lookup[normalized_name] = admin
    end

    reimbursements = Reimbursement.where.not(approver_name: [nil, '']).to_a
    puts "找到 #{reimbursements.count} 个带有审核通过人姓名的报销单"

    reimbursements.each do |reimbursement|
      process_reimbursement(reimbursement)
    end

    print_summary
  end

  private

  def process_reimbursement(reimbursement)
    approver_name = reimbursement.approver_name.to_s.strip
    puts "处理报销单 #{reimbursement.invoice_number}，审核通过人: #{approver_name}"

    if reimbursement.current_assignee.present?
      log_message = "报销单 #{reimbursement.invoice_number} 已分配给 #{reimbursement.current_assignee.name}"
      puts log_message
      @log << log_message
      return
    end

    admin_user = find_matching_admin_user(approver_name)

    if admin_user
      @assignment_service.assign(reimbursement.id, admin_user.id, "根据审核通过人姓名自动分配: #{approver_name}")
      log_message = "匹配并分配: #{reimbursement.invoice_number} 给 #{admin_user.name} (#{admin_user.email})"
      puts log_message
      @log << log_message
      @matched_count += 1
    else
      log_message = "未找到匹配项: #{approver_name}，报销单 #{reimbursement.invoice_number}"
      puts log_message
      @log << log_message
      @unmatched_count += 1
    end
  rescue StandardError => e
    log_message = "处理报销单 #{reimbursement.invoice_number} 时出错: #{e.message}"
    puts log_message
    @log << log_message
    @error_count += 1
  end

  def find_matching_admin_user(approver_name)
    normalized_name = normalize_name(approver_name)

    return @admin_user_lookup[normalized_name] if @admin_user_lookup[normalized_name]

    @admin_user_lookup.each do |admin_name, admin|
      return admin if admin_name.include?(normalized_name) || normalized_name.include?(admin_name)
    end

    nil
  end

  def normalize_name(name)
    name.to_s.downcase.gsub(/\s+/, ' ').strip
  end

  def print_summary
    puts "\n=== 摘要 ==="
    puts "总处理: #{@matched_count + @unmatched_count + @error_count}"
    puts "成功匹配并分配: #{@matched_count}"
    puts "未找到匹配项: #{@unmatched_count}"
    puts "错误: #{@error_count}"

    log_file = Rails.root.join('log', "approver_matching_#{Time.now.strftime('%Y%m%d%H%M%S')}.log")
    File.write(log_file, @log.join("\n"))
    puts "日志已写入: #{log_file}"
  end
end

# 使用方法:
system_admin = AdminUser.find_by(email: 'alex.lu@think-bridge.com') || AdminUser.first
if system_admin
  puts "\n准备执行报销单审核通过人匹配脚本..."
  puts "将使用管理员用户: #{system_admin.name} (#{system_admin.email}) 进行分配"
  puts '确认要执行吗? (输入 Y 继续)'

  if gets.chomp.upcase == 'Y'
    service = ApproverMatchingService.new(system_admin)
    service.run
  else
    puts '已取消执行'
  end
else
  puts '错误: 未找到系统管理员用户。请指定一个有效的管理员用户。'
end
