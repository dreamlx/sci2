require 'rails_helper'

RSpec.describe 'Dropdown Options', type: :model do
  describe ProblemTypeOptions do
    it 'returns the correct options list' do
      expect(ProblemTypeOptions.all).to eq(%w[
                                             发票问题
                                             金额错误
                                             费用类型错误
                                             缺少附件
                                             其他问题
                                           ])
    end
  end

  describe ProcessingOpinionOptions do
    it 'returns the correct options list' do
      expect(ProcessingOpinionOptions.all).to eq(%w[
                                                   可以通过
                                                   无法通过
                                                 ])
    end
  end

  describe InitiatorRoleOptions do
    it 'returns the correct options list' do
      expect(InitiatorRoleOptions.all).to eq(%w[
                                               财务人员
                                               审核人员
                                               申请人
                                               部门主管
                                               其他角色
                                             ])
    end
  end

  describe CommunicationMethodOptions do
    it 'returns the correct options list' do
      expect(CommunicationMethodOptions.all).to eq(%w[
                                                     电话
                                                     邮件
                                                     微信
                                                     当面沟通
                                                     其他方式
                                                   ])
    end
  end

  describe CommunicatorRoleOptions do
    it 'returns the correct options list' do
      expect(CommunicatorRoleOptions.all).to eq(%w[
                                                  财务人员
                                                  审核人员
                                                  申请人
                                                  部门经理
                                                  其他
                                                ])
    end
  end
end
