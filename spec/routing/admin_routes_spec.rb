require 'rails_helper'

RSpec.describe '管理界面路由', type: :routing do
  it '根路由重定向到管理界面' do
    expect(get: '/').to route_to('application#redirect_to_admin')
  end

  it '路由到管理员登录页面' do
    expect(get: '/admin/login').to route_to('active_admin/devise/sessions#new')
  end

  it '路由到报销单列表页面' do
    expect(get: '/admin/reimbursements').to route_to('admin/reimbursements#index')
  end

  it '路由到报销单详情页面' do
    expect(get: '/admin/reimbursements/1').to route_to('admin/reimbursements#show', id: '1')
  end

  it '路由到报销单导入页面' do
    expect(get: '/admin/reimbursements/new_import').to route_to('admin/reimbursements#new_import')
  end

  it '路由到报销单状态更新操作' do
    expect(put: '/admin/reimbursements/1/start_processing').to route_to('admin/reimbursements#start_processing',
                                                                        id: '1')
  end
end
