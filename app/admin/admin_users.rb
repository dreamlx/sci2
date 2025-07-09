ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation, :role, :name, :telephone

  menu priority: 10, label: "管理员用户"

  index do
    selectable_column
    id_column
    column :email
    column :name
    column :role
    column :telephone
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :name
  filter :role, as: :select, collection: AdminUser.roles.keys
  filter :telephone
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  show do
    attributes_table do
      row :id
      row :email
      row :name
      row :telephone
      row :role
      row :current_sign_in_at
      row :last_sign_in_at
      row :sign_in_count
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :name
      f.input :telephone
      f.input :role, as: :select, collection: AdminUser.roles.keys, include_blank: false
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  controller do
    def update
      if params[:admin_user][:password].blank? && params[:admin_user][:password_confirmation].blank?
        params[:admin_user].delete("password")
        params[:admin_user].delete("password_confirmation")
      end
      super
    end
  end
end
