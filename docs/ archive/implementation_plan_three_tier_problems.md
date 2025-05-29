# 三级问题代码库实施计划

## 概述

本计划详细描述如何将当前的两级问题代码库升级为三级级联结构，以支持用户故事中描述的完整业务逻辑。

## 实施阶段

### 阶段1：数据库结构创建 (1-2天)

#### 1.1 创建新的三级问题代码库表

```ruby
# db/migrate/20250528_create_three_tier_problem_structure.rb
class CreateThreeTierProblemStructure < ActiveRecord::Migration[7.1]
  def change
    # 第一级：会议类型/文档类别
    create_table :problem_meeting_types do |t|
      t.string :code, null: false, limit: 10
      t.string :title, null: false, limit: 100
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :problem_meeting_types, :code, unique: true
    add_index :problem_meeting_types, :active

    # 第二级：问题大类
    create_table :problem_major_categories do |t|
      t.string :code, null: false, limit: 10
      t.string :title, null: false, limit: 100
      t.references :meeting_type, null: false, foreign_key: { to_table: :problem_meeting_types }
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :problem_major_categories, [:code, :meeting_type_id], unique: true
    add_index :problem_major_categories, :meeting_type_id
    add_index :problem_major_categories, :active

    # 第三级：具体问题类型
    create_table :problem_specific_types do |t|
      t.string :code, null: false, limit: 10
      t.string :title, null: false, limit: 100
      t.text :sop_description
      t.text :standard_handling
      t.references :major_category, null: false, foreign_key: { to_table: :problem_major_categories }
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :problem_specific_types, [:code, :major_category_id], unique: true
    add_index :problem_specific_types, :major_category_id
    add_index :problem_specific_types, :active
  end
end
```

#### 1.2 更新工单表以支持三级问题选择

```ruby
# db/migrate/20250528_add_three_tier_problem_fields_to_work_orders.rb
class AddThreeTierProblemFieldsToWorkOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :work_orders, :problem_meeting_type, foreign_key: { to_table: :problem_meeting_types }, null: true
    add_reference :work_orders, :problem_major_category, foreign_key: { to_table: :problem_major_categories }, null: true
    add_reference :work_orders, :problem_specific_type, foreign_key: { to_table: :problem_specific_types }, null: true
    add_column :work_orders, :custom_description, :text
    
    # 添加索引以提高查询性能
    add_index :work_orders, :problem_meeting_type_id
    add_index :work_orders, :problem_major_category_id
    add_index :work_orders, :problem_specific_type_id
  end
end
```

### 阶段2：模型创建和关联 (1天)

#### 2.1 创建新的模型类

```ruby
# app/models/problem_meeting_type.rb
class ProblemMeetingType < ApplicationRecord
  has_many :problem_major_categories, foreign_key: 'meeting_type_id', dependent: :destroy
  has_many :work_orders, foreign_key: 'problem_meeting_type_id', dependent: :nullify
  
  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :title, presence: true, length: { maximum: 100 }
  
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:code) }
  
  def display_name
    "#{code} - #{title}"
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title active created_at updated_at]
  end
end
```

```ruby
# app/models/problem_major_category.rb
class ProblemMajorCategory < ApplicationRecord
  belongs_to :meeting_type, class_name: 'ProblemMeetingType', foreign_key: 'meeting_type_id'
  has_many :problem_specific_types, foreign_key: 'major_category_id', dependent: :destroy
  has_many :work_orders, foreign_key: 'problem_major_category_id', dependent: :nullify
  
  validates :code, presence: true, length: { maximum: 10 }
  validates :title, presence: true, length: { maximum: 100 }
  validates :code, uniqueness: { scope: :meeting_type_id }
  
  scope :active, -> { where(active: true) }
  scope :for_meeting_type, ->(meeting_type_id) { where(meeting_type_id: meeting_type_id) }
  scope :ordered, -> { order(:code) }
  
  def display_name
    "#{code} - #{title}"
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title meeting_type_id active created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[meeting_type problem_specific_types work_orders]
  end
end
```

