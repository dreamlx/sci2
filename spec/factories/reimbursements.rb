FactoryBot.define do
  factory :reimbursement do
    sequence(:invoice_number) { |n| "R#{Time.current.strftime('%Y%m%d')}#{n.to_s.rjust(3, '0')}" }
    document_name { "测试报销单" }
    applicant { "测试用户" }
    applicant_id { "EMP001" }
    company { "测试公司" }
    department { "测试部门" }
    amount { 1000.00 }
    receipt_status { "pending" }
    reimbursement_status { "pending" }
    is_electronic { false }
    is_complete { false }
    
    trait :electronic do
      is_electronic { true }
    end
    
    trait :received do
      receipt_status { "received" }
      receipt_date { Time.current }
    end
    
    trait :completed do
      is_complete { true }
      reimbursement_status { "closed" }
    end
  end
end