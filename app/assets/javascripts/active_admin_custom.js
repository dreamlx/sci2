// Custom JavaScript for ActiveAdmin
document.addEventListener('DOMContentLoaded', function() {
  // Initialize custom functionality for ActiveAdmin
  initializeActiveAdminCustomizations();
});

function initializeActiveAdminCustomizations() {
  // Remove any debug output or unwanted content from the page
  removeDebugOutput();
  
  // Initialize custom tooltips if needed
  initializeCustomTooltips();
}

function removeDebugOutput() {
  // Remove any script tags or debug content that might be showing at the bottom
  const debugElements = document.querySelectorAll('script[src*="active_admin_custom.js"]');
  debugElements.forEach(function(element) {
    // Hide any visible script content
    if (element.nextSibling && element.nextSibling.nodeType === Node.TEXT_NODE) {
      element.nextSibling.remove();
    }
  });
  
  // Remove any stray text nodes that might be showing file paths
  const walker = document.createTreeWalker(
    document.body,
    NodeFilter.SHOW_TEXT,
    function(node) {
      return node.textContent.includes('app/assets/javascripts/active_admin_custom.js') ?
        NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    }
  );
  
  const nodesToRemove = [];
  let node;
  while (node = walker.nextNode()) {
    nodesToRemove.push(node);
  }
  
  nodesToRemove.forEach(function(node) {
    node.remove();
  });
}

function initializeCustomTooltips() {
  // Placeholder for future tooltip functionality
  // This can be expanded when tooltip features are needed
}