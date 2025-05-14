class AdjustWorkOrderFieldsForAlignment < ActiveRecord::Migration[7.1]
  def change
    # --- Step 1: Ensure audit_result field exists ---
    if column_exists?(:work_orders, :resolution) && !column_exists?(:work_orders, :audit_result)
      puts "Renaming 'resolution' to 'audit_result'."
      rename_column :work_orders, :resolution, :audit_result
    elsif !column_exists?(:work_orders, :audit_result)
      puts "Adding 'audit_result' column."
      add_column :work_orders, :audit_result, :string
    else
      puts "'audit_result' column already exists."
    end

    # --- Step 2: Remove fields that were specific to CommunicationWorkOrder and are no longer needed ---
    if column_exists?(:work_orders, :resolution_summary)
      puts "Removing 'resolution_summary' column."
      remove_column :work_orders, :resolution_summary, :text
    end
    if column_exists?(:work_orders, :communication_method)
      puts "Removing 'communication_method' column."
      remove_column :work_orders, :communication_method, :string
    end
    if column_exists?(:work_orders, :audit_work_order_id)
      puts "Removing 'audit_work_order_id' column."
      remove_column :work_orders, :audit_work_order_id, :integer
    end
    # Consider initiator_role if it's no longer needed after alignment
    # if column_exists?(:work_orders, :initiator_role)
    #   puts "Removing 'initiator_role' column."
    #   remove_column :work_orders, :initiator_role, :string
    # end

    # --- Step 3: Unify creator_id / created_by ---
    if column_exists?(:work_orders, :creator_id) && !column_exists?(:work_orders, :created_by)
      puts "Renaming 'creator_id' to 'created_by'."
      rename_column :work_orders, :creator_id, :created_by
    end

    # --- Step 4: Remove legacy string-based problem_type & problem_description columns ---
    # (Assuming model now solely uses problem_type_id and problem_description_id and data in old columns is not needed)
    if column_exists?(:work_orders, :problem_type)
      puts "Removing legacy 'problem_type' string column."
      remove_column :work_orders, :problem_type, :string
    end
    if column_exists?(:work_orders, :problem_description)
      puts "Removing legacy 'problem_description' string column."
      remove_column :work_orders, :problem_description, :string
    end

    # Note: Fields like audit_comment, audit_date, vat_verified are assumed to be correct
    # for AuditWorkOrder and now also for CommunicationWorkOrder due to alignment.
  end
end