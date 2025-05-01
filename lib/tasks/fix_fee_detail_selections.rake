namespace :data do
  desc "Fix fee detail selections with wrong work_order_type"
  task fix_fee_detail_selections: :environment do
    puts "Starting to fix fee detail selections..."
    
    # Fix AuditWorkOrder fee detail selections
    AuditWorkOrder.find_each do |wo|
      count = FeeDetailSelection.where(work_order_id: wo.id, work_order_type: 'WorkOrder')
                               .update_all(work_order_type: 'AuditWorkOrder')
      puts "Updated #{count} fee detail selections for AuditWorkOrder ##{wo.id}" if count > 0
    end
    
    # Fix CommunicationWorkOrder fee detail selections
    CommunicationWorkOrder.find_each do |wo|
      count = FeeDetailSelection.where(work_order_id: wo.id, work_order_type: 'WorkOrder')
                               .update_all(work_order_type: 'CommunicationWorkOrder')
      puts "Updated #{count} fee detail selections for CommunicationWorkOrder ##{wo.id}" if count > 0
    end
    
    puts "Finished fixing fee detail selections."
  end
end