```ruby
# app/models/problem_specific_type.rb
class ProblemSpecificType < ApplicationRecord
  belongs_to :major_category, class_name: 'ProblemMajorCategory', foreign_key: 'major_category_id'
  has_many :work_orders, foreign_key: 'problem_specific_type_id', dependent: :nullify
  
  validates :code, presence: true, length: { maximum: 10 }
  validates :title, presence: true, length: { maximum: 100 }
  validates :code, uniqueness: { scope: :major_category_id }
  
  scope :active, -> { where(active: true) }
  scope :for_major_category, ->(major_category_id) { where(major_category_id: major_category_id) }
  scope :ordered, -> { order(:code) }
  
  def display_name
    "#{code} - #{title}"
  end
  
  def meeting_type
    major_category&.meeting_type
  end
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id code title sop_description standard_handling major_category_id active created_at updated_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[major_category work_orders]
  end
end
```

#### 2.2 更新工单模型

```ruby
# 在 app/models/work_order.rb 中添加
class WorkOrder < ApplicationRecord
  # 现有关联...
  
  # 新增三级问题选择关联
  belongs_to :problem_meeting_type, optional: true
  belongs_to :problem_major_category, optional: true
  belongs_to :problem_specific_type, optional: true
  
  # 验证三级选择的完整性
  validates :problem_major_category_id, presence: true, 
    if: :problem_specific_type_id?
  validates :problem_meeting_type_id, presence: true, 
    if: :problem_major_category_id?
    
  # 验证层级关系的正确性
  validate :validate_problem_hierarchy, if: :has_problem_selection?
  
  # 当处理意见为"无法通过"时，必须选择问题
  validates :problem_specific_type_id, presence: true, 
    if: -> { processing_opinion == '无法通过' }
  
  private
  
  def has_problem_selection?
    problem_meeting_type_id.present? || 
    problem_major_category_id.present? || 
    problem_specific_type_id.present?
  end
  
  def validate_problem_hierarchy
    if problem_major_category_id.present? && problem_meeting_type_id.present?
      unless problem_major_category&.meeting_type_id == problem_meeting_type_id
        errors.add(:problem_major_category_id, "必须属于所选的会议类型")
      end
    end
    
    if problem_specific_type_id.present? && problem_major_category_id.present?
      unless problem_specific_type&.major_category_id == problem_major_category_id
        errors.add(:problem_specific_type_id, "必须属于所选的问题大类")
      end
    end
  end
end
```

### 阶段3：数据迁移 (2-3天)

#### 3.1 分析现有数据结构

```ruby
# lib/tasks/analyze_existing_problem_data.rake
namespace :problem_data do
  desc "分析现有问题类型和描述数据"
  task analyze: :environment do
    puts "=== 现有问题类型分析 ==="
    ProblemType.includes(:problem_descriptions, :document_category).each do |pt|
      puts "问题类型: #{pt.name}"
      puts "  文档类别: #{pt.document_category&.name}"
      puts "  问题描述数量: #{pt.problem_descriptions.count}"
      pt.problem_descriptions.limit(3).each do |pd|
        puts "    - #{pd.description}"
      end
      puts ""
    end
  end
end
```

#### 3.2 创建数据迁移脚本

```ruby
# lib/tasks/migrate_to_three_tier_problems.rake
namespace :problem_data do
  desc "将现有两级问题数据迁移到三级结构"
  task migrate_to_three_tier: :environment do
    ActiveRecord::Base.transaction do
      # 1. 创建默认会议类型
      personal_meeting_type = ProblemMeetingType.find_or_create_by!(
        code: '00',
        title: '个人',
        active: true
      )
      
      academic_meeting_type = ProblemMeetingType.find_or_create_by!(
        code: '03',
        title: '学术论坛',
        active: true
      )
      
      # 2. 迁移现有问题类型到问题大类
      ProblemType.includes(:problem_descriptions, :document_category).find_each do |problem_type|
        # 根据文档类别确定会议类型
        meeting_type = if problem_type.document_category&.name&.include?('个人')
                        personal_meeting_type
                      else
                        academic_meeting_type
                      end
        
        # 创建问题大类
        major_category = ProblemMajorCategory.find_or_create_by!(
          code: format('%02d', problem_type.id),
          title: problem_type.name,
          meeting_type: meeting_type,
          active: problem_type.active
        )
        
        # 3. 迁移问题描述到具体问题类型
        problem_type.problem_descriptions.find_each.with_index do |description, index|
          ProblemSpecificType.find_or_create_by!(
            code: format('%02d', index + 1),
            title: description.description,
            sop_description: "从旧系统迁移：#{description.description}",
            standard_handling: "待补充标准处理方法",
            major_category: major_category,
            active: description.active
          )
        end
      end
      
      puts "数据迁移完成！"
      puts "会议类型: #{ProblemMeetingType.count}"
      puts "问题大类: #{ProblemMajorCategory.count}"
      puts "具体问题类型: #{ProblemSpecificType.count}"
    end
  end
end
```

