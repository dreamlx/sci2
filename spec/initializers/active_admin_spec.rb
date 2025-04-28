require 'rails_helper'

RSpec.describe "ActiveAdmin配置" do
  it "应该正确加载ActiveAdmin配置" do
    expect(ActiveAdmin.application.site_title).to eq("SCI2工单系统")
    expect(ActiveAdmin.application.default_namespace).to eq(:admin)
    expect(ActiveAdmin.application.root_to).to eq('dashboard#index')
    expect(ActiveAdmin.application.batch_actions).to be true
    expect(ActiveAdmin.application.default_per_page).to eq(30)
    expect(ActiveAdmin.application.csv_options).to eq({ col_sep: ',', force_quotes: true })
    expect(ActiveAdmin.application.comments).to be false
  end
end