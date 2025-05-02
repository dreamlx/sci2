# spec/integration/full_workflow_spec.rb
require 'rails_helper'
require 'csv'
require 'state_machines'
require 'state_machines-activerecord'

RSpec.describe "Full Workflow Integration", type: :model do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursements_csv_path) { Rails.root.join('spec/fixtures/files/test_reimbursements.csv') }
  let(:express_receipts_csv_path) { Rails.root.join('spec/fixtures/files/test_express_receipts.csv') }
  let(:fee_details_csv_path) { Rails.root.join('spec/fixtures/files/test_fee_details.csv') }
  let(:operation_histories_csv_path) { Rails.root.join('spec/fixtures/files/test_operation_histories.csv') }
  let(:operation_histories_approval_csv_path) { Rails.root.join('spec/fixtures/files/test_operation_histories_approval.csv') }

  before do
    # 清理数据库
    DatabaseCleaner.clean_with(:truncation)
    # 创建 AdminUser
    admin_user
    # 确保 Current.admin_user 在测试期间可用
    allow(Current).to receive(:admin_user).and_return(admin_user)

    # 创建测试所需的 CSV 文件
    create_test_csv_files
  end


  scenario "simulating a full reimbursement processing workflow" do
    # 第一阶段：数据导入
    puts "\n--- 第一阶段：数据导入 ---"
    
    # 导入报销单
    puts "Before import - Reimbursement count: #{Reimbursement.count}"
    uploaded_file = Rack::Test::UploadedFile.new(reimbursements_csv_path, 'text/csv')
    import_result = ReimbursementImportService.new(uploaded_file, admin_user).import
    puts "Import result: #{import_result.inspect}"
    unless import_result[:success]
      puts "Reimbursement import failed: #{import_result[:errors].join(', ')}"
      puts "Error details: #{import_result[:error_details].join('; ')}" if import_result[:error_details].present?
    end
    puts "After import - Reimbursement count: #{Reimbursement.count}"
    puts "Reimbursement records:"
    Reimbursement.all.each { |r| puts r.inspect }
    expect(Reimbursement.count).to eq(10)
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['pending'])
    puts "报销单导入完成，共 #{Reimbursement.count} 条，状态：#{Reimbursement.all.pluck(:status).uniq}"

    # 导入快递收单
    uploaded_file = Rack::Test::UploadedFile.new(express_receipts_csv_path, 'text/csv')
    import_result = ExpressReceiptImportService.new(uploaded_file, admin_user).import
    unless import_result[:success]
      puts "Express Receipt import failed: #{import_result[:errors].join(', ')}"
    end
    if import_result[:unmatched].to_i > 0
      puts "Express Receipt unmatched records: #{import_result[:unmatched_details].inspect}"
    end
    expect(ExpressReceiptWorkOrder.count).to eq(10)
    expect(ExpressReceiptWorkOrder.all.pluck(:status).uniq).to eq(['completed'])
    # 验证报销单状态未变
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['processing'])
    puts "快递收单导入完成，共 #{ExpressReceiptWorkOrder.count} 条工单，状态：#{ExpressReceiptWorkOrder.all.pluck(:status).uniq}"

    # 导入费用明细
    puts "Before FeeDetail import - Reimbursement count: #{Reimbursement.count}"
    puts "Reimbursement invoice_numbers: #{Reimbursement.pluck(:invoice_number)}"
    puts "FeeDetails CSV path: #{fee_details_csv_path}"
    puts "FeeDetails CSV content:"
    puts File.read(fee_details_csv_path).lines.first(5).join
    
    uploaded_file = Rack::Test::UploadedFile.new(fee_details_csv_path, 'text/csv')
    import_result = FeeDetailImportService.new(uploaded_file, admin_user).import
    puts "FeeDetail import result: #{import_result}"
    
    unless import_result[:success]
      puts "Fee detail import failed: #{import_result[:errors].join(', ')}"
      puts "Unmatched details: #{import_result[:unmatched_details].map { |d| "#{d[:document_number]} (#{d[:error]})" }.join(', ')}" if import_result[:unmatched_details].present?
    end
    
    puts "After FeeDetail import - FeeDetail count: #{FeeDetail.count}"
    puts "FeeDetail records:"
    FeeDetail.all.each { |fd| puts fd.inspect }
    
    expect(FeeDetail.count).to eq(9) # 根据测试场景，导入9条费用明细 (R2025005有两条，R2025006有一条，R2025007有两条)
    expect(FeeDetail.all.pluck(:verification_status).uniq).to eq(['pending'])
    puts "费用明细导入完成，共 #{FeeDetail.count} 条，验证状态：#{FeeDetail.all.pluck(:verification_status).uniq}"

    # 导入操作历史
    puts "Before OperationHistory import - OperationHistory count: #{OperationHistory.count}"
    puts "OperationHistory CSV path: #{operation_histories_csv_path}"
    puts "OperationHistory CSV content:"
    puts File.read(operation_histories_csv_path).lines.first(5).join
    
    uploaded_file = Rack::Test::UploadedFile.new(operation_histories_csv_path, 'text/csv')
    import_result = OperationHistoryImportService.new(uploaded_file, admin_user).import
    puts "OperationHistory import result: #{import_result}"
    
    unless import_result[:success]
      puts "Operation history import failed: #{import_result[:errors].join(', ')}"
      puts "Error details: #{import_result[:error_details].join('; ')}" if import_result[:error_details].present?
    end
    
    puts "After OperationHistory import - OperationHistory count: #{OperationHistory.count}"
    puts "OperationHistory records:"
    OperationHistory.all.each { |oh| puts oh.inspect }
    
    expect(OperationHistory.count).to eq(10)
    # 验证报销单状态未因提交操作历史改变
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['processing'])
    puts "操作历史导入完成，共 #{OperationHistory.count} 条。"

    puts "--- 第一阶段：数据导入完成 ---"

    # 第二阶段：审核工单处理
    puts "\n--- 第二阶段：审核工单处理 ---"
    # 报销单 R2025001（直接通过路径）
    reimbursement1 = Reimbursement.find_by(invoice_number: 'ER14228251')
    audit_wo1 = AuditWorkOrder.create!(reimbursement: reimbursement1, creator_id: admin_user.id)
    audit_wo1.select_fee_details(reimbursement1.fee_details.pluck(:id))
    audit_wo1.processing_opinion = "审核通过"
    audit_wo1.save! # 直接通过

    expect(audit_wo1.reload.status).to eq('approved')
    expect(reimbursement1.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement1.reload.status).to eq('waiting_completion')
    puts "报销单 R2025001 审核通过流程验证通过。"

    # 报销单 R2025002（标准通过路径）
    reimbursement2 = Reimbursement.find_by(invoice_number: 'ER14228252')
    audit_wo2 = AuditWorkOrder.create!(reimbursement: reimbursement2, creator_id: admin_user.id)
    audit_wo2.select_fee_details(reimbursement2.fee_details.pluck(:id))
    audit_wo2.problem_type = "文档不完整"
    audit_wo2.problem_description = "缺少发票照片"
    audit_wo2.remark = "请补充发票照片"
    audit_wo2.start_processing! # 触发状态变为 processing
    audit_wo2.save!

    expect(audit_wo2.reload.status).to eq('processing')
    expect(reimbursement2.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement2.reload.status).to eq('processing')

    audit_wo2.processing_opinion = "审核通过"
    audit_wo2.save! # 状态变为 approved

    expect(audit_wo2.reload.status).to eq('approved')
    expect(reimbursement2.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement2.reload.status).to eq('waiting_completion')
    puts "报销单 R2025002 标准审核通过流程验证通过。"

    # 报销单 R2025003（拒绝路径）
    reimbursement3 = Reimbursement.find_by(invoice_number: 'ER14228253')
    audit_wo3 = AuditWorkOrder.create!(reimbursement: reimbursement3, creator_id: admin_user.id)
    audit_wo3.select_fee_details(reimbursement3.fee_details.pluck(:id))
    audit_wo3.problem_type = "金额错误"
    audit_wo3.problem_description = "金额超出预算"
    audit_wo3.remark = "请调整金额后重新提交"
    audit_wo3.processing_opinion = "否决"
    audit_wo3.save! # 状态变为 rejected

    expect(audit_wo3.reload.status).to eq('rejected')
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement3.reload.status).to eq('processing') # 报销单状态仍为 processing
    puts "报销单 R2025003 审核拒绝流程验证通过。"
    puts "--- 第二阶段：审核工单处理完成 ---"

    # 第三阶段：沟通工单处理
    puts "\n--- 第三阶段：沟通工单处理 ---"
    # 报销单 R2025003（沟通后通过）
    reimbursement3 = Reimbursement.find_by(invoice_number: 'ER14228253')
    comm_wo1 = CommunicationWorkOrder.create!(reimbursement: reimbursement3, creator_id: admin_user.id)
    comm_wo1.select_fee_details(reimbursement3.fee_details.pluck(:id))
    comm_wo1.problem_type = "金额错误"
    comm_wo1.problem_description = "金额超出预算"
    comm_wo1.remark = "已与申请人沟通，金额已调整"
    comm_wo1.needs_communication = true
    comm_wo1.start_processing! # 触发状态变为 processing
    comm_wo1.save!

    expect(comm_wo1.reload.status).to eq('processing')
    expect(comm_wo1.needs_communication?).to be_truthy
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic']) # 状态仍为 problematic
    expect(reimbursement3.reload.status).to eq('processing')

    # 添加沟通记录
    comm_wo1.add_communication_record(content: "已与张伟电话沟通，确认金额调整为3000元", communicator_role: "张经理", communication_method: "电话")
    expect(comm_wo1.communication_records.count).to eq(1)

    comm_wo1.processing_opinion = "审核通过"
    comm_wo1.save! # 状态变为 approved

    expect(comm_wo1.reload.status).to eq('approved')
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified']) # 状态变为 verified
    expect(reimbursement3.reload.status).to eq('waiting_completion') # 报销单状态变为 waiting_completion
    puts "报销单 R2025003 沟通后通过流程验证通过。"

    # 报销单 R2025004（直接通过路径）
    reimbursement4 = Reimbursement.find_by(invoice_number: 'ER14228254')
    comm_wo2 = CommunicationWorkOrder.create!(reimbursement: reimbursement4, creator_id: admin_user.id)
    comm_wo2.select_fee_details(reimbursement4.fee_details.pluck(:id))
    comm_wo2.processing_opinion = "审核通过"
    comm_wo2.save! # 直接通过

    expect(comm_wo2.reload.status).to eq('approved')
    expect(reimbursement4.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement4.reload.status).to eq('waiting_completion')
    puts "报销单 R2025004 沟通工单直接通过流程验证通过。"
    puts "--- 第三阶段：沟通工单处理完成 ---"

    # 第四阶段：混合处理场景
    puts "\n--- 第四阶段：混合处理场景 ---"
    # 报销单 R2025005（费用明细分开处理）
    reimbursement5 = Reimbursement.find_by(invoice_number: 'ER14228255')
    # 查找为 R2025005 创建的两条费用明细
    fee_detail_5a = reimbursement5.fee_details.find_by(fee_type: '费用类型5A')
    fee_detail_5b = reimbursement5.fee_details.find_by(fee_type: '费用类型5B')

    audit_wo_part1 = AuditWorkOrder.create!(reimbursement: reimbursement5, creator_id: admin_user.id)
    audit_wo_part1.select_fee_details([fee_detail_5a.id])
    audit_wo_part1.processing_opinion = "审核通过"
    audit_wo_part1.save!

    expect(audit_wo_part1.reload.status).to eq('approved')
    expect(fee_detail_5a.reload.verification_status).to eq('verified')
    expect(fee_detail_5b.reload.verification_status).to eq('pending') # 另一个费用明细仍为 pending
    expect(reimbursement5.reload.status).to eq('processing') # 报销单状态仍为 processing

    audit_wo_part2 = AuditWorkOrder.create!(reimbursement: reimbursement5, creator_id: admin_user.id)
    audit_wo_part2.select_fee_details([fee_detail_5b.id])
    audit_wo_part2.processing_opinion = "审核通过"
    audit_wo_part2.save!

    expect(audit_wo_part2.reload.status).to eq('approved')
    expect(fee_detail_5a.reload.verification_status).to eq('verified')
    expect(fee_detail_5b.reload.verification_status).to eq('verified') # 所有费用明细变为 verified
    expect(reimbursement5.reload.status).to eq('waiting_completion') # 报销单状态变为 waiting_completion
    puts "报销单 R2025005 费用明细分开处理验证通过。"

    # 报销单 R2025006（审核拒绝后沟通通过）
    reimbursement6 = Reimbursement.find_by(invoice_number: 'R2025006') # This one is correct as it's in the second group
    audit_wo_reject = AuditWorkOrder.create!(reimbursement: reimbursement6, creator_id: admin_user.id)
    audit_wo_reject.select_fee_details(reimbursement6.fee_details.pluck(:id))
    audit_wo_reject.problem_type = "缺少证明"
    audit_wo_reject.problem_description = "缺少参会人员名单"
    audit_wo_reject.remark = "请提供参会人员名单"
    audit_wo_reject.processing_opinion = "否决"
    audit_wo_reject.save!

    expect(audit_wo_reject.reload.status).to eq('rejected')
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement6.reload.status).to eq('processing')

    comm_wo_approve = CommunicationWorkOrder.create!(reimbursement: reimbursement6, creator_id: admin_user.id)
    comm_wo_approve.select_fee_details(reimbursement6.fee_details.pluck(:id))
    comm_wo_approve.problem_type = "缺少证明"
    comm_wo_approve.problem_description = "缺少参会人员名单"
    comm_wo_approve.remark = "已收到参会人员名单"
    comm_wo_approve.needs_communication = true
    comm_wo_approve.start_processing! # 触发状态变为 processing
    comm_wo_approve.save!

    expect(comm_wo_approve.reload.status).to eq('processing')
    expect(comm_wo_approve.needs_communication?).to be_truthy
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement6.reload.status).to eq('processing')

    comm_wo_approve.add_communication_record(content: "已与陈明电话沟通，已收到参会人员名单", communicator_role: "张经理", communication_method: "电话")
    expect(comm_wo_approve.communication_records.count).to eq(1)

    comm_wo_approve.processing_opinion = "审核通过"
    comm_wo_approve.save! # 状态变为 approved

    expect(comm_wo_approve.reload.status).to eq('approved')
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement6.reload.status).to eq('waiting_completion')
    puts "报销单 R2025006 审核拒绝后沟通通过流程验证通过。"
    puts "--- 第四阶段：混合处理场景完成 ---"

    # 第五阶段：操作历史导入与状态更新
    puts "\n--- 第五阶段：操作历史导入与状态更新 ---"
    puts "Approval CSV path: #{operation_histories_approval_csv_path}"
    puts "File exists? #{File.exist?(operation_histories_approval_csv_path)}"
    spreadsheet = Roo::Spreadsheet.open(operation_histories_approval_csv_path, extension: :csv)
    import_result = OperationHistoryImportService.new(operation_histories_approval_csv_path, admin_user).import(spreadsheet)
    puts "Import result: #{import_result.inspect}"
    expect(OperationHistory.count).to eq(16) # 初始10条 + 新导入6条
    puts "审批操作历史导入完成，共 #{OperationHistory.count} 条。"

    (1..6).each do |i|
      if i <= 5
        reimbursement = Reimbursement.find_by(invoice_number: "ER1422825#{i}")
      else
        reimbursement = Reimbursement.find_by(invoice_number: "R2025%03d" % i)
      end
      expect(reimbursement.reload.status).to eq('closed')
    end
    (7..10).each do |i|
      if i <= 5
        reimbursement = Reimbursement.find_by(invoice_number: "ER1422825#{i}")
      else
        reimbursement = Reimbursement.find_by(invoice_number: "R2025%03d" % i)
      end
      expect(reimbursement.reload.status).not_to eq('closed') # 其他报销单状态不变
    end
    
    # 创建一个处理中状态的沟通工单，用于验证状态不受影响
    reimbursement7 = Reimbursement.find_by(invoice_number: 'R2025007') # This one is correct as it's in the second group
    comm_wo_processing = CommunicationWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    comm_wo_processing.problem_type = "其他问题"
    comm_wo_processing.problem_description = "需要确认信息"
    comm_wo_processing.remark = "请提供更多信息"
    comm_wo_processing.needs_communication = true
    comm_wo_processing.start_processing! # 触发状态变为 processing
    comm_wo_processing.save!
    expect(comm_wo_processing.reload.status).to eq('processing')
    
    # 验证工单状态不受影响
    expect(AuditWorkOrder.all.pluck(:status)).to include('approved', 'rejected')
    expect(CommunicationWorkOrder.all.pluck(:status)).to include('approved', 'processing')
    expect(ExpressReceiptWorkOrder.all.pluck(:status).uniq).to eq(['completed'])
    puts "审批操作历史导入后状态验证通过。"
    puts "--- 第五阶段：操作历史导入与状态更新完成 ---"

    # 第六阶段：电子发票标志测试
    puts "\n--- 第六阶段：电子发票标志测试 ---"
    reimbursement7 = Reimbursement.find_by(invoice_number: 'R2025007') # This one is correct as it's in the second group
    reimbursement7.update!(is_electronic: true)
    expect(reimbursement7.is_electronic?).to be_truthy
    # TODO: Add UI verification if feature specs are implemented
    puts "电子发票标志设置验证通过。"
    puts "--- 第六阶段：电子发票标志测试完成 ---"

    # 第七阶段：多工单关联同一费用明细
    puts "\n--- 第七阶段：多工单关联同一费用明细 ---"
    reimbursement7 = Reimbursement.find_by(invoice_number: 'R2025007') # This one is correct as it's in the second group
    fee_detail_computer = reimbursement7.fee_details.find_by(fee_type: '电脑')
    fee_detail_monitor = reimbursement7.fee_details.find_by(fee_type: '显示器')

    # 创建审核工单A，关联电脑费用明细，状态 processing
    audit_wo_a = AuditWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    audit_wo_a.select_fee_details([fee_detail_computer.id])
    audit_wo_a.problem_type = "金额错误"
    audit_wo_a.problem_description = "金额超出预算"
    audit_wo_a.remark = "请确认金额"
    audit_wo_a.start_processing! # 触发状态变为 processing
    audit_wo_a.save!

    expect(audit_wo_a.reload.status).to eq('processing')
    expect(fee_detail_computer.reload.verification_status).to eq('problematic')

    # 创建沟通工单B，关联电脑费用明细，状态 approved
    comm_wo_b = CommunicationWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    comm_wo_b.select_fee_details([fee_detail_computer.id])
    comm_wo_b.problem_type = "金额错误"
    comm_wo_b.problem_description = "金额超出预算"
    comm_wo_b.remark = "已与申请人沟通确认金额正确"
    comm_wo_b.processing_opinion = "审核通过"
    comm_wo_b.save! # 状态变为 approved

    expect(comm_wo_b.reload.status).to eq('approved')
    # 费用明细状态应跟随最新处理的工单 B 变为 verified
    expect(fee_detail_computer.reload.verification_status).to eq('verified')

    # 创建审核工单C，关联显示器费用明细，状态 approved
    audit_wo_c = AuditWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    audit_wo_c.select_fee_details([fee_detail_monitor.id])
    audit_wo_c.processing_opinion = "审核通过"
    audit_wo_c.save!

    expect(audit_wo_c.reload.status).to eq('approved')
    expect(fee_detail_monitor.reload.verification_status).to eq('verified')

    # 验证报销单状态变为 waiting_completion
    expect(reimbursement7.reload.status).to eq('waiting_completion')
    puts "报销单 R2025007 多工单关联同一费用明细验证通过。"
    puts "--- 第七阶段：多工单关联同一费用明细完成 ---"

    puts "\n--- 集成测试完成 ---"
  end

  def create_test_csv_files
    puts "创建测试 CSV 文件..."
    # 创建 test_reimbursements.csv
    CSV.open(reimbursements_csv_path, "w") do |csv|
      csv << ["报销单单号", "单据名称", "报销单申请人", "报销单申请人工号", "申请人公司", "申请人部门", "收单状态", "收单日期", "提交报销日期", "报销金额（单据币种）", "报销单状态"]
      # First 5 records use ER14228251-ER14228255 format
      (1..5).each do |i|
        csv << ["ER1422825#{i}", "报销单#{i}", "申请人#{i}", "E%03d" % i, "科技有限公司", "部门#{i}", "pending", "", "2025-04-%02d" % i, (100 + i * 50).round(2), "待审批"]
      end
      # Remaining records use R2025006-R2025010 format
      (6..10).each do |i|
        csv << ["R2025%03d" % i, "报销单#{i}", "申请人#{i}", "E%03d" % i, "科技有限公司", "部门#{i}", "pending", "", "2025-04-%02d" % i, (100 + i * 50).round(2), "待审批"]
      end
      puts "创建 #{reimbursements_csv_path} 完成，文件是否存在：#{File.exist?(reimbursements_csv_path)}"
      puts "文件内容（前5行）："
      File.readlines(reimbursements_csv_path).first(5).each { |line| puts line }
    end
    puts "创建 #{reimbursements_csv_path} 完成，文件是否存在：#{File.exist?(reimbursements_csv_path)}"
    puts "文件内容（前5行）："
    File.readlines(reimbursements_csv_path).first(5).each { |line| puts line }

    # 创建 test_express_receipts.csv
    CSV.open(express_receipts_csv_path, "w") do |csv|
      csv << ["单据编号", "操作类型", "操作日期", "操作人", "操作意见"]
      # First 5 records use ER14228251-ER14228255 format
      (1..5).each do |i|
        csv << ["ER1422825#{i}", "收单", "2025-04-%02d" % (i + 10), "张经理", "快递单号：SF100#{i}"]
      end
      # Remaining records use R2025006-R2025010 format
      (6..10).each do |i|
        csv << ["R2025%03d" % i, "收单", "2025-04-%02d" % (i + 10), "张经理", "快递单号：SF%010d" % i]
      end
    end
    puts "创建 #{express_receipts_csv_path} 完成，文件是否存在：#{File.exist?(express_receipts_csv_path)}"
    puts "文件内容（前5行）："
    File.readlines(express_receipts_csv_path).first(5).each { |line| puts line }

    # 创建 test_fee_details.csv
    # 创建 test_fee_details.csv (根据映射文档，前4条各1条，第5条2条)
    CSV.open(fee_details_csv_path, "w") do |csv|
      csv << ["报销单单号", "费用类型", "原始金额", "原始币种", "费用发生日期", "弹性字段11"]
      # First 4 records use ER14228251-ER14228254 format
      (1..4).each do |i|
        csv << ["ER1422825#{i}", "费用类型#{i}", (100 + i * 10).round(2), "CNY", "2025-04-%02d" % i, "支付方式A"]
      end
      # 为 ER14228255 创建两条费用明细
      csv << ["ER14228255", "费用类型5A", 150.00, "CNY", "2025-04-05", "支付方式A"]
      csv << ["ER14228255", "费用类型5B", 200.00, "CNY", "2025-04-05", "支付方式B"]
      # 为 R2025006 创建一条费用明细
      csv << ["R2025006", "费用类型6", 180.00, "CNY", "2025-04-06", "支付方式A"]
      # 为 R2025007 创建两条费用明细（电脑和显示器）
      csv << ["R2025007", "电脑", 5000.00, "CNY", "2025-04-07", "支付方式A"]
      csv << ["R2025007", "显示器", 2000.00, "CNY", "2025-04-07", "支付方式B"]
    end
    puts "创建 #{fee_details_csv_path} 完成，文件是否存在：#{File.exist?(fee_details_csv_path)}"
    puts "文件内容（前5行）："
    File.readlines(fee_details_csv_path).first(5).each { |line| puts line }

    # 创建 test_operation_histories.csv
    CSV.open(operation_histories_csv_path, "w") do |csv|
      csv << ["单据编号", "操作类型", "操作日期", "操作人", "操作意见"]
      # First 5 records use ER14228251-ER14228255 format
      (1..5).each do |i|
        csv << ["ER1422825#{i}", "提交", "2025-04-%02d" % i, "申请人#{i}", "请审批"]
      end
      # Remaining records use R2025006-R2025010 format
      (6..10).each do |i|
        csv << ["R2025%03d" % i, "提交", "2025-04-%02d" % i, "申请人#{i}", "请审批"]
      end
    end
    puts "创建 #{operation_histories_csv_path} 完成，文件是否存在：#{File.exist?(operation_histories_csv_path)}"
    puts "文件内容（前5行）："
    File.readlines(operation_histories_csv_path).first(5).each { |line| puts line }

    # 创建 test_operation_histories_approval.csv
    CSV.open(operation_histories_approval_csv_path, "w") do |csv|
      csv << ["单据编号", "操作类型", "操作日期", "操作人", "操作意见"]
      # First 5 records use ER14228251-ER14228255 format
      (1..5).each do |i|
        csv << ["ER1422825#{i}", "审批", "2025-04-%02d" % (i + 20), "李总", "审批通过"]
      end
      # Plus R2025006
      csv << ["R2025006", "审批", "2025-04-26", "李总", "审批通过"]
    end
    puts "创建 #{operation_histories_approval_csv_path} 完成，文件是否存在：#{File.exist?(operation_histories_approval_csv_path)}"
    puts "文件内容（前5行）："
    File.readlines(operation_histories_approval_csv_path).first(5).each { |line| puts line }
  end


  def import_data
    # 导入报销单
    ReimbursementImportService.new(reimbursements_csv_path, admin_user).import
    expect(Reimbursement.count).to eq(10)
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['pending'])

    # 导入快递收单
    ExpressReceiptImportService.new(express_receipts_csv_path, admin_user).import
    expect(ExpressReceiptWorkOrder.count).to eq(10)
    expect(ExpressReceiptWorkOrder.all.pluck(:status).uniq).to eq(['completed'])
    # 验证报销单状态未变
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['pending'])

    # 导入费用明细
    FeeDetailImportService.new(File.open(fee_details_csv_path), admin_user).import
    expect(FeeDetail.count).to eq(19) # 根据CSV数据计算
    expect(FeeDetail.all.pluck(:verification_status).uniq).to eq(['pending'])

    # 导入操作历史
    OperationHistoryImportService.new(File.open(operation_histories_csv_path), admin_user).import
    expect(OperationHistory.count).to eq(10)
    # 验证报销单状态未因提交操作历史改变
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['pending'])
  end

  def verify_initial_import_status
    puts "验证初始导入状态..."
    expect(Reimbursement.count).to eq(10)
    expect(Reimbursement.all.pluck(:status).uniq).to eq(['pending'])
    expect(ExpressReceiptWorkOrder.count).to eq(10)
    expect(ExpressReceiptWorkOrder.all.pluck(:status).uniq).to eq(['completed'])
    expect(FeeDetail.count).to eq(19)
    expect(FeeDetail.all.pluck(:verification_status).uniq).to eq(['pending'])
    expect(OperationHistory.count).to eq(10)
    puts "初始导入状态验证通过。"
  end

  def process_audit_work_orders
    puts "处理审核工单..."
    # 报销单 R2025001（直接通过路径）
    reimbursement1 = Reimbursement.find_by(invoice_number: 'ER14228251')
    audit_wo1 = AuditWorkOrder.create!(reimbursement: reimbursement1, creator_id: admin_user.id)
    audit_wo1.select_fee_details(reimbursement1.fee_details.pluck(:id))
    audit_wo1.processing_opinion = "审核通过"
    audit_wo1.save! # 直接通过

    expect(audit_wo1.reload.status).to eq('approved')
    expect(reimbursement1.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement1.reload.status).to eq('waiting_completion')
    puts "报销单 R2025001 审核通过流程验证通过。"

    # 报销单 R2025002（标准通过路径）
    reimbursement2 = Reimbursement.find_by(invoice_number: 'ER14228252')
    audit_wo2 = AuditWorkOrder.create!(reimbursement: reimbursement2, creator_id: admin_user.id)
    audit_wo2.select_fee_details(reimbursement2.fee_details.pluck(:id))
    audit_wo2.problem_type = "文档不完整"
    audit_wo2.problem_description = "缺少发票照片"
    audit_wo2.remark = "请补充发票照片"
    audit_wo2.save! # 状态变为 processing

    expect(audit_wo2.reload.status).to eq('processing')
    expect(reimbursement2.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement2.reload.status).to eq('processing')

    audit_wo2.processing_opinion = "审核通过"
    audit_wo2.save! # 状态变为 approved

    expect(audit_wo2.reload.status).to eq('approved')
    expect(reimbursement2.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement2.reload.status).to eq('waiting_completion')
    puts "报销单 R2025002 标准审核通过流程验证通过。"

    # 报销单 R2025003（拒绝路径）
    reimbursement3 = Reimbursement.find_by(invoice_number: 'ER14228253')
    audit_wo3 = AuditWorkOrder.create!(reimbursement: reimbursement3, creator_id: admin_user.id)
    audit_wo3.select_fee_details(reimbursement3.fee_details.pluck(:id))
    audit_wo3.problem_type = "金额错误"
    audit_wo3.problem_description = "金额超出预算"
    audit_wo3.remark = "请调整金额后重新提交"
    audit_wo3.processing_opinion = "否决"
    audit_wo3.save! # 状态变为 rejected

    expect(audit_wo3.reload.status).to eq('rejected')
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement3.reload.status).to eq('processing') # 报销单状态仍为 processing
    puts "报销单 R2025003 审核拒绝流程验证通过。"
  end

  def process_communication_work_orders
    puts "处理沟通工单..."
    # 报销单 R2025003（沟通后通过）
    reimbursement3 = Reimbursement.find_by(invoice_number: 'R2025003')
    comm_wo1 = CommunicationWorkOrder.create!(reimbursement: reimbursement3, creator_id: admin_user.id)
    comm_wo1.select_fee_details(reimbursement3.fee_details.pluck(:id))
    comm_wo1.problem_type = "金额错误"
    comm_wo1.problem_description = "金额超出预算"
    comm_wo1.remark = "已与申请人沟通，金额已调整"
    comm_wo1.needs_communication = true
    comm_wo1.save! # 状态变为 processing

    expect(comm_wo1.reload.status).to eq('processing')
    expect(comm_wo1.needs_communication?).to be_truthy
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic']) # 状态仍为 problematic
    expect(reimbursement3.reload.status).to eq('processing')

    # 添加沟通记录
    comm_wo1.add_communication_record(content: "已与张伟电话沟通，确认金额调整为3000元", communicator_role: "张经理", communication_method: "电话")
    expect(comm_wo1.communication_records.count).to eq(1)

    comm_wo1.processing_opinion = "审核通过"
    comm_wo1.save! # 状态变为 approved

    expect(comm_wo1.reload.status).to eq('approved')
    expect(reimbursement3.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified']) # 状态变为 verified
    expect(reimbursement3.reload.status).to eq('waiting_completion') # 报销单状态变为 waiting_completion
    puts "报销单 R2025003 沟通后通过流程验证通过。"

    # 报销单 R2025004（直接通过路径）
    reimbursement4 = Reimbursement.find_by(invoice_number: 'R2025004')
    comm_wo2 = CommunicationWorkOrder.create!(reimbursement: reimbursement4, creator_id: admin_user.id)
    comm_wo2.select_fee_details(reimbursement4.fee_details.pluck(:id))
    comm_wo2.processing_opinion = "审核通过"
    comm_wo2.save! # 直接通过

    expect(comm_wo2.reload.status).to eq('approved')
    expect(reimbursement4.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement4.reload.status).to eq('waiting_completion')
    puts "报销单 R2025004 沟通工单直接通过流程验证通过。"
  end

  def process_mixed_scenarios
    puts "处理混合场景..."
    # 报销单 R2025005（费用明细分开处理）
    reimbursement5 = Reimbursement.find_by(invoice_number: 'R2025005')
    fee_detail_5a = reimbursement5.fee_details.find_by(fee_type: '出租车')
    fee_detail_5b = reimbursement5.fee_details.find_by(fee_type: '地铁')

    audit_wo_part1 = AuditWorkOrder.create!(reimbursement: reimbursement5, created_by: admin_user.id)
    audit_wo_part1.select_fee_details([fee_detail_5a.id])
    audit_wo_part1.processing_opinion = "审核通过"
    audit_wo_part1.save!

    expect(audit_wo_part1.reload.status).to eq('approved')
    expect(fee_detail_5a.reload.verification_status).to eq('verified')
    expect(fee_detail_5b.reload.verification_status).to eq('pending') # 另一个费用明细仍为 pending
    expect(reimbursement5.reload.status).to eq('processing') # 报销单状态仍为 processing

    audit_wo_part2 = AuditWorkOrder.create!(reimbursement: reimbursement5, created_by: admin_user.id)
    audit_wo_part2.select_fee_details([fee_detail_5b.id])
    audit_wo_part2.processing_opinion = "审核通过"
    audit_wo_part2.save!

    expect(audit_wo_part2.reload.status).to eq('approved')
    expect(fee_detail_5a.reload.verification_status).to eq('verified')
    expect(fee_detail_5b.reload.verification_status).to eq('verified') # 所有费用明细变为 verified
    expect(reimbursement5.reload.status).to eq('waiting_completion') # 报销单状态变为 waiting_completion
    puts "报销单 R2025005 费用明细分开处理验证通过。"

    # 报销单 R2025006（审核拒绝后沟通通过）
    reimbursement6 = Reimbursement.find_by(invoice_number: 'R2025006')
    audit_wo_reject = AuditWorkOrder.create!(reimbursement: reimbursement6, created_by: admin_user.id)
    audit_wo_reject.select_fee_details(reimbursement6.fee_details.pluck(:id))
    audit_wo_reject.problem_type = "缺少证明"
    audit_wo_reject.problem_description = "缺少参会人员名单"
    audit_wo_reject.remark = "请提供参会人员名单"
    audit_wo_reject.processing_opinion = "否决"
    audit_wo_reject.save!

    expect(audit_wo_reject.reload.status).to eq('rejected')
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement6.reload.status).to eq('processing')

    comm_wo_approve = CommunicationWorkOrder.create!(reimbursement: reimbursement6, created_by: admin_user.id)
    comm_wo_approve.select_fee_details(reimbursement6.fee_details.pluck(:id))
    comm_wo_approve.problem_type = "缺少证明"
    comm_wo_approve.problem_description = "缺少参会人员名单"
    comm_wo_approve.remark = "已收到参会人员名单"
    comm_wo_approve.needs_communication = true
    comm_wo_approve.save! # 状态变为 processing

    expect(comm_wo_approve.reload.status).to eq('processing')
    expect(comm_wo_approve.needs_communication?).to be_truthy
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['problematic'])
    expect(reimbursement6.reload.status).to eq('processing')

    comm_wo_approve.add_communication_record(content: "已与陈明电话沟通，已收到参会人员名单", communicator_role: "张经理", communication_method: "电话")
    expect(comm_wo_approve.communication_records.count).to eq(1)

    comm_wo_approve.processing_opinion = "审核通过"
    comm_wo_approve.save! # 状态变为 approved

    expect(comm_wo_approve.reload.status).to eq('approved')
    expect(reimbursement6.fee_details.reload.pluck(:verification_status).uniq).to eq(['verified'])
    expect(reimbursement6.reload.status).to eq('waiting_completion')
    puts "报销单 R2025006 审核拒绝后沟通通过流程验证通过。"
  end

  def import_approval_history
    puts "导入审批操作历史..."
    OperationHistoryImportService.new(operation_histories_approval_csv_path, admin_user).import
    expect(OperationHistory.count).to eq(16) # 初始10条 + 新导入6条
    puts "审批操作历史导入完成。"
  end

  def verify_status_after_approval_history
    puts "验证审批操作历史导入后的状态..."
    (1..6).each do |i|
      reimbursement = Reimbursement.find_by(invoice_number: "R2025%03d" % i)
      expect(reimbursement.reload.status).to eq('closed')
    end
    (7..10).each do |i|
      reimbursement = Reimbursement.find_by(invoice_number: "R2025%03d" % i)
      expect(reimbursement.reload.status).not_to eq('closed') # 其他报销单状态不变
    end
    # 验证工单状态不受影响
    expect(AuditWorkOrder.all.pluck(:status)).to include('approved', 'rejected')
    expect(CommunicationWorkOrder.all.pluck(:status)).to include('approved', 'processing')
    expect(ExpressReceiptWorkOrder.all.pluck(:status).uniq).to eq(['completed'])
    puts "审批操作历史导入后状态验证通过。"
  end

  def test_electronic_invoice_flag
    puts "测试电子发票标志..."
    reimbursement7 = Reimbursement.find_by(invoice_number: 'R2025007')
    reimbursement7.update!(is_electronic: true)
    expect(reimbursement7.is_electronic?).to be_truthy
    # TODO: Add UI verification if feature specs are implemented
    puts "电子发票标志设置验证通过。"
  end

  def test_multiple_work_orders_on_fee_detail
    puts "测试多工单关联同一费用明细..."
    reimbursement7 = Reimbursement.find_by(invoice_number: 'R2025007')
    fee_detail_computer = reimbursement7.fee_details.find_by(fee_type: '电脑')
    fee_detail_monitor = reimbursement7.fee_details.find_by(fee_type: '显示器')

    # 创建审核工单A，关联电脑费用明细，状态 processing
    audit_wo_a = AuditWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    audit_wo_a.select_fee_details([fee_detail_computer.id])
    audit_wo_a.problem_type = "金额错误"
    audit_wo_a.problem_description = "金额超出预算"
    audit_wo_a.remark = "请确认金额"
    audit_wo_a.save! # 状态变为 processing

    expect(audit_wo_a.reload.status).to eq('processing')
    expect(fee_detail_computer.reload.verification_status).to eq('problematic')

    # 创建沟通工单B，关联电脑费用明细，状态 approved
    comm_wo_b = CommunicationWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    comm_wo_b.select_fee_details([fee_detail_computer.id])
    comm_wo_b.problem_type = "金额错误"
    comm_wo_b.problem_description = "金额超出预算"
    comm_wo_b.remark = "已与申请人沟通确认金额正确"
    comm_wo_b.processing_opinion = "审核通过"
    comm_wo_b.save! # 状态变为 approved

    expect(comm_wo_b.reload.status).to eq('approved')
    # 费用明细状态应跟随最新处理的工单 B 变为 verified
    expect(fee_detail_computer.reload.verification_status).to eq('verified')

    # 创建审核工单C，关联显示器费用明细，状态 approved
    audit_wo_c = AuditWorkOrder.create!(reimbursement: reimbursement7, creator_id: admin_user.id)
    audit_wo_c.select_fee_details([fee_detail_monitor.id])
    audit_wo_c.processing_opinion = "审核通过"
    audit_wo_c.save!

    expect(audit_wo_c.reload.status).to eq('approved')
    expect(fee_detail_monitor.reload.verification_status).to eq('verified')

    # 验证报销单状态变为 waiting_completion
    expect(reimbursement7.reload.status).to eq('waiting_completion')
    puts "报销单 R2025007 多工单关联同一费用明细验证通过。"
  end
end