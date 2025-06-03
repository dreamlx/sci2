require 'rails_helper'

RSpec.describe "Problem Code Import", type: :system, js: true do
  let(:admin_user) { create(:admin_user) }
  
  before do
    login_as(admin_user, scope: :admin_user)
  end
  
  describe "问题代码导入" do
    it "测试问题代码导入功能" do
      # 访问导入页面
      visit admin_imports_path
      
      # 点击问题代码导入链接
      click_link "问题代码导入"
      
      # 验证导入页面标题
      expect(page).to have_content("导入问题代码")
      
      # 准备测试CSV文件
      csv_content = <<~CSV
        EN Code,Exp. Code,费用类型,Issue Code,问题类型,SOP描述,标准处理方法
        EN000101,00,月度交通费,01,燃油费行程问题,根据SOP规定需提供行程,请补充行程信息
        EN000102,00,月度交通费,02,金额超标,检查金额是否超过规定限额,要求说明超标原因
      CSV
      
      # 创建临时文件
      file = Tempfile.new(['test_problem_codes', '.csv'])
      file.write(csv_content)
      file.close
      
      # 上传文件
      attach_file('file', file.path)
      
      # 提交导入表单
      click_button "导入"
      
      # 验证导入结果页面
      expect(page).to have_content("导入结果详情")
      
      # 验证费用类型导入成功
      expect(page).to have_content("00 - 月度交通费")
      
      # 验证问题类型导入成功
      expect(page).to have_content("01 - 燃油费行程问题")
      expect(page).to have_content("02 - 金额超标")
      
      # 清理临时文件
      file.unlink
      
      # 验证数据库中的记录
      fee_type = FeeType.find_by(code: '00', title: '月度交通费')
      expect(fee_type).not_to be_nil
      
      problem_type1 = ProblemType.find_by(code: '01', title: '燃油费行程问题')
      expect(problem_type1).not_to be_nil
      expect(problem_type1.sop_description).to eq('根据SOP规定需提供行程')
      expect(problem_type1.standard_handling).to eq('请补充行程信息')
      
      problem_type2 = ProblemType.find_by(code: '02', title: '金额超标')
      expect(problem_type2).not_to be_nil
      expect(problem_type2.sop_description).to eq('检查金额是否超过规定限额')
      expect(problem_type2.standard_handling).to eq('要求说明超标原因')
    end
    
    it "测试问题代码更新功能" do
      # 创建已存在的费用类型和问题类型
      fee_type = FeeType.create!(
        code: "00",
        title: "旧费用类型名称",
        meeting_type: "个人",
        active: true
      )
      
      problem_type = ProblemType.create!(
        code: "01",
        title: "旧问题类型名称",
        sop_description: "旧SOP描述",
        standard_handling: "旧标准处理方法",
        fee_type: fee_type,
        active: true
      )
      
      # 访问导入页面
      visit admin_imports_path
      
      # 点击问题代码导入链接
      click_link "问题代码导入"
      
      # 准备测试CSV文件（更新现有记录）
      csv_content = <<~CSV
        EN Code,Exp. Code,费用类型,Issue Code,问题类型,SOP描述,标准处理方法
        EN000101,00,月度交通费,01,燃油费行程问题,根据SOP规定需提供行程,请补充行程信息
      CSV
      
      # 创建临时文件
      file = Tempfile.new(['test_problem_codes_update', '.csv'])
      file.write(csv_content)
      file.close
      
      # 上传文件
      attach_file('file', file.path)
      
      # 提交导入表单
      click_button "导入"
      
      # 验证导入结果页面
      expect(page).to have_content("导入结果详情")
      
      # 验证费用类型更新成功
      expect(page).to have_content("00 - 月度交通费")
      expect(page).to have_content("更新")
      
      # 验证问题类型更新成功
      expect(page).to have_content("01 - 燃油费行程问题")
      expect(page).to have_content("更新")
      
      # 清理临时文件
      file.unlink
      
      # 验证数据库中的记录已更新
      fee_type.reload
      expect(fee_type.title).to eq('月度交通费')
      
      problem_type.reload
      expect(problem_type.title).to eq('燃油费行程问题')
      expect(problem_type.sop_description).to eq('根据SOP规定需提供行程')
      expect(problem_type.standard_handling).to eq('请补充行程信息')
    end
  end
end