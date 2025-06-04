# app/services/fee_detail_group_service.rb
class FeeDetailGroupService
  def initialize(fee_detail_ids)
    @fee_detail_ids = Array(fee_detail_ids).map(&:to_i).uniq
    @fee_details = FeeDetail.where(id: @fee_detail_ids)
  end
  
  # 按费用类型分组
  def group_by_fee_type
    # 创建分组结果
    result = {}
    
    @fee_details.each do |fee_detail|
      fee_type = fee_detail.fee_type.to_s
      
      # 初始化分组
      result[fee_type] ||= {
        fee_type: fee_type,
        fee_type_id: get_fee_type_id(fee_type),
        details: []
      }
      
      # 添加到分组
      result[fee_type][:details] << {
        id: fee_detail.id,
        amount: fee_detail.amount,
        fee_date: fee_detail.fee_date,
        verification_status: fee_detail.verification_status
      }
    end
    
    result.values
  end
  
  # 获取所有相关的费用类型
  def fee_types
    @fee_details.pluck(:fee_type).compact.uniq
  end
  
  # 获取所有相关的费用类型ID
  def fee_type_ids
    # 从费用类型名称获取ID
    fee_types.map { |fee_type| get_fee_type_id(fee_type) }.compact
  end
  
  # 获取所有相关的问题类型
  def available_problem_types
    ProblemType.active.where(fee_type_id: fee_type_ids)
  end
  
  # 按费用类型分组的问题类型
  def problem_types_by_fee_type
    result = {}
    
    available_problem_types.each do |problem_type|
      fee_type_id = problem_type.fee_type_id
      
      # 初始化分组
      result[fee_type_id] ||= []
      
      # 添加到分组
      result[fee_type_id] << {
        id: problem_type.id,
        code: problem_type.code,
        title: problem_type.title,
        display_name: problem_type.display_name,
        fee_type_id: fee_type_id
      }
    end
    
    result
  end
  
  private
  
  # 从费用类型名称获取ID
  def get_fee_type_id(fee_type_name)
    # 查找费用类型
    fee_type = FeeType.find_by("title LIKE ? OR code LIKE ?", "%#{fee_type_name}%", "%#{fee_type_name}%")
    fee_type&.id
  end
end