#### 3.3 从CSV文件导入标准问题代码

```ruby
# lib/tasks/import_standard_problem_codes.rake
namespace :problem_data do
  desc "从CSV文件导入标准问题代码"
  task import_from_csv: :environment do
    require 'csv'
    
    # 导入个人问题代码
    personal_csv_path = Rails.root.join('docs/user_data/个人问题code.csv')
    if File.exist?(personal_csv_path)
      import_personal_problems(personal_csv_path)
    end
    
    # 导入学术问题代码
    academic_csv_path = Rails.root.join('docs/user_data/学术问题code.csv')
    if File.exist?(academic_csv_path)
      import_academic_problems(academic_csv_path)
    end
  end
  
  private
  
  def import_personal_problems(csv_path)
    personal_meeting_type = ProblemMeetingType.find_or_create_by!(
      code: '00', title: '个人'
    )
    
    CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
      # 根据CSV结构调整字段映射
      major_category = ProblemMajorCategory.find_or_create_by!(
        code: row['Exp. Code'],
        title: row['费用类型'],
        meeting_type: personal_meeting_type
      )
      
      ProblemSpecificType.find_or_create_by!(
        code: row['Issue Code'],
        title: row['问题类型'],
        sop_description: row['SOP描述'],
        standard_handling: row['标准处理方法'],
        major_category: major_category
      )
    end
  end
  
  def import_academic_problems(csv_path)
    CSV.foreach(csv_path, headers: true, encoding: 'UTF-8') do |row|
      # 创建或查找会议类型
      meeting_type = ProblemMeetingType.find_or_create_by!(
        code: row['Meeting Code'],
        title: row['会议类型']
      )
      
      # 创建或查找问题大类
      major_category = ProblemMajorCategory.find_or_create_by!(
        code: row['Issue Code'],
        title: row['问题大类'],
        meeting_type: meeting_type
      )
      
      # 创建具体问题类型
      ProblemSpecificType.find_or_create_by!(
        code: row['Sub Issue Code'] || row['Issue Code'],
        title: row['问题类型'],
        sop_description: row['SOP描述'],
        standard_handling: row['标准处理方法'],
        major_category: major_category
      )
    end
  end
end
```

### 阶段4：ActiveAdmin界面更新 (2-3天)

#### 4.1 创建三级问题代码库管理界面

```ruby
# app/admin/problem_meeting_types.rb
ActiveAdmin.register ProblemMeetingType do
  menu parent: "问题代码库管理", priority: 1
  
  permit_params :code, :title, :active
  
  index do
    selectable_column
    id_column
    column :code
    column :title
    column :active
    column "问题大类数量" do |meeting_type|
      meeting_type.problem_major_categories.count
    end
    column :created_at
    actions
  end
  
  form do |f|
    f.inputs do
      f.input :code, hint: "唯一标识码，如：00, 03"
      f.input :title, hint: "显示名称，如：个人, 学术论坛"
      f.input :active
    end
    f.actions
  end
  
  show do
    attributes_table do
      row :id
      row :code
      row :title
      row :active
      row :created_at
      row :updated_at
    end
    
    panel "关联的问题大类" do
      table_for resource.problem_major_categories.ordered do
        column :code
        column :title
        column :active
        column "具体问题数量" do |category|
          category.problem_specific_types.count
        end
      end
    end
  end
end
```

