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

ActiveRecord::Schema[7.1].define(version: 2025_04_26_162440) do
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

  create_table "audit_work_orders", force: :cascade do |t|
    t.integer "reimbursement_id"
    t.integer "express_receipt_work_order_id"
    t.string "status", null: false
    t.string "audit_result"
    t.text "audit_comment"
    t.datetime "audit_date"
    t.boolean "vat_verified"
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_result"], name: "index_audit_work_orders_on_audit_result"
    t.index ["express_receipt_work_order_id"], name: "index_audit_work_orders_on_express_receipt_work_order_id"
    t.index ["reimbursement_id"], name: "index_audit_work_orders_on_reimbursement_id"
    t.index ["status"], name: "index_audit_work_orders_on_status"
  end

  create_table "communication_records", force: :cascade do |t|
    t.integer "communication_work_order_id"
    t.text "content"
    t.string "communicator_role"
    t.string "communicator_name"
    t.string "communication_method"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_work_order_id"], name: "index_communication_records_on_communication_work_order_id"
    t.index ["recorded_at"], name: "index_communication_records_on_recorded_at"
  end

  create_table "communication_work_orders", force: :cascade do |t|
    t.integer "reimbursement_id"
    t.integer "audit_work_order_id"
    t.string "status", null: false
    t.string "communication_method"
    t.string "initiator_role"
    t.text "resolution_summary"
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_work_order_id"], name: "index_communication_work_orders_on_audit_work_order_id"
    t.index ["reimbursement_id"], name: "index_communication_work_orders_on_reimbursement_id"
    t.index ["status"], name: "index_communication_work_orders_on_status"
  end

  create_table "express_receipt_work_orders", force: :cascade do |t|
    t.integer "reimbursement_id"
    t.string "status", null: false
    t.string "tracking_number"
    t.datetime "received_at"
    t.string "courier_name"
    t.integer "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reimbursement_id"], name: "index_express_receipt_work_orders_on_reimbursement_id"
    t.index ["status"], name: "index_express_receipt_work_orders_on_status"
    t.index ["tracking_number"], name: "index_express_receipt_work_orders_on_tracking_number"
  end

  create_table "express_receipts", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "tracking_number"
    t.datetime "receive_date"
    t.string "receiver"
    t.string "courier_company"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_express_receipts_on_document_number"
    t.index ["tracking_number"], name: "index_express_receipts_on_tracking_number"
  end

  create_table "fee_detail_selections", force: :cascade do |t|
    t.integer "fee_detail_id"
    t.integer "audit_work_order_id"
    t.integer "communication_work_order_id"
    t.string "verification_status"
    t.text "verification_comment"
    t.integer "verified_by"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_work_order_id"], name: "index_fee_detail_selections_on_audit_work_order_id"
    t.index ["communication_work_order_id"], name: "index_fee_detail_selections_on_communication_work_order_id"
    t.index ["fee_detail_id", "audit_work_order_id"], name: "index_fee_detail_selections_on_fee_detail_and_audit_work_order", unique: true, where: "audit_work_order_id IS NOT NULL"
    t.index ["fee_detail_id", "communication_work_order_id"], name: "index_fee_detail_selections_on_fee_detail_and_comm_work_order", unique: true, where: "communication_work_order_id IS NOT NULL"
    t.index ["fee_detail_id"], name: "index_fee_detail_selections_on_fee_detail_id"
  end

  create_table "fee_details", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "fee_type"
    t.decimal "amount", precision: 10, scale: 2
    t.string "currency", default: "CNY"
    t.datetime "fee_date"
    t.string "payment_method"
    t.string "verification_status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_fee_details_on_document_number"
    t.index ["verification_status"], name: "index_fee_details_on_verification_status"
  end

  create_table "operation_histories", force: :cascade do |t|
    t.string "document_number", null: false
    t.string "operation_type"
    t.datetime "operation_time"
    t.string "operator"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_operation_histories_on_document_number"
    t.index ["operation_time"], name: "index_operation_histories_on_operation_time"
  end

  create_table "reimbursements", force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "document_name"
    t.string "applicant"
    t.string "applicant_id"
    t.string "company"
    t.string "department"
    t.decimal "amount", precision: 10, scale: 2
    t.string "receipt_status", default: "pending"
    t.string "reimbursement_status", default: "pending"
    t.datetime "receipt_date"
    t.datetime "submission_date"
    t.boolean "is_electronic", default: false
    t.boolean "is_complete", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["applicant"], name: "index_reimbursements_on_applicant"
    t.index ["invoice_number"], name: "index_reimbursements_on_invoice_number", unique: true
    t.index ["is_complete"], name: "index_reimbursements_on_is_complete"
    t.index ["receipt_status"], name: "index_reimbursements_on_receipt_status"
    t.index ["reimbursement_status"], name: "index_reimbursements_on_reimbursement_status"
  end

  create_table "work_order_status_changes", force: :cascade do |t|
    t.string "work_order_type", null: false
    t.integer "work_order_id", null: false
    t.string "from_status"
    t.string "to_status", null: false
    t.datetime "changed_at", null: false
    t.integer "changed_by"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_at"], name: "index_work_order_status_changes_on_changed_at"
    t.index ["work_order_type", "work_order_id"], name: "idx_on_work_order_type_work_order_id_cdd6197b3f"
  end

  add_foreign_key "audit_work_orders", "express_receipt_work_orders"
  add_foreign_key "audit_work_orders", "reimbursements"
  add_foreign_key "communication_records", "communication_work_orders"
  add_foreign_key "communication_work_orders", "audit_work_orders"
  add_foreign_key "communication_work_orders", "reimbursements"
  add_foreign_key "express_receipt_work_orders", "reimbursements"
  add_foreign_key "fee_detail_selections", "audit_work_orders"
  add_foreign_key "fee_detail_selections", "communication_work_orders"
  add_foreign_key "fee_detail_selections", "fee_details"
end
