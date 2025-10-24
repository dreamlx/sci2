class CreateWorkOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :work_orders do |t|
      t.references :reimbursement, foreign_key: true, null: false
      t.string :type, null: false, index: true # STI 类型字段
      t.string :status, null: false, index: true
      t.references :creator, foreign_key: { to_table: :admin_users }, null: true

      # 共享字段 (Req 6/7)
      t.string :problem_type
      t.string :problem_description
      t.text :remark
      t.string :processing_opinion

      # ExpressReceiptWorkOrder 特定字段
      t.string :tracking_number, index: true
      t.datetime :received_at
      t.string :courier_name

      # AuditWorkOrder 特定字段
      t.string :audit_result
      t.text :audit_comment
      t.datetime :audit_date
      t.boolean :vat_verified

      # CommunicationWorkOrder 特定字段
      t.string :communication_method
      t.string :initiator_role
      t.text :resolution_summary
      t.references :audit_work_order, foreign_key: { to_table: :work_orders }, null: true

      t.timestamps
    end

    # 添加复合索引用于快递收单工单重复检查
    add_index :work_orders, %i[reimbursement_id tracking_number],
              name: 'index_work_orders_on_reimbursement_and_tracking',
              where: "type = 'ExpressReceiptWorkOrder' AND tracking_number IS NOT NULL"
  end
end