#### 4.2 更新工单表单以支持三级选择

```ruby
# app/admin/audit_work_orders.rb 中的表单部分
form do |f|
  f.inputs "基本信息" do
    f.input :reimbursement, as: :select, collection: Reimbursement.all.map { |r| [r.invoice_number, r.id] }
    f.input :status, as: :select, collection: WorkOrder.state_machine.states.map(&:name)
    f.input :processing_opinion, as: :select, collection: ['可以通过', '无法通过', '待处理']
  end
  
  f.inputs "费用明细选择" do
    if f.object.reimbursement.present?
      f.input :submitted_fee_detail_ids, as: :check_boxes, 
              collection: f.object.reimbursement.fee_details.map { |fd| [fd.summary_for_selection, fd.id] },
              hint: "选择此工单要处理的费用明细"
    end
  end
  
  f.inputs "问题选择（三级联动）" do
    f.input :problem_meeting_type, as: :select,
            collection: ProblemMeetingType.active.ordered.map { |mt| [mt.display_name, mt.id] },
            include_blank: "请选择会议类型",
            input_html: { 
              id: 'work_order_problem_meeting_type_id',
              data: { 
                url: admin_ajax_major_categories_path,
                target: '#work_order_problem_major_category_id'
              }
            }
    
    f.input :problem_major_category, as: :select,
            collection: [],
            include_blank: "请先选择会议类型",
            input_html: { 
              id: 'work_order_problem_major_category_id',
              data: {
                url: admin_ajax_specific_types_path,
                target: '#work_order_problem_specific_type_id'
              }
            }
    
    f.input :problem_specific_type, as: :select,
            collection: [],
            include_blank: "请先选择问题大类",
            input_html: { id: 'work_order_problem_specific_type_id' }
    
    f.input :custom_description, as: :text,
            hint: "如果预定义问题类型不够准确，请在此详细描述"
  end
  
  f.inputs "其他信息" do
    f.input :remark, as: :text
    f.input :audit_comment, as: :text
  end
  
  f.actions
end
```

#### 4.3 添加AJAX支持的级联下拉

```ruby
# app/controllers/admin/ajax_controller.rb
class Admin::AjaxController < Admin::BaseController
  def major_categories
    meeting_type_id = params[:meeting_type_id]
    categories = if meeting_type_id.present?
                  ProblemMajorCategory.active.for_meeting_type(meeting_type_id).ordered
                else
                  []
                end
    
    render json: categories.map { |c| { id: c.id, text: c.display_name } }
  end
  
  def specific_types
    major_category_id = params[:major_category_id]
    types = if major_category_id.present?
             ProblemSpecificType.active.for_major_category(major_category_id).ordered
           else
             []
           end
    
    render json: types.map { |t| { id: t.id, text: t.display_name } }
  end
end
```

### 阶段5：前端JavaScript支持 (1-2天)

```javascript
// app/assets/javascripts/admin/three_tier_problem_selection.js
$(document).ready(function() {
  // 会议类型变更时更新问题大类
  $('#work_order_problem_meeting_type_id').on('change', function() {
    var meetingTypeId = $(this).val();
    var targetSelect = $('#work_order_problem_major_category_id');
    var specificTypeSelect = $('#work_order_problem_specific_type_id');
    
    // 清空下级选择
    targetSelect.empty().append('<option value="">请选择问题大类</option>');
    specificTypeSelect.empty().append('<option value="">请先选择问题大类</option>');
    
    if (meetingTypeId) {
      $.ajax({
        url: '/admin/ajax/major_categories',
        data: { meeting_type_id: meetingTypeId },
        success: function(data) {
          $.each(data, function(index, item) {
            targetSelect.append('<option value="' + item.id + '">' + item.text + '</option>');
          });
        }
      });
    }
  });
  
  // 问题大类变更时更新具体问题类型
  $('#work_order_problem_major_category_id').on('change', function() {
    var majorCategoryId = $(this).val();
    var targetSelect = $('#work_order_problem_specific_type_id');
    
    targetSelect.empty().append('<option value="">请选择具体问题类型</option>');
    
    if (majorCategoryId) {
      $.ajax({
        url: '/admin/ajax/specific_types',
        data: { major_category_id: majorCategoryId },
        success: function(data) {
          $.each(data, function(index, item) {
            targetSelect.append('<option value="' + item.id + '">' + item.text + '</option>');
          });
        }
      });
    }
  });
});
```

