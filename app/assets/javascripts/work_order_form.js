// Shared JavaScript for both Audit and Communication work order forms
document.addEventListener('DOMContentLoaded', function() {
  // Enable debug logging
  const DEBUG = true;
  function debugLog(...args) {
    if (DEBUG) console.log(...args);
  }

  // Initialize based on form type
  const isAuditForm = document.querySelector('form[id*="audit_work_order"]');
  const formType = isAuditForm ? 'audit' : 'communication';
  debugLog(`Initializing ${formType} work order form...`);

  // Check API endpoints
  checkApiEndpoints();

  // Get DOM elements
  const form = document.querySelector('form.formtastic');
  const feeDetailCheckboxes = document.querySelectorAll('.fee-detail-checkbox');
  const feeTypeTagsContainer = document.querySelector('.fee-type-tags-container');
  const feeTypeTags = document.getElementById('fee-type-tags');
  const problemTypesContainer = document.getElementById('problem-types-container');
  const problemTypesWrapper = document.querySelector('.problem-types-wrapper');
  const validationErrorsContainer = document.getElementById('validation-errors');
  const processingOpinionRadios = document.querySelectorAll(`input[name="${formType}_work_order[processing_opinion]"]`);
  const auditCommentField = document.getElementById('audit_comment_field');

  debugLog('DOM元素获取状态:');
  debugLog('- 费用明细复选框:', feeDetailCheckboxes.length);
  debugLog('- 费用类型标签容器:', feeTypeTagsContainer ? '已找到' : '未找到');
  debugLog('- 费用类型标签区域:', feeTypeTags ? '已找到' : '未找到');
  debugLog('- 问题类型容器:', problemTypesContainer ? '已找到' : '未找到');
  debugLog('- 问题类型包装器:', problemTypesWrapper ? '已找到' : '未找到');
  debugLog('- 验证错误容器:', validationErrorsContainer ? '已找到' : '未找到');
  debugLog('- 处理意见单选按钮:', processingOpinionRadios.length);
  debugLog('- 审核意见字段:', auditCommentField ? '已找到' : '未找到');

  // Application state
  const appState = {
    allFeeTypes: [],
    allProblemTypes: [],
    selectedFeeDetails: [],
    uniqueFeeTypes: new Set(),
    processingOpinion: null,
    validationErrors: [],
    isFormValid: true
  };

  // Initialize the application
  initializeApp();

  function initializeApp() {
    // 添加事件监听器
    setupEventListeners();
    
    // 加载费用类型和问题类型数据
    Promise.all([loadFeeTypes(), loadProblemTypes()])
      .then(() => {
        debugLog('数据加载完成，初始化UI状态');
        
        // 初始化UI状态
        updateSelectedFeeDetails();
        
        // 如果处理意见为"无法通过"，显示问题类型
        if (appState.processingOpinion === '无法通过') {
          showProblemTypes();
        } else {
          hideProblemTypes();
        }
      })
      .catch(error => {
        console.error('初始化应用时出错:', error);
        if (validationErrorsContainer) {
          if (error.message.includes('Authentication required')) {
            validationErrorsContainer.innerHTML = `
              <p>需要重新登录: 请刷新页面或重新登录</p>
              <p><a href="/admin/logout" class="button">重新登录</a></p>
            `;
          } else {
            validationErrorsContainer.innerHTML = `<p>初始化应用时出错: ${error.message}</p>`;
          }
          validationErrorsContainer.style.display = 'block';
        }
      });
  }

  // 设置事件监听器
  function setupEventListeners() {
    // 费用明细复选框变化
    feeDetailCheckboxes.forEach(checkbox => {
      checkbox.addEventListener('change', handleFeeDetailChange);
    });
    
    // 处理意见变化
    processingOpinionRadios.forEach(radio => {
      radio.addEventListener('change', handleProcessingOpinionChange);
      // 检查初始状态
      if (radio.checked) {
        appState.processingOpinion = radio.value;
        debugLog('初始处理意见:', appState.processingOpinion);
      }
    });
    
    // 审核意见字段变化
    if (auditCommentField) {
      auditCommentField.addEventListener('input', function() {
        if (appState.validationErrors.length > 0) {
          validateFormState();
          renderValidationErrors();
        }
      });
    }
    
    // 表单提交验证
    if (form) {
      form.addEventListener('submit', validateForm);
      debugLog('已添加表单验证');
    } else {
      console.error('未找到表单元素');
    }
  }
  
  // 加载费用类型数据
  function loadFeeTypes() {
    debugLog('加载费用类型数据...');
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!csrfToken) {
      console.error('CSRF token not found');
      return Promise.reject(new Error('CSRF token not found'));
    }

    return fetch('/admin/fee_types.json', {
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'include'
    })
    .then(response => {
      if (response.status === 401) {
        // Handle unauthorized error
        console.error('Authentication required - please refresh the page');
        validationErrorsContainer.innerHTML = `
          <p>需要重新登录: 请刷新页面或重新登录</p>
          <p><a href="/admin/logout" class="button">重新登录</a></p>
        `;
        validationErrorsContainer.style.display = 'block';
        throw new Error('Authentication required');
      }
      return response;
    })
    .then(response => {
      debugLog('费用类型API响应状态:', response.status);
      if (!response.ok) {
        throw new Error(`获取费用类型失败: ${response.status} ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      debugLog('获取到费用类型数据:', data);
      appState.allFeeTypes = data;
    })
    .catch(error => {
      console.error('加载费用类型时出错:', error);
      throw error;
    });
  }
  
  // 加载问题类型数据
  function loadProblemTypes() {
    debugLog('加载问题类型数据...');
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    if (!csrfToken) {
      console.error('CSRF token not found');
      return Promise.reject(new Error('CSRF token not found'));
    }

    return fetch('/admin/problem_types.json', {
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'include'
    })
    .then(response => {
      if (response.status === 401) {
        // Handle unauthorized error
        console.error('Authentication required - please refresh the page');
        validationErrorsContainer.innerHTML = `
          <p>需要重新登录: 请刷新页面或重新登录</p>
          <p><a href="/admin/logout" class="button">重新登录</a></p>
        `;
        validationErrorsContainer.style.display = 'block';
        throw new Error('Authentication required');
      }
      return response;
    })
    .then(response => {
      debugLog('问题类型API响应状态:', response.status);
      if (!response.ok) {
        throw new Error(`获取问题类型失败: ${response.status} ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      debugLog('获取到问题类型数据:', data);
      appState.allProblemTypes = data;
    })
    .catch(error => {
      console.error('加载问题类型时出错:', error);
      throw error;
    });
  }
  
  // 处理费用明细选择变化
  function handleFeeDetailChange() {
    debugLog('费用明细选择变更');
    
    // 更新选中的费用明细
    updateSelectedFeeDetails();
    
    // 如果处理意见为"无法通过"，更新问题类型
    if (appState.processingOpinion === '无法通过') {
      showProblemTypes();
    }
    
    // 如果有验证错误，重新验证
    if (appState.validationErrors.length > 0) {
      validateFormState();
      renderValidationErrors();
    }
  }
  
  // 处理处理意见变化
  function handleProcessingOpinionChange(event) {
    const newOpinion = event.target.value;
    debugLog('处理意见变更为:', newOpinion);
    
    // 更新状态
    appState.processingOpinion = newOpinion;
    
    // 根据处理意见显示/隐藏相应区域
    if (newOpinion === '无法通过') {
      showProblemTypes();
    } else {
      hideProblemTypes();
    }
    
    // 如果有验证错误，重新验证
    if (appState.validationErrors.length > 0) {
      validateFormState();
      renderValidationErrors();
    }
  }
  
  // 更新选中的费用明细
  function updateSelectedFeeDetails() {
    debugLog('更新选中的费用明细...');
    
    // 重置状态
    appState.selectedFeeDetails = [];
    appState.uniqueFeeTypes = new Set();
    
    // 获取所有选中的费用明细
    feeDetailCheckboxes.forEach(checkbox => {
      if (checkbox.checked) {
        const feeDetailId = checkbox.value;
        const feeType = checkbox.dataset.feeType || '';
        
        debugLog(`选中的费用明细 #${feeDetailId}, 费用类型: "${feeType}"`);
        
        // 添加到选中的费用明细
        appState.selectedFeeDetails.push({
          id: feeDetailId,
          feeType: feeType
        });
        
        // 添加到唯一费用类型集合
        if (feeType && feeType.trim() !== '') {
          appState.uniqueFeeTypes.add(feeType);
        }
      }
    });
    
    debugLog('选中的费用明细数量:', appState.selectedFeeDetails.length);
    debugLog('唯一费用类型:', Array.from(appState.uniqueFeeTypes));
    
    // 更新费用类型标签
    renderFeeTypeTags();
  }
  
  // 渲染费用类型标签
  function renderFeeTypeTags() {
    debugLog('渲染费用类型标签...');
    
    if (!feeTypeTagsContainer || !feeTypeTags) {
      console.error('费用类型标签容器或区域未找到');
      return;
    }
    
    // 清空容器
    feeTypeTagsContainer.innerHTML = '';
    
    // 检查是否有选择的费用明细
    const uniqueFeeTypesArray = Array.from(appState.uniqueFeeTypes);
    
    if (uniqueFeeTypesArray.length === 0) {
      // 没有选择费用明细，显示提示信息
      feeTypeTagsContainer.innerHTML = '<p>未选择费用明细</p>';
      feeTypeTags.style.display = 'none';
      return;
    }
    
    // 有选择的费用明细，显示费用类型标签
    uniqueFeeTypesArray.forEach(feeType => {
      const tagDiv = document.createElement('div');
      tagDiv.className = 'fee-type-tag';
      tagDiv.dataset.feeType = feeType;
      
      // 计算该费用类型下的费用明细数量
      const count = appState.selectedFeeDetails.filter(detail => detail.feeType === feeType).length;
      
      tagDiv.textContent = `${feeType} (${count}项)`;
      feeTypeTagsContainer.appendChild(tagDiv);
    });
    
    // 确保费用类型标签区域显示
    feeTypeTags.style.display = 'block';
  }
  
  // 显示问题类型
  function showProblemTypes() {
    debugLog('显示问题类型...');
    
    if (!problemTypesContainer || !problemTypesWrapper) {
      console.error('问题类型容器或包装器未找到');
      return;
    }
    
    // 确保问题类型区域显示
    problemTypesContainer.style.display = 'block';
    
    // 清空问题类型容器
    problemTypesWrapper.innerHTML = '';
    
    // 如果没有选择费用明细，显示提示信息
    if (appState.selectedFeeDetails.length === 0) {
      problemTypesWrapper.innerHTML = '<p>请先选择费用明细，以加载相关的问题类型</p>';
      return;
    }
    
    // 获取选中费用类型对应的问题类型
    const relevantProblemTypes = getRelevantProblemTypes();
    
    // 如果没有找到相关问题类型，显示提示信息
    if (relevantProblemTypes.length === 0) {
      problemTypesWrapper.innerHTML = '<p>未找到与已选费用类型相关的问题类型</p>';
      return;
    }
    
    // 创建问题类型复选框
    renderProblemTypeCheckboxes(relevantProblemTypes);
  }
  
  // 隐藏问题类型
  function hideProblemTypes() {
    debugLog('隐藏问题类型...');
    
    if (problemTypesContainer) {
      problemTypesContainer.style.display = 'none';
    }
  }
  
  // 获取与选中费用类型相关的问题类型
  function getRelevantProblemTypes() {
    debugLog('获取相关问题类型...');
    
    // 如果没有选择费用明细，返回空数组
    if (appState.selectedFeeDetails.length === 0) {
      return [];
    }
    
    // 获取选中费用类型对应的FeeType记录
    const selectedFeeTypeNames = Array.from(appState.uniqueFeeTypes);
    const matchedFeeTypes = [];
    const unmatchedFeeTypes = [];
    
    // 严格匹配费用类型
    selectedFeeTypeNames.forEach(feeTypeName => {
      // 只进行精确匹配
      const exactMatch = appState.allFeeTypes.find(ft =>
        ft.title === feeTypeName ||
        ft.code === feeTypeName ||
        ft.display_name === feeTypeName
      );
      
      if (exactMatch) {
        matchedFeeTypes.push(exactMatch);
      } else {
        // 如果没有找到匹配，记录未匹配的费用类型
        unmatchedFeeTypes.push(feeTypeName);
      }
    });
    
    debugLog('匹配到的费用类型:', matchedFeeTypes);
    debugLog('未匹配到的费用类型:', unmatchedFeeTypes);
    
    // 如果有未匹配的费用类型，显示提示
    if (unmatchedFeeTypes.length > 0) {
      // 在费用类型标签区域显示提示
      const feeTypeTagsContainer = document.querySelector('.fee-type-tags-container');
      if (feeTypeTagsContainer) {
        const warningDiv = document.createElement('div');
        warningDiv.className = 'unmatched-fee-types-warning';
        warningDiv.style.marginTop = '10px';
        warningDiv.style.padding = '10px';
        warningDiv.style.backgroundColor = '#fff3cd';
        warningDiv.style.border = '1px solid #ffeeba';
        warningDiv.style.borderRadius = '4px';
        warningDiv.style.color = '#856404';
        
        warningDiv.innerHTML = `
          <p><strong>提示：</strong>以下费用类型在系统中不存在，建议创建：</p>
          <ul>${unmatchedFeeTypes.map(ft => `<li>${ft}</li>`).join('')}</ul>
          <p><a href="/admin/fee_types/new" target="_blank" class="button" style="display:inline-block; padding:5px 10px; background-color:#007bff; color:white; text-decoration:none; border-radius:3px;">创建费用类型</a></p>
        `;
        
        // 检查是否已经存在警告，如果存在则替换，否则添加
        const existingWarning = feeTypeTagsContainer.querySelector('.unmatched-fee-types-warning');
        if (existingWarning) {
          feeTypeTagsContainer.replaceChild(warningDiv, existingWarning);
        } else {
          feeTypeTagsContainer.appendChild(warningDiv);
        }
      }
    }
    
    // 获取这些费用类型对应的问题类型
    const relevantProblemTypes = [];
    const matchedFeeTypeIds = matchedFeeTypes.map(ft => ft.id);
    
    // 使用Set来防止重复的问题类型
    const problemTypeSet = new Set();
    
    appState.allProblemTypes.forEach(problemType => {
      // 如果问题类型关联的费用类型在匹配列表中，则包含
      if (problemType.fee_type_id && matchedFeeTypeIds.includes(problemType.fee_type_id)) {
        // 使用问题类型ID作为唯一标识，防止重复
        const problemTypeKey = problemType.id.toString();
        if (!problemTypeSet.has(problemTypeKey)) {
          problemTypeSet.add(problemTypeKey);
          relevantProblemTypes.push(problemType);
        }
      }
    });
    
    debugLog('相关问题类型数量:', relevantProblemTypes.length);
    
    // 如果没有找到相关问题类型，显示提示信息
    if (relevantProblemTypes.length === 0) {
      debugLog('未找到相关问题类型');
      return [];
    }
    
    return relevantProblemTypes;
  }
  
  // 渲染问题类型复选框
  function renderProblemTypeCheckboxes(problemTypes) {
    debugLog('渲染问题类型复选框...');
    
    // 创建一个分组容器
    const sectionDiv = document.createElement('div');
    sectionDiv.className = 'problem-type-section';
    
    // 创建费用类型标题
    const feeTypeTitle = document.createElement('h5');
    feeTypeTitle.textContent = `已选费用类型: ${Array.from(appState.uniqueFeeTypes).join(', ')}`;
    sectionDiv.appendChild(feeTypeTitle);
    
    // 创建问题类型复选框容器
    const checkboxContainer = document.createElement('div');
    checkboxContainer.className = 'problem-type-checkboxes';
    
    // 创建问题类型复选框
    problemTypes.forEach(problemType => {
      const checkboxDiv = document.createElement('div');
      checkboxDiv.className = 'problem-type-checkbox';
      
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.id = `problem_type_${problemType.id}`;
      checkbox.name = `${formType}_work_order[problem_type_ids][]`;
      checkbox.value = problemType.id;
      
      // 添加事件监听器，当选择问题类型时重新验证
      checkbox.addEventListener('change', function() {
        if (appState.validationErrors.length > 0) {
          validateFormState();
          renderValidationErrors();
        }
      });
      
      const label = document.createElement('label');
      label.htmlFor = `problem_type_${problemType.id}`;
      
      // 创建问题类型信息容器
      const problemTypeInfoDiv = document.createElement('div');
      problemTypeInfoDiv.className = 'problem-type-info';
      
      // 创建标题元素
      const titleDiv = document.createElement('div');
      titleDiv.className = 'problem-type-title';
      
      // 构建显示名称
      if (problemType.display_name) {
        titleDiv.textContent = problemType.display_name;
      } else if (problemType.code && problemType.title) {
        titleDiv.textContent = `${problemType.code} - ${problemType.title}`;
      } else {
        titleDiv.textContent = problemType.title || `问题类型 #${problemType.id}`;
      }
      
      // 创建SOP描述元素
      const sopDescDiv = document.createElement('div');
      sopDescDiv.className = 'problem-type-sop-description';
      sopDescDiv.innerHTML = `<strong>SOP描述:</strong> ${problemType.sop_description || '无'}`;
      
      // 创建标准处理元素
      const standardHandlingDiv = document.createElement('div');
      standardHandlingDiv.className = 'problem-type-standard-handling';
      standardHandlingDiv.innerHTML = `<strong>标准处理:</strong> ${problemType.standard_handling || '无'}`;
      
      // 将所有元素添加到信息容器
      problemTypeInfoDiv.appendChild(titleDiv);
      problemTypeInfoDiv.appendChild(sopDescDiv);
      problemTypeInfoDiv.appendChild(standardHandlingDiv);
      
      // 将复选框和信息容器添加到复选框div
      checkboxDiv.appendChild(checkbox);
      checkboxDiv.appendChild(problemTypeInfoDiv);
      checkboxContainer.appendChild(checkboxDiv);
    });
    
    sectionDiv.appendChild(checkboxContainer);
    problemTypesWrapper.appendChild(sectionDiv);
  }
  
  // 表单验证
  function validateForm(event) {
    debugLog('验证表单...');
    
    // 验证表单状态
    const isValid = validateFormState();
    
    // 如果验证失败，阻止表单提交
    if (!isValid) {
      event.preventDefault();
      renderValidationErrors();
      return false;
    }
    
    return true;
  }
  
  // 验证表单状态
  function validateFormState() {
    debugLog('验证表单状态...');
    
    // 重置验证状态
    appState.validationErrors = [];
    appState.isFormValid = true;
    
    // 检查是否选择了费用明细
    if (appState.selectedFeeDetails.length === 0) {
      appState.validationErrors.push('请至少选择一个费用明细');
      appState.isFormValid = false;
    }
    
    // 检查处理意见
    if (!appState.processingOpinion) {
      appState.validationErrors.push('请选择处理意见');
      appState.isFormValid = false;
    }
    
    // 如果处理意见为"无法通过"，检查是否选择了问题类型或填写了审核意见
    if (appState.processingOpinion === '无法通过') {
      const problemTypeCheckboxes = document.querySelectorAll(`input[name="${formType}_work_order[problem_type_ids][]"]:checked`);
      const auditComment = auditCommentField ? auditCommentField.value.trim() : '';
      
      if (problemTypeCheckboxes.length === 0 && auditComment === '') {
        appState.validationErrors.push('当处理意见为"无法通过"时，需选择问题类型或填写审核意见');
        appState.isFormValid = false;
      }
    }
    
    return appState.isFormValid;
  }
  
  // 渲染验证错误
  function renderValidationErrors() {
    debugLog('渲染验证错误...');
    
    if (!validationErrorsContainer) {
      console.error('验证错误容器未找到');
      return;
    }
    
    // 清空容器
    validationErrorsContainer.innerHTML = '';
    
    // 如果没有错误，隐藏容器
    if (appState.validationErrors.length === 0) {
      validationErrorsContainer.style.display = 'none';
      return;
    }
    
    // 显示容器
    validationErrorsContainer.style.display = 'block';
    
    // 创建错误列表
    const errorList = document.createElement('ul');
    
    // 添加错误项
    appState.validationErrors.forEach(error => {
      const errorItem = document.createElement('li');
      errorItem.textContent = error;
      errorList.appendChild(errorItem);
    });
    
    // 添加到容器
    validationErrorsContainer.appendChild(errorList);
  }
  
  // 检查API端点配置
  function checkApiEndpoints() {
    debugLog('检查API端点配置...');
    
    // 检查费用类型API
    fetch('/admin/fee_types.json', { method: 'HEAD' })
      .then(response => {
        debugLog('费用类型API检查结果:', response.status, response.statusText);
      })
      .catch(error => {
        console.error('费用类型API检查失败:', error);
      });
    
    // 检查问题类型API
    fetch('/admin/problem_types.json', { method: 'HEAD' })
      .then(response => {
        debugLog('问题类型API检查结果:', response.status, response.statusText);
      })
      .catch(error => {
        console.error('问题类型API检查失败:', error);
      });
  }
});