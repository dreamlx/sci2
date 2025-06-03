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

ActiveRecord::Schema[7.1].define(version: 2025_17_26_000008) do
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

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
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
    t.string "code", null: false
    t.string "title", null: false
    t.string "meeting_type", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_fee_types_on_active"
    t.index ["code"], name: "index_fee_types_on_code", unique: true
    t.index ["meeting_type"], name: "index_fee_types_on_meeting_type"
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
    t.index ["document_number", "operation_type", "operation_time", "operator"], name: "index_operation_histories_on_document_and_operation", unique: true
    t.index ["document_number"], name: "index_operation_histories_on_document_number"
    t.index ["operation_time"], name: "index_operation_histories_on_operation_time"
  end

  create_table "problem_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.string "code", default: "", null: false
    t.string "title", default: "", null: false
    t.text "sop_description"
    t.text "standard_handling"
    t.integer "fee_type_id"
    t.index ["code", "fee_type_id"], name: "index_problem_types_on_code_and_fee_type_id", unique: true
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
    t.index ["external_status"], name: "index_reimbursements_on_external_status"
    t.index ["invoice_number"], name: "index_reimbursements_on_invoice_number", unique: true
    t.index ["is_electronic"], name: "index_reimbursements_on_is_electronic"
    t.index ["status"], name: "index_reimbursements_on_status"
  end

  create_table "work_order_fee_details", force: :cascade do |t|
    t.integer "fee_detail_id", null: false
    t.integer "work_order_id", null: false
    t.string "work_order_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fee_detail_id", "work_order_id", "work_order_type"], name: "index_work_order_fee_details_uniqueness", unique: true
    t.index ["fee_detail_id"], name: "index_work_order_fee_details_on_fee_detail_id"
    t.index ["work_order_id", "work_order_type"], name: "index_work_order_fee_details_on_work_order"
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
    t.text "remark"
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
    t.index ["created_by"], name: "index_work_orders_on_created_by"
    t.index ["reimbursement_id", "tracking_number"], name: "index_work_orders_on_reimbursement_and_tracking", where: "type = 'ExpressReceiptWorkOrder' AND tracking_number IS NOT NULL"
    t.index ["reimbursement_id"], name: "index_work_orders_on_reimbursement_id"
    t.index ["status"], name: "index_work_orders_on_status"
    t.index ["tracking_number"], name: "index_work_orders_on_tracking_number"
    t.index ["type"], name: "index_work_orders_on_type"
  end

  add_foreign_key "communication_records", "work_orders", column: "communication_work_order_id"
  add_foreign_key "problem_types", "fee_types"
  add_foreign_key "reimbursement_assignments", "admin_users", column: "assignee_id"
  add_foreign_key "reimbursement_assignments", "admin_users", column: "assigner_id"
  add_foreign_key "reimbursement_assignments", "reimbursements"
  add_foreign_key "work_order_fee_details", "fee_details"
  add_foreign_key "work_order_operations", "admin_users"
  add_foreign_key "work_order_operations", "work_orders"
  add_foreign_key "work_order_status_changes", "admin_users", column: "changer_id"
  add_foreign_key "work_orders", "admin_users", column: "created_by"
  add_foreign_key "work_orders", "reimbursements"
end
