# lib/tasks/create_general_fee_types.rake
# 为费用类型和问题类型优化方案创建数据准备脚本

namespace :data do
  desc "为每个会议类型创建通用费用类型和关联的通用问题类型"
  task create_general_fee_types: :environment do
    puts "开始创建通用费用类型和问题类型..."
    
    # 定义会议类型（从现有数据中获取或使用默认值）
    meeting_types = FeeType.distinct.pluck(:meeting_type).reject(&:blank?)
    
    # 如果没有找到会议类型，使用一些默认值
    if meeting_types.empty?
      meeting_types = ['学术会议', '商务会议', '培训会议', '内部会议']
      puts "未找到现有会议类型，使用默认值: #{meeting_types.join(', ')}"
    else
      puts "找到现有会议类型: #{meeting_types.join(', ')}"
    end
    
    created_fee_types = 0
    created_problem_types = 0
    
    meeting_types.each do |meeting_type|
      puts "\n处理会议类型: #{meeting_type}"
      
      # 创建或查找通用费用类型
      general_fee_type = FeeType.find_or_create_by(
        code: "GENERAL_#{meeting_type.upcase.gsub(/\s+/, '_')}",
        title: "通用问题",
        meeting_type: meeting_type,
        active: true
      )
      
      if general_fee_type.just_created?
        puts "  ✓ 创建通用费用类型: #{general_fee_type.code}"
        created_fee_types += 1
      else
        puts "  ✓ 通用费用类型已存在: #{general_fee_type.code}"
      end
      
      # 为该通用费用类型创建通用问题类型
      general_problems = [
        {
          code: "GENERAL_001",
          title: "报销单填写不完整",
          sop_description: "检查报销单各项信息是否完整，包括申请信息、费用明细、附件等",
          standard_handling: "要求补充完整信息后重新提交"
        },
        {
          code: "GENERAL_002", 
          title: "审批流程不规范",
          sop_description: "检查审批流程是否符合公司规定，包括审批权限、审批顺序等",
          standard_handling: "按规定流程重新审批"
        },
        {
          code: "GENERAL_003",
          title: "附件材料不齐全",
          sop_description: "检查是否缺少必要的附件材料，如发票、行程单、会议通知等",
          standard_handling: "补充相关附件材料"
        },
        {
          code: "GENERAL_004",
          title: "费用金额异常",
          sop_description: "检查费用金额是否合理，是否存在超出标准或异常情况",
          standard_handling: "核实费用情况，提供合理解释或调整金额"
        },
        {
          code: "GENERAL_005",
          title: "费用类型选择错误",
          sop_description: "检查费用类型是否与实际费用性质匹配，是否存在错选费用类型的情况",
          standard_handling: "重新选择正确的费用类型"
        }
      ]
      
      general_problems.each do |problem_data|
        problem_type = ProblemType.find_or_create_by(
          code: problem_data[:code],
          fee_type: general_fee_type
        ) do |pt|
          pt.title = problem_data[:title]
          pt.sop_description = problem_data[:sop_description]
          pt.standard_handling = problem_data[:standard_handling]
          pt.active = true
        end
        
        if problem_type.just_created?
          puts "    ✓ 创建通用问题类型: #{problem_type.title}"
          created_problem_types += 1
        else
          puts "    ✓ 通用问题类型已存在: #{problem_type.title}"
        end
      end
    end
    
    puts "\n=== 创建完成 ==="
    puts "创建的通用费用类型数量: #{created_fee_types}"
    puts "创建的通用问题类型数量: #{created_problem_types}"
    
    # 显示创建的数据统计
    puts "\n=== 数据统计 ==="
    general_fee_types = FeeType.where("code LIKE 'GENERAL_%'")
    puts "通用费用类型总数: #{general_fee_types.count}"
    
    general_problem_types = ProblemType.joins(:fee_type).where("fee_types.code LIKE 'GENERAL_%'")
    puts "通用问题类型总数: #{general_problem_types.count}"
    
    puts "\n按会议类型统计:"
    general_fee_types.each do |fee_type|
      problem_count = fee_type.problem_types.count
      puts "  #{fee_type.meeting_type}: #{problem_count} 个通用问题类型"
    end
    
    puts "\n数据准备完成！现在可以实施前端优化了。"
  end
  
  desc "显示当前费用类型和问题类型统计"
  task show_fee_type_stats: :environment do
    puts "=== 费用类型统计 ==="
    puts "费用类型总数: #{FeeType.count}"
    puts "活跃费用类型: #{FeeType.active.count}"
    
    puts "\n=== 问题类型统计 ==="
    puts "问题类型总数: #{ProblemType.count}"
    puts "活跃问题类型: #{ProblemType.active.count}"
    
    puts "\n=== 通用费用类型统计 ==="
    general_fee_types = FeeType.where("code LIKE 'GENERAL_%'")
    puts "通用费用类型数量: #{general_fee_types.count}"
    
    puts "\n=== 通用问题类型统计 ==="
    general_problem_types = ProblemType.joins(:fee_type).where("fee_types.code LIKE 'GENERAL_%'")
    puts "通用问题类型数量: #{general_problem_types.count}"
    
    puts "\n=== 按会议类型统计 ==="
    meeting_types = FeeType.distinct.pluck(:meeting_type).reject(&:blank?)
    meeting_types.each do |meeting_type|
      fee_types = FeeType.by_meeting_type(meeting_type)
      general_fee_type = fee_types.find { |ft| ft.code.start_with?('GENERAL_') }
      specific_fee_types = fee_types.reject { |ft| ft.code.start_with?('GENERAL_') }
      
      puts "\n会议类型: #{meeting_type}"
      puts "  具体费用类型: #{specific_fee_types.count} 个"
      puts "  通用费用类型: #{general_fee_type ? '1 个' : '0 个'}"
      
      if general_fee_type
        problem_count = general_fee_type.problem_types.count
        puts "  通用问题类型: #{problem_count} 个"
      end
    end
  end
  
  desc "清理通用费用类型和问题类型（谨慎使用）"
  task cleanup_general_fee_types: :environment do
    puts "⚠️  警告：此操作将删除所有通用费用类型和关联的问题类型"
    print "确定要继续吗？(输入 'YES' 确认): "
    confirmation = STDIN.gets.chomp
    
    if confirmation == 'YES'
      puts "开始清理通用费用类型和问题类型..."
      
      general_fee_types = FeeType.where("code LIKE 'GENERAL_%'")
      general_fee_type_count = general_fee_types.count
      
      general_problem_types = ProblemType.joins(:fee_type).where("fee_types.code LIKE 'GENERAL_%'")
      general_problem_type_count = general_problem_types.count
      
      puts "将删除 #{general_fee_type_count} 个通用费用类型"
      puts "将删除 #{general_problem_type_count} 个通用问题类型"
      
      # 删除通用问题类型
      general_problem_types.destroy_all
      
      # 删除通用费用类型
      general_fee_types.destroy_all
      
      puts "清理完成！"
    else
      puts "操作已取消"
    end
  end
end