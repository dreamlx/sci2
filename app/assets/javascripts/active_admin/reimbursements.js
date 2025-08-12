// 报销单附件上传表单处理
document.addEventListener('DOMContentLoaded', function() {
  const form = document.querySelector('form[action*="upload_attachment"]');
  if(form) {
    form.addEventListener('submit', function(e) {
      // 检查是否选择了文件
      const fileInput = form.querySelector('input[type="file"]');
      if(!fileInput.files.length) {
        alert('请选择要上传的文件');
        e.preventDefault();
        return;
      }
      
      // 添加加载状态
      const submitBtn = form.querySelector('input[type="submit"]');
      const originalValue = submitBtn.value;
      submitBtn.value = '上传中...';
      submitBtn.disabled = true;
      
      // 让表单正常提交，ActiveAdmin会处理重定向
    });
  }
});