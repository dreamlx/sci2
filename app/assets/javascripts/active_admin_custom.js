document.addEventListener('DOMContentLoaded', function() {
  // Check if we're on the unassigned reimbursements page
  if (window.location.href.includes('/admin/reimbursements') && 
      window.location.href.includes('scope=unassigned')) {
    
    // Add a prominent message above the table
    var tableContainer = document.querySelector('.index_as_table');
    if (tableContainer) {
      var messageDiv = document.createElement('div');
      messageDiv.className = 'batch_assign_message';
      messageDiv.innerHTML = '<h3>请选择要分配的报销单，然后点击上方的"批量分配报销单"按钮</h3>';
      messageDiv.style.padding = '15px';
      messageDiv.style.margin = '15px 0';
      messageDiv.style.backgroundColor = '#e8f5e9';
      messageDiv.style.border = '1px solid #4CAF50';
      messageDiv.style.borderRadius = '4px';
      messageDiv.style.textAlign = 'center';
      messageDiv.style.color = '#2e7d32';
      
      tableContainer.parentNode.insertBefore(messageDiv, tableContainer);
    }
    
    // Make the batch actions dropdown more prominent
    var batchActionsButton = document.querySelector('.batch_actions_selector .dropdown_menu_button');
    if (batchActionsButton) {
      // Add a pulsing animation to draw attention
      batchActionsButton.style.animation = 'pulse 2s infinite';
      
      // Add the animation keyframes
      var style = document.createElement('style');
      style.textContent = `
        @keyframes pulse {
          0% {
            box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.7);
          }
          70% {
            box-shadow: 0 0 0 10px rgba(76, 175, 80, 0);
          }
          100% {
            box-shadow: 0 0 0 0 rgba(76, 175, 80, 0);
          }
        }
      `;
      document.head.appendChild(style);
    }
  }
});