Rails.application.routes.draw do
  # ActiveAdmin Devise routes
  devise_for :admin_users, ActiveAdmin::Devise.config

  # 自定义API路由
  namespace :api, constraints: { format: :json } do
    namespace :v1 do
      resources :reimbursements, only: [:index, :show] do
        collection do
          post :import
        end
      end

      resources :fee_details, only: [:index, :show] do
        collection do
          post :import
        end
      end

      resources :work_orders, only: [:index, :show]
    end
  end

  # 自定义控制器路由
  namespace :admin do
    resources :imports, only: [] do
      collection do
        get :reimbursements
        post :import_reimbursements
        get :fee_details
        post :import_fee_details
        get :express_receipts
        post :import_express_receipts
        get :operation_histories
        post :import_operation_histories
      end
    end

    resources :statistics, only: [:index] do
      collection do
        get :reimbursement_status_counts
        get :work_order_status_counts
        get :fee_detail_verification_counts
      end
    end
    resources :dashboards, only: [:index]

    # Explicit route for start_processing member action
    put 'reimbursements/:id/start_processing', to: 'reimbursements#start_processing', as: :start_processing_admin_reimbursement

    # Audit work orders routes

  end

  # 设置根路由重定向到管理界面
  root to: "application#redirect_to_admin"

  # ActiveAdmin routes
  ActiveAdmin.routes(self)
end
