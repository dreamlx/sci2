# spec/factories/reimbursements.rb
FactoryBot.define do
  factory :reimbursement do
    sequence(:invoice_number) { |n| "R#{Time.now.year}#{sprintf('%06d', n)}" }
    document_name { "测试报销单" }
    applicant { "测试用户" }
    applicant_id { "TEST001" }
    company { "测试公司" }
    department { "测试部门" }
    amount { 500.00 }
    receipt_status { "pending" }
    status { "pending" } # 内部状态
    external_status { "审批中" } # 示例外部状态
    is_electronic { false }

    trait :electronic do
      is_electronic { true }
    end

    trait :received do
      receipt_status { "received" }
      receipt_date { Time.current - 1.day }
    end

    trait :processing do
      status { "processing" }
    end

    trait :close do
      status { "close" }
      external_status { "已付款" } # 示例
      approval_date { Time.current - 2.days }
      approver_name { "测试审批人" }
    end
    
    # Alias for :close trait to support tests using :closed
    trait :closed do
      close
    end
  end
end