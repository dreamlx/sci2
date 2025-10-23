# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_17_26_000025) do
  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.integer "resource_id"
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "telephone"
    t.string "role"
    t.string "status", default: "active", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_admin_users_on_deleted_at"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_admin_users_on_status"
  end

  create_table "communication_records", force: :cascade do |t|
    t.integer "communication_work_order_id", null: false
    t.text "content", null: false
    t.string "communicator_role"
    t.string "communicator_name"
    t.string "communication_method"
    t.datetime "recorded_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_work_order_id"], name: "index_communication_records_on_communication_work_order_id"
  end

  create_table "fee_details", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "fee_type"
    t.decimal "amount", precision: 10, scale: 2
    t.date "fee_date"
    t.string "verification_status", default: "pending", null: false
    t.string "month_belonging"
    t.datetime "first_submission_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.string "external_fee_id"
    t.string "plan_or_pre_application"
    t.string "product"
    t.string "flex_field_11"
    t.string "expense_corresponding_plan"
    t.string "expense_associated_application"
    t.string "flex_field_6"
    t.string "flex_field_7"
    t.index ["document_number"], name: "index_fee_details_on_document_number"
    t.index ["external_fee_id"], name: "index_fee_details_on_external_fee_id", unique: true
    t.index ["fee_date"], name: "index_fee_details_on_fee_date"
    t.index ["verification_status"], name: "index_fee_details_on_verification_status"
  end

  create_table "fee_types", force: :cascade do |t|
    t.string "name"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reimbursement_type_code"
    t.string "meeting_type_code"
    t.string "expense_type_code"
    t.string "meeting_name"
    t.index ["active"], name: "index_fee_types_on_active"
    t.index ["reimbursement_type_code", "meeting_type_code", "expense_type_code"], name: "index_fee_types_on_context", unique: true
  end

  create_table "import_performances", force: :cascade do |t|
    t.string "operation_type", null: false
    t.float "elapsed_time", null: false
    t.integer "record_count", default: 0
    t.string "optimization_level"
    t.text "optimization_settings"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_import_performances_on_created_at"
    t.index ["operation_type"], name: "index_import_performances_on_operation_type"
    t.index ["optimization_level"], name: "index_import_performances_on_optimization_level"
  end

  create_table "operation_histories", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "operation_type"
    t.datetime "operation_time"
    t.string "operator"
    t.text "notes"
    t.string "form_type"
    t.string "operation_node"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "applicant"
    t.string "employee_id"
    t.string "employee_company"
    t.string "employee_department"
    t.text "employee_department_path"
    t.string "document_company"
    t.string "document_department"
    t.text "document_department_path"
    t.string "submitter"
    t.string "document_name"
    t.string "currency"
    t.decimal "amount", precision: 10, scale: 2
    t.datetime "created_date"
    t.index ["applicant"], name: "index_operation_histories_on_applicant"
    t.index ["created_date"], name: "index_operation_histories_on_created_date"
    t.index ["currency"], name: "index_operation_histories_on_currency"
    t.index ["document_number", "operation_type", "operation_time", "operator"], name: "index_operation_histories_on_document_and_operation", unique: true
    t.index ["document_number"], name: "index_operation_histories_on_document_number"
    t.index ["employee_company"], name: "index_operation_histories_on_employee_company"
    t.index ["employee_department"], name: "index_operation_histories_on_employee_department"
    t.index ["employee_id"], name: "index_operation_histories_on_employee_id"
    t.index ["operation_time"], name: "index_operation_histories_on_operation_time"
    t.index ["submitter"], name: "index_operation_histories_on_submitter"
  end

  create_table "problem_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.string "issue_code", default: "", null: false
    t.string "title", default: "", null: false
    t.text "sop_description"
    t.text "standard_handling"
    t.string "legacy_problem_code"
    t.integer "fee_type_id", null: false
    t.index ["fee_type_id"], name: "index_problem_types_on_fee_type_id"
  end

  create_table "reimbursement_assignments", force: :cascade do |t|
    t.integer "reimbursement_id", null: false
    t.integer "assignee_id", null: false
    t.integer "assigner_id", null: false
    t.boolean "is_active", default: true
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "is_active"], name: "index_reimbursement_assignments_on_assignee_id_and_is_active"
    t.index ["assignee_id"], name: "index_reimbursement_assignments_on_assignee_id"
    t.index ["assigner_id"], name: "index_reimbursement_assignments_on_assigner_id"
    t.index ["reimbursement_id", "is_active"], name: "idx_on_reimbursement_id_is_active_7c67e0658b"
    t.index ["reimbursement_id"], name: "index_reimbursement_assignments_on_reimbursement_id"
  end

  create_table "reimbursements", force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "document_name"
    t.string "applicant"
    t.string "applicant_id"
    t.string "company"
    t.string "department"
    t.string "receipt_status"
    t.datetime "receipt_date"
    t.datetime "submission_date"
    t.decimal "amount", precision: 10, scale: 2
    t.boolean "is_electronic", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "external_status"
    t.datetime "approval_date"
    t.string "approver_name"
    t.string "related_application_number"
    t.date "accounting_date"
    t.string "document_tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "erp_current_approval_node"
    t.string "erp_current_approver"
    t.string "erp_flexible_field_2"
    t.datetime "erp_node_entry_time"
    t.datetime "erp_first_submitted_at"
    t.string "erp_flexible_field_8"
    t.boolean "manual_override", default: false, null: false
    t.datetime "manual_override_at"
    t.string "last_external_status", limit: 50
    t.datetime "last_viewed_operation_histories_at"
    t.datetime "last_viewed_express_receipts_at"
    t.datetime "last_viewed_at"
    t.datetime "last_update_at"
    t.boolean "has_updates", default: false, null: false
    t.index ["external_status"], name: "index_reimbursements_on_external_status"
    t.index ["invoice_number"], name: "index_reimbursements_on_invoice_number", unique: true
    t.index ["is_electronic"], name: "index_reimbursements_on_is_electronic"
    t.index ["last_external_status"], name: "index_reimbursements_on_last_external_status"
    t.index ["last_viewed_express_receipts_at"], name: "index_reimbursements_on_last_viewed_express_receipts_at"
    t.index ["last_viewed_operation_histories_at"], name: "index_reimbursements_on_last_viewed_operation_histories_at"
    t.index ["manual_override"], name: "index_reimbursements_on_manual_override"
    t.index ["status"], name: "index_reimbursements_on_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "work_order_fee_details", force: :cascade do |t|
    t.integer "work_order_id", null: false
    t.integer "fee_detail_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_detail_id"], name: "index_work_order_fee_details_on_fee_detail_id"
    t.index ["work_order_id", "fee_detail_id"], name: "index_work_order_fee_details_on_wo_and_fd", unique: true
    t.index ["work_order_id"], name: "index_work_order_fee_details_on_work_order_id"
  end

  create_table "work_order_operations", force: :cascade do |t|
    t.integer "work_order_id", null: false
    t.integer "admin_user_id", null: false
    t.string "operation_type", null: false
    t.text "details"
    t.text "previous_state"
    t.text "current_state"
    t.datetime "created_at", null: false
    t.index ["admin_user_id", "created_at"], name: "index_work_order_operations_on_admin_user_id_and_created_at"
    t.index ["admin_user_id"], name: "index_work_order_operations_on_admin_user_id"
    t.index ["operation_type", "created_at"], name: "index_work_order_operations_on_operation_type_and_created_at"
    t.index ["work_order_id", "created_at"], name: "index_work_order_operations_on_work_order_id_and_created_at"
    t.index ["work_order_id"], name: "index_work_order_operations_on_work_order_id"
  end

  create_table "work_order_problems", force: :cascade do |t|
    t.integer "work_order_id", null: false
    t.integer "problem_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["problem_type_id"], name: "index_work_order_problems_on_problem_type_id"
    t.index ["work_order_id", "problem_type_id"], name: "idx_work_order_problems_unique", unique: true
    t.index ["work_order_id"], name: "index_work_order_problems_on_work_order_id"
  end

  create_table "work_order_status_changes", force: :cascade do |t|
    t.string "work_order_type", null: false
    t.integer "work_order_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.datetime "changed_at", null: false
    t.integer "changer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_at"], name: "index_work_order_status_changes_on_changed_at"
    t.index ["changer_id"], name: "index_work_order_status_changes_on_changer_id"
    t.index ["work_order_type", "work_order_id"], name: "index_work_order_status_changes_on_work_order"
  end

  create_table "work_orders", force: :cascade do |t|
    t.integer "reimbursement_id", null: false
    t.string "type", null: false
    t.string "status", null: false
    t.integer "created_by"
    t.string "processing_opinion"
    t.string "tracking_number"
    t.datetime "received_at"
    t.string "courier_name"
    t.string "audit_result"
    t.text "audit_comment"
    t.datetime "audit_date"
    t.boolean "vat_verified"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "problem_type_id"
    t.string "initiator_role", default: "internal"
    t.string "communication_method"
    t.integer "fee_type_id"
    t.string "filling_id", limit: 10
    t.integer "assignee_id"
    t.index ["assignee_id"], name: "index_work_orders_on_assignee_id"
    t.index ["created_by"], name: "index_work_orders_on_created_by"
    t.index ["filling_id"], name: "index_work_orders_on_filling_id", unique: true, where: "type = 'ExpressReceiptWorkOrder' AND filling_id IS NOT NULL"
    t.index ["reimbursement_id", "tracking_number"], name: "index_work_orders_on_reimbursement_and_tracking", where: "type = 'ExpressReceiptWorkOrder' AND tracking_number IS NOT NULL"
    t.index ["reimbursement_id"], name: "index_work_orders_on_reimbursement_id"
    t.index ["status"], name: "index_work_orders_on_status"
    t.index ["tracking_number"], name: "index_work_orders_on_tracking_number"
    t.index ["type"], name: "index_work_orders_on_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "communication_records", "work_orders", column: "communication_work_order_id"
  add_foreign_key "problem_types", "fee_types"
  add_foreign_key "reimbursement_assignments", "admin_users", column: "assignee_id"
  add_foreign_key "reimbursement_assignments", "admin_users", column: "assigner_id"
  add_foreign_key "reimbursement_assignments", "reimbursements"
  add_foreign_key "work_order_fee_details", "fee_details"
  add_foreign_key "work_order_fee_details", "work_orders"
  add_foreign_key "work_order_operations", "admin_users"
  add_foreign_key "work_order_operations", "work_orders"
  add_foreign_key "work_order_problems", "problem_types"
  add_foreign_key "work_order_problems", "work_orders"
  add_foreign_key "work_order_status_changes", "admin_users", column: "changer_id"
  add_foreign_key "work_orders", "admin_users", column: "assignee_id"
  add_foreign_key "work_orders", "admin_users", column: "created_by"
  add_foreign_key "work_orders", "reimbursements"
end