### 阶段6：测试和验证 (2-3天)

#### 6.1 单元测试

```ruby
# spec/models/problem_meeting_type_spec.rb
RSpec.describe ProblemMeetingType, type: :model do
  describe "validations" do
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:title) }
    it { should validate_uniqueness_of(:code) }
  end
  
  describe "associations" do
    it { should have_many(:problem_major_categories) }
    it { should have_many(:work_orders) }
  end
  
  describe "#display_name" do
    let(:meeting_type) { build(:problem_meeting_type, code: '00', title: '个人') }
    
    it "returns formatted display name" do
      expect(meeting_type.display_name).to eq('00 - 个人')
    end
  end
end
```

#### 6.2 集成测试

```ruby
# spec/features/admin/three_tier_problem_selection_spec.rb
RSpec.describe "三级问题选择", type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:reimbursement) { create(:reimbursement) }
  let(:meeting_type) { create(:problem_meeting_type, code: '00', title: '个人') }
  let(:major_category) { create(:problem_major_category, meeting_type: meeting_type) }
  let(:specific_type) { create(:problem_specific_type, major_category: major_category) }
  
  before do
    login_as(admin_user, scope: :admin_user)
    meeting_type && major_category && specific_type
  end
  
  scenario "用户可以进行三级问题选择" do
    visit new_admin_audit_work_order_path
    
    select reimbursement.invoice_number, from: 'work_order_reimbursement_id'
    select meeting_type.display_name, from: 'work_order_problem_meeting_type_id'
    
    # 等待AJAX加载完成
    expect(page).to have_select('work_order_problem_major_category_id', 
                               with_options: [major_category.display_name])
    
    select major_category.display_name, from: 'work_order_problem_major_category_id'
    
    # 等待AJAX加载完成
    expect(page).to have_select('work_order_problem_specific_type_id',
                               with_options: [specific_type.display_name])
    
    select specific_type.display_name, from: 'work_order_problem_specific_type_id'
    
    fill_in 'work_order_custom_description', with: '自定义问题描述'
    select '无法通过', from: 'work_order_processing_opinion'
    
    click_button '创建'
    
    expect(page).to have_content('工单创建成功')
    
    work_order = AuditWorkOrder.last
    expect(work_order.problem_meeting_type).to eq(meeting_type)
    expect(work_order.problem_major_category).to eq(major_category)
    expect(work_order.problem_specific_type).to eq(specific_type)
    expect(work_order.custom_description).to eq('自定义问题描述')
  end
end
```

## 实施时间表

| 阶段 | 任务 | 预计时间 | 负责人 |
|------|------|----------|--------|
| 1 | 数据库结构创建 | 1-2天 | 后端开发 |
| 2 | 模型创建和关联 | 1天 | 后端开发 |
| 3 | 数据迁移 | 2-3天 | 后端开发 |
| 4 | ActiveAdmin界面更新 | 2-3天 | 全栈开发 |
| 5 | 前端JavaScript支持 | 1-2天 | 前端开发 |
| 6 | 测试和验证 | 2-3天 | 测试工程师 |

**总计：9-14天**

## 风险控制

1. **数据备份**：在执行任何迁移前完整备份数据库
2. **分步实施**：每个阶段完成后进行充分测试
3. **回滚计划**：准备回滚脚本以防出现问题
4. **用户培训**：新界面上线前对用户进行培训

## 验收标准

- [ ] 三级问题代码库表结构创建完成
- [ ] 现有数据成功迁移到新结构
- [ ] 工单表单支持三级级联选择
- [ ] AJAX级联下拉功能正常工作
- [ ] 所有测试用例通过
- [ ] 用户故事与实现完全对齐
- [ ] 测试计划v4.3可以直接执行