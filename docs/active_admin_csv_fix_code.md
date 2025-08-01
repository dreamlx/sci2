# ActiveAdmin CSV导出功能增强方案

## 问题描述
当前工单(快递收单、沟通工单、审核工单)的CSV导出功能中，无法显示关联费用明细的document_number字段。

## 解决方案
为每种工单类型添加自定义CSV导出功能，包含关联费用明细的document_number字段。

### 修改文件
1. `app/admin/express_receipt_work_orders.rb`
2. `app/admin/communication_work_orders.rb` 
3. `app/admin/audit_work_orders.rb`

### 实现步骤
1. 添加`collection_action :export_csv`方法
2. 在导出中包含关联费用明细的document_number
3. 在index页面添加导出按钮

### 代码示例
```ruby
collection_action :export_csv, method: :get do
  work_orders = ExpressReceiptWorkOrder.includes(reimbursement: :fee_details)
  
  csv_data = CSV.generate(headers: true) do |csv|
    csv << ["ID", "报销单号", "快递单号", "快递公司", "收单日期", "状态", "创建人", "创建时间", "费用明细单号"]
    
    work_orders.find_each do |wo|
      document_numbers = wo.reimbursement&.fee_details&.pluck(:document_number)&.uniq&.join(", ") || ""
      csv << [
        wo.id,
        wo.reimbursement&.invoice_number,
        wo.tracking_number,
        wo.courier_name,
        wo.received_at,
        wo.status,
        wo.creator&.email,
        wo.created_at,
        document_numbers
      ]
    end
  end
  
  send_data csv_data, 
            type: 'text/csv; charset=utf-8; header=present',
            disposition: "attachment; filename=快递收单工单_#{Time.current.strftime('%Y%m%d')}.csv"
end
```

## 测试计划
1. 导出快递收单工单CSV，确认包含document_number
2. 检查关联多个费用明细时的显示格式
3. 验证其他工单类型的导出功能