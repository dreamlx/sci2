require 'rails_helper'

RSpec.describe "Dropdown Options", type: :model do
  describe ProblemTypeOptions do
    it "returns the correct options list" do
      expect(ProblemTypeOptions.all).to eq([
        "发票问题",
        "金额错误",
        "费用类型错误",
        "缺少附件",
        "其他问题"
      ])
    end
  end

  describe ProblemDescriptionOptions do
    it "returns the correct options list" do
      expect(ProblemDescriptionOptions.all).to eq([
        "发票信息不完整",
        "发票金额与申报金额不符",
        "费用类型选择错误",
        "缺少必要证明材料",
        "其他问题说明"
      ])
    end
  end

  describe ProcessingOpinionOptions do
    it "returns the correct options list" do
      expect(ProcessingOpinionOptions.all).to eq([
        "需要补充材料",
        "需要修改申报信息",
        "需要重新提交",
        "可以通过",
        "无法通过"
      ])
    end
  end

  describe InitiatorRoleOptions do
    it "returns the correct options list" do
      expect(InitiatorRoleOptions.all).to eq([
        "财务人员",
        "审核人员",
        "申请人",
        "部门经理",
        "其他"
      ])
    end
  end

  describe CommunicationMethodOptions do
    it "returns the correct options list" do
      expect(CommunicationMethodOptions.all).to eq([
        "电话",
        "邮件",
        "微信",
        "面谈",
        "其他"
      ])
    end
  end

  describe CommunicatorRoleOptions do
    it "returns the correct options list" do
      expect(CommunicatorRoleOptions.all).to eq([
        "财务人员",
        "审核人员",
        "申请人",
        "部门经理",
        "其他"
      ])
    end
  end
end