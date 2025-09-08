# app/services/meeting_code_mapping_service.rb
class MeetingCodeMappingService
  MAPPING = {
    '日常会议' => '01',
    '学术会议' => '02',
    '患者教育' => '03', # Based on log, assuming '03', please confirm
    '学术论坛' => '02', # Assuming this maps to the same code as '学术会议'
    # Please provide the complete mapping here
  }.freeze

  def self.call(description)
    return nil if description.blank?
    MAPPING[description]
  end
end