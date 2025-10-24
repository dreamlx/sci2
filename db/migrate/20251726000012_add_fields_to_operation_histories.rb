class AddFieldsToOperationHistories < ActiveRecord::Migration[7.1]
  def change
    # 添加申请人相关字段
    add_column :operation_histories, :applicant, :string, comment: '申请人'
    add_column :operation_histories, :employee_id, :string, comment: '员工工号'
    add_column :operation_histories, :employee_company, :string, comment: '员工公司'
    add_column :operation_histories, :employee_department, :string, comment: '员工部门'
    add_column :operation_histories, :employee_department_path, :text, comment: '员工部门路径'

    # 添加单据相关字段
    add_column :operation_histories, :document_company, :string, comment: '员工单据公司'
    add_column :operation_histories, :document_department, :string, comment: '员工单据部门'
    add_column :operation_histories, :document_department_path, :text, comment: '员工单据部门路径'
    add_column :operation_histories, :submitter, :string, comment: '提交人'
    add_column :operation_histories, :document_name, :string, comment: '单据名称'

    # 添加金额相关字段
    add_column :operation_histories, :currency, :string, comment: '币种'
    add_column :operation_histories, :amount, :decimal, precision: 10, scale: 2, comment: '金额'

    # 添加时间字段
    add_column :operation_histories, :created_date, :datetime, comment: '创建日期'

    # 添加索引以提升查询性能
    add_index :operation_histories, :applicant
    add_index :operation_histories, :employee_id
    add_index :operation_histories, :employee_company
    add_index :operation_histories, :employee_department
    add_index :operation_histories, :submitter
    add_index :operation_histories, :currency
    add_index :operation_histories, :created_date
  end
end
