# lib/tasks/create_academic_general_fee_types.rake
namespace :fee_types do
  desc '为学术会议创建通用费用类型和对应的问题类型'
  task create_academic_general_types: :environment do
    puts '开始为学术会议创建通用费用类型和问题类型...'

    # 只为学术论坛创建通用费用类型
    academic_meeting_type = '学术论坛'

    # 创建学术会议的通用费用类型
    general_fee_type = FeeType.find_or_create_by(
      code: 'GENERAL_ACADEMIC',
      meeting_type: academic_meeting_type
    ) do |ft|
      ft.title = '通用问题-学术论坛'
      ft.name = '通用问题-学术论坛'
      ft.active = true
    end

    puts "创建通用费用类型: #{general_fee_type.display_name}"

    # 创建学术会议的通用问题类型
    create_academic_general_problem_types(general_fee_type)

    puts '学术会议通用费用类型和问题类型创建完成！'
  end

  private

  def create_academic_general_problem_types(fee_type)
    puts "为 #{fee_type.title} 创建通用问题类型..."

    general_problems = [
      {
        code: 'ACADEMIC_GENERAL_001',
        title: '报销单填写不完整',
        sop_description: '检查学术会议报销单各项信息是否完整填写，包括会议名称、时间、地点等',
        standard_handling: '要求补充完整信息后重新提交，特别注意学术会议相关证明材料'
      },
      {
        code: 'ACADEMIC_GENERAL_002',
        title: '审批流程不规范',
        sop_description: '检查学术会议费用审批流程是否符合公司规定',
        standard_handling: '按照学术会议费用审批的正确流程重新审批'
      },
      {
        code: 'ACADEMIC_GENERAL_003',
        title: '会议证明材料缺失',
        sop_description: '检查是否提供了学术会议的邀请函、议程、参会证明等必要材料',
        standard_handling: '要求提供完整的学术会议证明材料'
      },
      {
        code: 'ACADEMIC_GENERAL_004',
        title: '费用标准超出规定',
        sop_description: '检查学术会议相关费用是否超出公司规定的标准',
        standard_handling: '按照公司学术会议费用标准进行调整或提供超标说明'
      },
      {
        code: 'ACADEMIC_GENERAL_005',
        title: '时间跨度不合理',
        sop_description: '检查学术会议费用发生时间是否与会议时间匹配',
        standard_handling: '要求提供时间说明或重新整理符合会议时间的费用单据'
      }
    ]

    general_problems.each do |problem_data|
      problem_type = ProblemType.find_or_create_by(
        code: problem_data[:code],
        fee_type: fee_type
      ) do |pt|
        pt.title = problem_data[:title]
        pt.sop_description = problem_data[:sop_description]
        pt.standard_handling = problem_data[:standard_handling]
        pt.active = true
      end

      puts "  创建问题类型: #{problem_type.code} - #{problem_type.title}"
    end
  end
end
