require 'rails_helper'
require 'tempfile'

RSpec.describe ProblemCodeImportService, type: :service do
  describe "#import" do
    let(:personal_csv_content) do
      <<~CSV
        费用类型代码,费用类型名称,问题代码,问题名称,SOP描述,标准处理方法
        00,月度交通费（销售/SMO/CO）,01,燃油费行程问题,检查燃油费是否与行程匹配,要求提供详细行程单
        00,月度交通费（销售/SMO/CO）,02,交通费超标,检查交通费是否超过标准,要求提供说明
        03,电话费,01,电话费不合规,检查电话费是否符合规定,要求提供通话记录
      CSV
    end
    
    let(:academic_csv_content) do
      <<~CSV
        费用类型代码,费用类型名称,问题代码,问题名称,SOP描述,标准处理方法
        01,会议整体费用,01,会议议程不完整,检查会议议程是否完整,要求提供完整议程
        01,会议整体费用,02,参会人员不符,检查参会人员是否符合要求,要求提供参会人员名单
        02,会议餐饮费,01,餐饮费超标,检查餐饮费是否超过标准,要求提供说明
      CSV
    end
    
    let(:personal_csv_file) do
      file = Tempfile.new(['personal', '.csv'])
      file.write(personal_csv_content)
      file.close
      file.path
    end
    
    let(:academic_csv_file) do
      file = Tempfile.new(['academic', '.csv'])
      file.write(academic_csv_content)
      file.close
      file.path
    end
    
    after do
      File.unlink(personal_csv_file) if File.exist?(personal_csv_file)
      File.unlink(academic_csv_file) if File.exist?(academic_csv_file)
    end
    
    it "imports personal problem codes correctly" do
      service = ProblemCodeImportService.new(personal_csv_file, "个人")
      service.import
      
      # Check fee types
      expect(FeeType.count).to eq(2)
      
      traffic_fee_type = FeeType.find_by(code: "00")
      expect(traffic_fee_type).to be_present
      expect(traffic_fee_type.title).to eq("月度交通费（销售/SMO/CO）")
      expect(traffic_fee_type.meeting_type).to eq("个人")
      expect(traffic_fee_type.active).to be true
      
      phone_fee_type = FeeType.find_by(code: "03")
      expect(phone_fee_type).to be_present
      expect(phone_fee_type.title).to eq("电话费")
      expect(phone_fee_type.meeting_type).to eq("个人")
      expect(phone_fee_type.active).to be true
      
      # Check problem types
      expect(ProblemType.count).to eq(3)
      
      fuel_problem = ProblemType.find_by(code: "01", fee_type_id: traffic_fee_type.id)
      expect(fuel_problem).to be_present
      expect(fuel_problem.title).to eq("燃油费行程问题")
      expect(fuel_problem.sop_description).to eq("检查燃油费是否与行程匹配")
      expect(fuel_problem.standard_handling).to eq("要求提供详细行程单")
      expect(fuel_problem.active).to be true
      
      traffic_problem = ProblemType.find_by(code: "02", fee_type_id: traffic_fee_type.id)
      expect(traffic_problem).to be_present
      expect(traffic_problem.title).to eq("交通费超标")
      expect(traffic_problem.sop_description).to eq("检查交通费是否超过标准")
      expect(traffic_problem.standard_handling).to eq("要求提供说明")
      expect(traffic_problem.active).to be true
      
      phone_problem = ProblemType.find_by(code: "01", fee_type_id: phone_fee_type.id)
      expect(phone_problem).to be_present
      expect(phone_problem.title).to eq("电话费不合规")
      expect(phone_problem.sop_description).to eq("检查电话费是否符合规定")
      expect(phone_problem.standard_handling).to eq("要求提供通话记录")
      expect(phone_problem.active).to be true
    end
    
    it "imports academic problem codes correctly" do
      service = ProblemCodeImportService.new(academic_csv_file, "学术论坛")
      service.import
      
      # Check fee types
      expect(FeeType.count).to eq(2)
      
      meeting_fee_type = FeeType.find_by(code: "01")
      expect(meeting_fee_type).to be_present
      expect(meeting_fee_type.title).to eq("会议整体费用")
      expect(meeting_fee_type.meeting_type).to eq("学术论坛")
      expect(meeting_fee_type.active).to be true
      
      dining_fee_type = FeeType.find_by(code: "02")
      expect(dining_fee_type).to be_present
      expect(dining_fee_type.title).to eq("会议餐饮费")
      expect(dining_fee_type.meeting_type).to eq("学术论坛")
      expect(dining_fee_type.active).to be true
      
      # Check problem types
      expect(ProblemType.count).to eq(3)
      
      agenda_problem = ProblemType.find_by(code: "01", fee_type_id: meeting_fee_type.id)
      expect(agenda_problem).to be_present
      expect(agenda_problem.title).to eq("会议议程不完整")
      expect(agenda_problem.sop_description).to eq("检查会议议程是否完整")
      expect(agenda_problem.standard_handling).to eq("要求提供完整议程")
      expect(agenda_problem.active).to be true
      
      attendee_problem = ProblemType.find_by(code: "02", fee_type_id: meeting_fee_type.id)
      expect(attendee_problem).to be_present
      expect(attendee_problem.title).to eq("参会人员不符")
      expect(attendee_problem.sop_description).to eq("检查参会人员是否符合要求")
      expect(attendee_problem.standard_handling).to eq("要求提供参会人员名单")
      expect(attendee_problem.active).to be true
      
      dining_problem = ProblemType.find_by(code: "01", fee_type_id: dining_fee_type.id)
      expect(dining_problem).to be_present
      expect(dining_problem.title).to eq("餐饮费超标")
      expect(dining_problem.sop_description).to eq("检查餐饮费是否超过标准")
      expect(dining_problem.standard_handling).to eq("要求提供说明")
      expect(dining_problem.active).to be true
    end
    
    it "updates existing fee types and problem types" do
      # First import
      service = ProblemCodeImportService.new(personal_csv_file, "个人")
      service.import
      
      # Modify the CSV content
      modified_csv_content = <<~CSV
        费用类型代码,费用类型名称,问题代码,问题名称,SOP描述,标准处理方法
        00,月度交通费（更新）,01,燃油费行程问题（更新）,检查燃油费是否与行程匹配（更新）,要求提供详细行程单（更新）
        00,月度交通费（更新）,03,新增问题,新增SOP描述,新增标准处理方法
      CSV
      
      modified_csv_file = Tempfile.new(['modified', '.csv'])
      modified_csv_file.write(modified_csv_content)
      modified_csv_file.close
      
      # Second import
      service = ProblemCodeImportService.new(modified_csv_file.path, "个人")
      service.import
      
      # Check updates
      traffic_fee_type = FeeType.find_by(code: "00")
      expect(traffic_fee_type.title).to eq("月度交通费（更新）")
      
      fuel_problem = ProblemType.find_by(code: "01", fee_type_id: traffic_fee_type.id)
      expect(fuel_problem.title).to eq("燃油费行程问题（更新）")
      expect(fuel_problem.sop_description).to eq("检查燃油费是否与行程匹配（更新）")
      expect(fuel_problem.standard_handling).to eq("要求提供详细行程单（更新）")
      
      # Check new problem
      new_problem = ProblemType.find_by(code: "03", fee_type_id: traffic_fee_type.id)
      expect(new_problem).to be_present
      expect(new_problem.title).to eq("新增问题")
      expect(new_problem.sop_description).to eq("新增SOP描述")
      expect(new_problem.standard_handling).to eq("新增标准处理方法")
      
      # Clean up
      File.unlink(modified_csv_file.path) if File.exist?(modified_csv_file.path)
    end
    
    it "handles missing or invalid data gracefully" do
      invalid_csv_content = <<~CSV
        费用类型代码,费用类型名称,问题代码,问题名称,SOP描述,标准处理方法
        ,月度交通费（销售/SMO/CO）,01,燃油费行程问题,检查燃油费是否与行程匹配,要求提供详细行程单
        00,,01,燃油费行程问题,检查燃油费是否与行程匹配,要求提供详细行程单
        00,月度交通费（销售/SMO/CO）,,燃油费行程问题,检查燃油费是否与行程匹配,要求提供详细行程单
        00,月度交通费（销售/SMO/CO）,01,,检查燃油费是否与行程匹配,要求提供详细行程单
      CSV
      
      invalid_csv_file = Tempfile.new(['invalid', '.csv'])
      invalid_csv_file.write(invalid_csv_content)
      invalid_csv_file.close
      
      service = ProblemCodeImportService.new(invalid_csv_file.path, "个人")
      service.import
      
      # No fee types or problem types should be created
      expect(FeeType.count).to eq(0)
      expect(ProblemType.count).to eq(0)
      
      # Clean up
      File.unlink(invalid_csv_file.path) if File.exist?(invalid_csv_file.path)
    end
  end
end