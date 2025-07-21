require 'rails_helper'

RSpec.describe Admin::ReimbursementsController, type: :controller do
  render_views
  
  let(:super_admin) { create(:admin_user, role: 'super_admin') }
  let(:regular_admin) { create(:admin_user, role: 'admin') }
  
  # 创建测试数据
  let!(:reimbursement1) { create(:reimbursement, invoice_number: 'R001', status: 'pending') }
  let!(:reimbursement2) { create(:reimbursement, invoice_number: 'R002', status: 'processing') }
  let!(:reimbursement3) { create(:reimbursement, invoice_number: 'R003', status: 'closed') }
  
  # 创建分配
  let!(:assignment1) { create(:reimbursement_assignment, reimbursement: reimbursement1, assignee: regular_admin, is_active: true) }
  let!(:assignment2) { create(:reimbursement_assignment, reimbursement: reimbursement2, assignee: super_admin, is_active: true) }
  # reimbursement3 没有分配
  
  before do
    sign_in admin_user
  end
  
  describe "GET #index with different scopes" do
    context "when user is super_admin" do
      let(:admin_user) { super_admin }
      
      it "shows all reimbursements with scope=all" do
        get :index, params: { scope: 'all' }
        expect(assigns(:reimbursements)).to include(reimbursement1, reimbursement2, reimbursement3)
      end
      
      it "shows only assigned reimbursements with scope=assigned_to_me" do
        get :index, params: { scope: 'assigned_to_me' }
        expect(assigns(:reimbursements)).to include(reimbursement2)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement3)
      end
      
      it "shows only assigned reimbursements with scope=my_assignments" do
        get :index, params: { scope: 'my_assignments' }
        expect(assigns(:reimbursements)).to include(reimbursement2)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement3)
      end
      
      it "shows all pending reimbursements with scope=pending" do
        get :index, params: { scope: 'pending' }
        expect(assigns(:reimbursements)).to include(reimbursement1)
        expect(assigns(:reimbursements)).not_to include(reimbursement2, reimbursement3)
      end
      
      it "shows all processing reimbursements with scope=processing" do
        get :index, params: { scope: 'processing' }
        expect(assigns(:reimbursements)).to include(reimbursement2)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement3)
      end
      
      it "shows all closed reimbursements with scope=closed" do
        get :index, params: { scope: 'closed' }
        expect(assigns(:reimbursements)).to include(reimbursement3)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement2)
      end
      
      it "shows all unassigned reimbursements with scope=unassigned" do
        get :index, params: { scope: 'unassigned' }
        expect(assigns(:reimbursements)).to include(reimbursement3)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement2)
      end
      
      it "defaults to assigned_to_me with empty scope" do
        get :index, params: { scope: '' }
        expect(assigns(:reimbursements)).to include(reimbursement2)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement3)
      end
    end
    
    context "when user is regular admin" do
      let(:admin_user) { regular_admin }
      
      it "shows all reimbursements with scope=all" do
        get :index, params: { scope: 'all' }
        expect(assigns(:reimbursements)).to include(reimbursement1, reimbursement2, reimbursement3)
      end
      
      it "shows only assigned reimbursements with scope=assigned_to_me" do
        get :index, params: { scope: 'assigned_to_me' }
        expect(assigns(:reimbursements)).to include(reimbursement1)
        expect(assigns(:reimbursements)).not_to include(reimbursement2, reimbursement3)
      end
      
      it "shows only assigned reimbursements with scope=my_assignments" do
        get :index, params: { scope: 'my_assignments' }
        expect(assigns(:reimbursements)).to include(reimbursement1)
        expect(assigns(:reimbursements)).not_to include(reimbursement2, reimbursement3)
      end
      
      it "shows only assigned pending reimbursements with scope=pending" do
        get :index, params: { scope: 'pending' }
        expect(assigns(:reimbursements)).to include(reimbursement1)
        expect(assigns(:reimbursements)).not_to include(reimbursement2, reimbursement3)
      end
      
      it "shows only assigned processing reimbursements with scope=processing" do
        get :index, params: { scope: 'processing' }
        expect(assigns(:reimbursements)).to be_empty
      end
      
      it "shows only assigned closed reimbursements with scope=closed" do
        get :index, params: { scope: 'closed' }
        expect(assigns(:reimbursements)).to be_empty
      end
      
      it "shows all unassigned reimbursements with scope=unassigned" do
        get :index, params: { scope: 'unassigned' }
        expect(assigns(:reimbursements)).to include(reimbursement3)
        expect(assigns(:reimbursements)).not_to include(reimbursement1, reimbursement2)
      end
      
      it "defaults to assigned_to_me with empty scope" do
        get :index, params: { scope: '' }
        expect(assigns(:reimbursements)).to include(reimbursement1)
        expect(assigns(:reimbursements)).not_to include(reimbursement2, reimbursement3)
      end
    end
  end
  
  describe "GET #show" do
    context "when user is super_admin" do
      let(:admin_user) { super_admin }
      
      it "can access any reimbursement" do
        get :show, params: { id: reimbursement1.id }
        expect(response).to be_successful
        
        get :show, params: { id: reimbursement2.id }
        expect(response).to be_successful
        
        get :show, params: { id: reimbursement3.id }
        expect(response).to be_successful
      end
    end
    
    context "when user is regular admin" do
      let(:admin_user) { regular_admin }
      
      it "can access any reimbursement" do
        get :show, params: { id: reimbursement1.id }
        expect(response).to be_successful
        
        get :show, params: { id: reimbursement2.id }
        expect(response).to be_successful
        
        get :show, params: { id: reimbursement3.id }
        expect(response).to be_successful
      end
    end
  end
end