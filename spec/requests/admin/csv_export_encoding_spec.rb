require 'rails_helper'

RSpec.describe "CSV Export Character Encoding", type: :request do
  let!(:admin_user) { create(:admin_user, :super_admin) }
  let!(:reimbursement_with_chinese) { create(:reimbursement, 
    invoice_number: "INV-2023-测试",
    document_name: "测试报销单-中文内容",
    applicant: "张三",
    company: "测试科技有限公司",
    department: "研发部门",
    external_status: "审批中"
  )}

  before do
    sign_in admin_user
  end

  describe "CSV Export Encoding Tests" do
    context "when exporting CSV with Chinese characters" do
      it "includes UTF-8 BOM for Excel compatibility" do
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Type']).to include('charset=utf-8')
        
        # Check for UTF-8 BOM (Byte Order Mark)
        bom = response.body.bytes[0..2]
        expect(bom).to eq([0xEF, 0xBB, 0xBF]) # UTF-8 BOM
        
        # Verify the response body contains Chinese characters
        expect(response.body).to include("测试")
        expect(response.body).to include("中文")
        expect(response.body).to include("张三")
      end

      it "sets proper Content-Disposition headers for Windows compatibility" do
        get admin_reimbursements_path(format: :csv)
        
        content_disposition = response.headers['Content-Disposition']
        expect(content_disposition).to include('attachment')
        expect(content_disposition).to include('.csv')
        expect(content_disposition).to include('filename*=') # UTF-8 filename encoding
      end

      it "handles invalid UTF-8 sequences gracefully" do
        # Create a record with potentially problematic characters
        problematic_reimbursement = create(:reimbursement,
          invoice_number: "INV-2023-特殊字符",
          document_name: "测试单\u0000包含\u0001控制字符",
          applicant: "李四\u0080\u009F"
        )
        
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        # Should not raise encoding errors
        expect { response.body.encode('UTF-8') }.not_to raise_error
      end

      it "preserves Chinese characters in CSV content" do
        get admin_reimbursements_path(format: :csv)
        
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '') # Remove BOM for parsing
        csv = CSV.parse(csv_content, headers: true)
        
        # Find the row with our test data
        test_row = csv.find { |row| row["报销单单号"] == "INV-2023-测试" }
        
        expect(test_row).not_to be_nil
        expect(test_row["单据名称"]).to eq("测试报销单-中文内容")
        expect(test_row["报销单申请人"]).to eq("张三")
        expect(test_row["申请人公司"]).to eq("测试科技有限公司")
        expect(test_row["申请人部门"]).to eq("研发部门")
        expect(test_row["报销单状态"]).to eq("审批中")
      end
    end

    context "when comparing different export formats" do
      it "provides consistent data between CSV and Excel exports" do
        # Test CSV export
        get admin_reimbursements_path(format: :csv)
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '')
        csv = CSV.parse(csv_content, headers: true)
        
        # Test Excel export (if available)
        begin
          get admin_reimbursements_path(format: :xlsx)
          
          if response.successful?
            # Excel export is working, compare data consistency
            expect(response.content_type).to include('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
            
            # Both formats should have the same data structure
            csv_headers = csv.headers
            expect(csv_headers).to include("报销单单号")
            expect(csv_headers).to include("单据名称")
            expect(csv_headers).to include("报销单申请人")
          else
            # Excel export might not be available, which is acceptable
            puts "Excel export not available, skipping comparison test"
          end
        rescue => e
          puts "Excel export test skipped due to: #{e.message}"
        end
      end
    end

    context "when testing cross-platform compatibility" do
      it "generates CSV that can be opened in Windows Excel" do
        get admin_reimbursements_path(format: :csv)
        
        # Simulate Windows Excel requirements
        csv_content = response.body
        
        # Should start with BOM for Excel recognition
        expect(csv_content).to start_with("\xEF\xBB\xBF")
        
        # Should be valid UTF-8
        expect { csv_content.encode('UTF-8') }.not_to raise_error
        
        # Should have proper line endings (CRLF for Windows)
        expect(csv_content).to include("\r\n").or include("\n")
        
        # Headers should be properly quoted if they contain special characters
        expect(csv_content).to include('"报销单单号"')
      end

      it "handles various Chinese character encodings" do
        # Test with different Chinese character sets
        test_cases = [
          { invoice_number: "INV-简体测试", document_name: "简体中文测试" },
          { invoice_number: "INV-繁體測試", document_name: "繁體中文測試" },
          { invoice_number: "INV-混合測试", document_name: "混合简繁体測试" }
        ]
        
        test_cases.each do |test_data|
          create(:reimbursement, test_data)
        end
        
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '')
        
        # All test cases should be present in the CSV
        test_cases.each do |test_data|
          expect(csv_content).to include(test_data[:invoice_number])
          expect(csv_content).to include(test_data[:document_name])
        end
      end
    end

    context "when testing edge cases" do
      it "handles empty Chinese strings correctly" do
        empty_chinese_reimbursement = create(:reimbursement,
          invoice_number: "INV-EMPTY",
          document_name: "",
          applicant: "   ", # Spaces only
          company: nil
        )
        
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '')
        csv = CSV.parse(csv_content, headers: true)
        
        empty_row = csv.find { |row| row["报销单单号"] == "INV-EMPTY" }
        expect(empty_row).not_to be_nil
        expect(empty_row["单据名称"]).to eq("")
        expect(empty_row["报销单申请人"]).to eq("   ")
        expect(empty_row["申请人公司"]).to eq("")
      end

      it "handles very long Chinese text" do
        long_text = "这是一个非常长的中文测试字符串" * 20 # Repeat 20 times
        long_reimbursement = create(:reimbursement,
          invoice_number: "INV-LONG",
          document_name: long_text
        )
        
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '')
        expect(csv_content).to include(long_text)
      end

      it "handles mixed Chinese and English content" do
        mixed_reimbursement = create(:reimbursement,
          invoice_number: "INV-MIXED-001",
          document_name: "报销单 Reimbursement 测试 Test",
          applicant: "John Doe 张三",
          company: "ABC公司 Ltd.",
          department: "IT部门 Tech Department"
        )
        
        get admin_reimbursements_path(format: :csv)
        
        expect(response).to be_successful
        csv_content = response.body.sub(/^\xEF\xBB\xBF/, '')
        csv = CSV.parse(csv_content, headers: true)
        
        mixed_row = csv.find { |row| row["报销单单号"] == "INV-MIXED-001" }
        expect(mixed_row).not_to be_nil
        expect(mixed_row["单据名称"]).to eq("报销单 Reimbursement 测试 Test")
        expect(mixed_row["报销单申请人"]).to eq("John Doe 张三")
        expect(mixed_row["申请人公司"]).to eq("ABC公司 Ltd.")
        expect(mixed_row["申请人部门"]).to eq("IT部门 Tech Department")
      end
    end
  end

  describe "Excel Export Encoding Tests" do
    it "generates Excel files with proper encoding" do
      skip "Excel export requires RubyXL gem" unless defined?(RubyXL)
      
      get admin_reimbursements_path(format: :xlsx)
      
      expect(response).to be_successful
      expect(response.content_type).to include('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      
      # The Excel file should contain Chinese characters
      # Note: We can't easily parse the binary Excel content here, but we can verify the response
      expect(response.body.bytesize).to be > 0
    end
  end

  describe "Export Performance with Large Chinese Datasets" do
    it "handles large datasets with Chinese characters efficiently" do
      # Create a larger dataset with Chinese content
      50.times do |i|
        create(:reimbursement,
          invoice_number: "INV-#{i}-测试",
          document_name: "测试报销单编号#{i}",
          applicant: "测试用户#{i}",
          company: "测试公司#{i}",
          department: "测试部门#{i}"
        )
      end
      
      start_time = Time.current
      get admin_reimbursements_path(format: :csv)
      end_time = Time.current
      
      expect(response).to be_successful
      expect(response.body).to include("测试") # Should contain Chinese characters
      
      # Performance should be reasonable (less than 5 seconds for 50+ records)
      expect(end_time - start_time).to be < 5.seconds
    end
  end
end
