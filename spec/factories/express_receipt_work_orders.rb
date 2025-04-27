FactoryBot.define do
  factory :express_receipt_work_order do
    reimbursement
    status { 'received' }
    tracking_number { "TRK#{rand(1000000)}" }
    courier_name { ['SF Express', 'EMS', 'YTO', 'ZTO'].sample }
    created_by { create(:admin_user).id }
trait :processed do
    status { 'processed' }
  end
  end
end