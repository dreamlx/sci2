//= require active_admin/base

// 添加确认对话框的自定义文本
$.fn.activeAdminConfirm = function(options) {
  options = options || {};
  options.message = options.message || "确定要执行此操作吗?";

  return this.each(function() {
    $(this).on('click', function(e) {
      if (!confirm(options.message)) {
        e.preventDefault();
      }
    });
  });
};

$(document).on('ready turbolinks:load', function() {
  // 为状态变更按钮添加确认对话框
  $('.status_action').activeAdminConfirm({
    message: "确定要变更状态吗? 此操作可能会影响关联数据。"
  });

  // 初始化日期选择器
  $('.datepicker').datepicker({
    dateFormat: 'yy-mm-dd',
    firstDay: 1
  });
});
