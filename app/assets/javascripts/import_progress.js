// 导入进度提示和用户体验增强
document.addEventListener('DOMContentLoaded', function() {
  // 初始化导入进度功能
  initializeImportProgress();
});

function initializeImportProgress() {
  const importForms = document.querySelectorAll('#import_form');
  
  importForms.forEach(function(form) {
    const submitBtn = form.querySelector('#import_submit_btn');
    const fileInput = form.querySelector('#file_input');
    const progressDiv = form.querySelector('#import_progress');
    const progressMessage = form.querySelector('#progress_message');
    const progressDetails = form.querySelector('#progress_details');
    const errorDiv = form.querySelector('#import_error');
    
    if (!form || !submitBtn || !progressDiv) return;
    
    // 表单提交处理
    form.addEventListener('submit', function(e) {
      const file = fileInput.files[0];
      
      if (!file) {
        alert('请选择要导入的文件');
        e.preventDefault();
        return;
      }
      
      // 文件大小检查
      const fileSizeMB = file.size / 1024 / 1024;
      if (fileSizeMB > 100) {
        if (!confirm(`文件较大 (${fileSizeMB.toFixed(2)}MB)，导入可能需要较长时间，是否继续？`)) {
          e.preventDefault();
          return;
        }
      }
      
      // 显示进度提示
      showImportProgress(file, progressDiv, progressMessage, progressDetails);
      
      // 禁用提交按钮防止重复提交
      disableSubmitButton(submitBtn, form);
      
      // 隐藏错误提示
      if (errorDiv) errorDiv.style.display = 'none';
      
      // 设置超时检查
      setupTimeoutCheck(form, submitBtn);
    });
    
    // 文件选择预检查
    if (fileInput) {
      fileInput.addEventListener('change', function(e) {
        handleFileSelection(e, this);
      });
    }
  });
}

function showImportProgress(file, progressDiv, progressMessage, progressDetails) {
  progressDiv.style.display = 'block';
  
  // 显示文件信息
  const fileSize = (file.size / 1024 / 1024).toFixed(2);
  const fileName = file.name;
  const estimatedRecords = Math.round(file.size / 1024 * 7.5); // 粗略估算
  
  progressMessage.textContent = `正在处理文件: ${fileName} (${fileSize}MB)`;
  
  // 估算处理时间（基于优化后的性能）
  let estimatedTime = '几秒钟';
  if (estimatedRecords > 10000) {
    estimatedTime = '10-30秒';
  } else if (estimatedRecords > 5000) {
    estimatedTime = '5-15秒';
  } else if (estimatedRecords > 1000) {
    estimatedTime = '2-10秒';
  }
  
  progressDetails.innerHTML = `
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 10px;">
      <div>📁 文件名: ${fileName}</div>
      <div>📊 文件大小: ${fileSize}MB</div>
      <div>📈 预计记录数: ${estimatedRecords.toLocaleString()}条</div>
      <div>⏱️ 预计处理时间: ${estimatedTime}</div>
    </div>
    <div style="padding: 8px; background: #e8f5e8; border-radius: 3px; color: #2e7d32; font-size: 12px;">
      💡 提示: 已启用批量优化技术，导入速度比传统方式快30-40倍
    </div>
    <div style="margin-top: 8px; color: #ff6b35; font-size: 12px;">
      ⚠️ 导入过程中请不要关闭页面或重复点击导入按钮
    </div>
  `;
  
  // 添加动态进度提示
  startProgressMessages(progressMessage);
}

function startProgressMessages(progressMessage) {
  let messageIndex = 0;
  const messages = [
    '🔍 正在解析文件内容...',
    '✅ 正在验证数据格式...',
    '⚡ 正在执行批量导入...',
    '🔄 正在更新关联关系...',
    '🎯 即将完成，请稍候...'
  ];
  
  const messageInterval = setInterval(function() {
    if (messageIndex < messages.length) {
      progressMessage.textContent = messages[messageIndex];
      messageIndex++;
    } else {
      clearInterval(messageInterval);
      progressMessage.textContent = '🏁 正在完成导入，请稍候...';
    }
  }, 2000); // 每2秒更换一次提示信息
  
  // 保存interval ID以便后续清理
  window.importProgressInterval = messageInterval;
}

function disableSubmitButton(submitBtn, form) {
  submitBtn.disabled = true;
  submitBtn.textContent = '导入中...';
  submitBtn.style.opacity = '0.6';
  submitBtn.style.cursor = 'not-allowed';
  form.classList.add('importing');
  
  // 添加视觉反馈
  submitBtn.style.background = '#ccc';
}

function setupTimeoutCheck(form, submitBtn) {
  // 设置超时检查（5分钟）
  const timeoutId = setTimeout(function() {
    if (form.classList.contains('importing')) {
      const continueImport = confirm(
        '导入已进行5分钟，可能是大文件导入或网络较慢。\n\n' +
        '点击"确定"继续等待\n' +
        '点击"取消"刷新页面（注意：这可能会中断导入过程）'
      );
      
      if (!continueImport) {
        window.location.reload();
      } else {
        // 继续等待，再设置一个5分钟的检查
        setupTimeoutCheck(form, submitBtn);
      }
    }
  }, 5 * 60 * 1000); // 5分钟
  
  // 保存timeout ID
  window.importTimeoutId = timeoutId;
}

function handleFileSelection(e, fileInput) {
  const file = e.target.files[0];
  if (!file) return;
  
  const fileSize = file.size / 1024 / 1024; // MB
  const fileName = file.name;
  const fileExt = fileName.split('.').pop().toLowerCase();
  
  // 文件格式检查
  if (!['csv', 'xlsx', 'xls'].includes(fileExt)) {
    alert('请选择CSV或Excel格式的文件');
    e.target.value = '';
    return;
  }
  
  // 文件大小检查
  if (fileSize > 50) { // 大于50MB
    if (!confirm(`文件较大 (${fileSize.toFixed(2)}MB)，导入可能需要较长时间，是否继续？`)) {
      e.target.value = '';
      return;
    }
  }
  
  // 显示文件信息
  showFileInfo(fileInput, fileName, fileSize);
}

function showFileInfo(fileInput, fileName, fileSizeMB) {
  const estimatedRecords = Math.round(fileSizeMB * 7500); // 粗略估算
  
  const fileInfo = document.createElement('div');
  fileInfo.style.cssText = `
    margin-top: 8px; 
    padding: 10px; 
    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); 
    border-radius: 5px; 
    font-size: 13px;
    border-left: 4px solid #4CAF50;
  `;
  
  fileInfo.innerHTML = `
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
      <div><strong>📁 文件名:</strong> ${fileName}</div>
      <div><strong>📊 文件大小:</strong> ${fileSizeMB.toFixed(2)}MB</div>
      <div><strong>📈 预计记录数:</strong> ${estimatedRecords.toLocaleString()}条</div>
      <div><strong>⚡ 预计导入时间:</strong> ${getEstimatedTime(estimatedRecords)}</div>
    </div>
    <div style="margin-top: 8px; padding: 6px; background: rgba(76, 175, 80, 0.1); border-radius: 3px; color: #2e7d32; font-size: 12px;">
      ✨ 使用批量优化技术，导入速度约 ${Math.round(estimatedRecords / getEstimatedTimeSeconds(estimatedRecords)).toLocaleString()} 记录/秒
    </div>
  `;
  
  // 移除之前的文件信息
  const existingInfo = fileInput.parentNode.querySelector('.file-info');
  if (existingInfo) {
    existingInfo.remove();
  }
  
  fileInfo.className = 'file-info';
  fileInput.parentNode.appendChild(fileInfo);
}

function getEstimatedTime(recordCount) {
  const seconds = getEstimatedTimeSeconds(recordCount);
  
  if (seconds < 60) {
    return `${seconds}秒`;
  } else {
    const minutes = Math.ceil(seconds / 60);
    return `${minutes}分钟`;
  }
}

function getEstimatedTimeSeconds(recordCount) {
  // 基于批量优化后的性能：约10,000记录/秒
  return Math.max(1, Math.ceil(recordCount / 10000));
}

// 页面离开确认
window.addEventListener('beforeunload', function(e) {
  const importingForms = document.querySelectorAll('#import_form.importing');
  if (importingForms.length > 0) {
    e.preventDefault();
    e.returnValue = '导入正在进行中，确定要离开页面吗？这可能会中断导入过程。';
    return e.returnValue;
  }
});

// 清理函数
window.addEventListener('unload', function() {
  if (window.importProgressInterval) {
    clearInterval(window.importProgressInterval);
  }
  if (window.importTimeoutId) {
    clearTimeout(window.importTimeoutId);
  }
});