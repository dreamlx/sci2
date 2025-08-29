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
    
    // 获取选中费用明细的会议类型和费用类型
    const selectedMeetingTypes = new Set();
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
        selectedMeetingTypes.add(exactMatch.meeting_type);
      } else {
        // 如果没有找到匹配，记录未匹配的费用类型
        unmatchedFeeTypes.push(feeTypeName);
      }
    });
    
    debugLog('匹配到的费用类型:', matchedFeeTypes);
    debugLog('选中的会议类型:', Array.from(selectedMeetingTypes));
    debugLog('未匹配到的费用类型:', unmatchedFeeTypes);
    
    // 如果有未匹配的费用类型，显示提示
    if (unmatchedFeeTypes.length > 0) {
      showUnmatchedFeeTypesWarning(unmatchedFeeTypes);
    }
    
    // 获取相关的问题类型
    const relevantProblemTypes = [];
    const matchedFeeTypeIds = matchedFeeTypes.map(ft => ft.id);
    
    // 使用Set来防止重复的问题类型
    const problemTypeSet = new Set();
    
    appState.allProblemTypes.forEach(problemType => {
      if (!problemType.fee_type_id) return;
      
      const feeType = appState.allFeeTypes.find(ft => ft.id === problemType.fee_type_id);
      if (!feeType) return;
      
      // 检查是否应该包含此问题类型
      let shouldInclude = false;
      let category = 'specific';
      
      // 通用问题类型：fee_type.code 以 GENERAL 开头的所有问题类型
      if (feeType.code && feeType.code.startsWith('GENERAL')) {
        shouldInclude = true;
        category = 'general';
        debugLog('找到通用问题类型:', problemType.title, '费用类型代码:', feeType.code);
      }
      // 特定问题类型：只显示与选中费用类型匹配的
      else if (matchedFeeTypeIds.includes(feeType.id)) {
        shouldInclude = true;
        category = 'specific';
      }
      
      if (shouldInclude) {
        // 使用问题类型ID作为唯一标识，防止重复
        const problemTypeKey = problemType.id.toString();
        if (!problemTypeSet.has(problemTypeKey)) {
          problemTypeSet.add(problemTypeKey);
          
          // 标记问题类型的类别
          const enhancedProblemType = {
            ...problemType,
            category: category,
            meeting_type: feeType.meeting_type,
            fee_type_title: feeType.title
          };
          
          relevantProblemTypes.push(enhancedProblemType);
        }
      }
    });
    
    debugLog('相关问题类型数量:', relevantProblemTypes.length);
    debugLog('问题类型详情:', relevantProblemTypes);
    
    // 如果没有找到相关问题类型，显示提示信息
    if (relevantProblemTypes.length === 0) {
      debugLog('未找到相关问题类型');
      return [];
    }
    
    return relevantProblemTypes;
  }
  
  // 显示未匹配费用类型警告
  function showUnmatchedFeeTypesWarning(unmatchedFeeTypes) {
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
  
  // 渲染问题类型复选框
  function renderProblemTypeCheckboxes(problemTypes) {
    debugLog('渲染问题类型复选框，按类别分组...');
    
    if (!problemTypesWrapper) {
      debugLog('问题类型容器不存在');
      return;
    }
    
    // 清空容器
    problemTypesWrapper.innerHTML = '';
    
    // 按类别分组
    const specificProblems = problemTypes.filter(p => p.category === 'specific');
    const generalProblems = problemTypes.filter(p => p.category === 'general');
    
    // 按费用类型进一步分组特定问题
    const specificByFeeType = {};
    specificProblems.forEach(problem => {
      const feeTypeKey = problem.fee_type_title || problem.meeting_type || '其他';
      if (!specificByFeeType[feeTypeKey]) {
        specificByFeeType[feeTypeKey] = [];
      }
      specificByFeeType[feeTypeKey].push(problem);
    });
    
    // 渲染特定问题类型
    Object.keys(specificByFeeType).forEach(feeTypeTitle => {
      const problems = specificByFeeType[feeTypeTitle];
      renderProblemGroup(`📋 ${feeTypeTitle}相关问题`, problems, 'specific');
    });
    
    // 渲染通用问题类型（只有学术会议才有）
    if (generalProblems.length > 0) {
      renderProblemGroup('🌐 学术会议通用问题', generalProblems, 'general');
    }
  }
  
  // 渲染问题类型分组
  function renderProblemGroup(groupTitle, problems, groupType) {
    if (problems.length === 0) return;
    
    // 创建分组容器
    const groupDiv = document.createElement('div');
    groupDiv.className = `problem-type-group ${groupType}-problems`;
    
    // 创建分组标题（可点击折叠）
    const titleDiv = document.createElement('h5');
    titleDiv.className = 'problem-group-title collapsible';
    
    // 添加折叠图标和标题文本
    const iconSpan = document.createElement('span');
    iconSpan.className = 'collapse-icon';
    iconSpan.textContent = '▼'; // 默认展开状态
    
    const titleText = document.createElement('span');
    titleText.textContent = `${groupTitle} (${problems.length}个)`;
    
    titleDiv.appendChild(iconSpan);
    titleDiv.appendChild(titleText);
    
    // 创建问题复选框容器
    const checkboxContainer = document.createElement('div');
    checkboxContainer.className = 'problem-checkboxes';
    checkboxContainer.style.display = 'block'; // 默认展开
    
    // 添加点击事件来切换折叠状态
    titleDiv.addEventListener('click', function() {
      const isCollapsed = checkboxContainer.style.display === 'none';
      
      if (isCollapsed) {
        // 展开
        checkboxContainer.style.display = 'block';
        iconSpan.textContent = '▼';
        titleDiv.classList.remove('collapsed');
      } else {
        // 折叠
        checkboxContainer.style.display = 'none';
        iconSpan.textContent = '▶';
        titleDiv.classList.add('collapsed');
      }
    });
    
    // 渲染每个问题类型
    problems.forEach(problemType => {
      const problemItem = renderProblemTypeCheckbox(problemType);
      checkboxContainer.appendChild(problemItem);
    });
    
    groupDiv.appendChild(titleDiv);
    groupDiv.appendChild(checkboxContainer);
    problemTypesWrapper.appendChild(groupDiv);
  }
  
  // 渲染单个问题类型复选框
  function renderProblemTypeCheckbox(problemType) {
    const itemDiv = document.createElement('div');
    itemDiv.className = 'problem-type-item';
    
    // 创建标签容器
    const label = document.createElement('label');
    label.className = 'problem-type-label';
    label.htmlFor = `problem_type_${problemType.id}`;
    
    // 创建复选框
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.id = `problem_type_${problemType.id}`;
    checkbox.className = 'problem-type-checkbox';
    checkbox.value = problemType.id;
    
    // 动态获取表单参数名
    const paramName = getWorkOrderParamName();
    checkbox.name = `${paramName}[problem_type_ids][]`;
    
    // 检查是否已选中
    if (appState.selectedProblemTypeIds && appState.selectedProblemTypeIds.includes(problemType.id.toString())) {
      checkbox.checked = true;
    }
    
    // 添加事件监听器
    checkbox.addEventListener('change', function() {
      if (appState.validationErrors && appState.validationErrors.length > 0) {
        validateFormState();
        renderValidationErrors();
      }
    });
    
    // 创建问题标题
    const titleSpan = document.createElement('span');
    titleSpan.className = 'problem-type-title';
    titleSpan.textContent = problemType.title || `问题类型 #${problemType.id}`;
    
    // 创建详细信息容器
    const detailsDiv = document.createElement('div');
    detailsDiv.className = 'problem-type-details';
    
    // SOP描述
    if (problemType.sop_description) {
      const sopDiv = document.createElement('div');
      sopDiv.className = 'sop-description';
      sopDiv.textContent = problemType.sop_description;
      detailsDiv.appendChild(sopDiv);
    }
    
    // 标准处理
    if (problemType.standard_handling) {
      const handlingDiv = document.createElement('div');
      handlingDiv.className = 'standard-handling';
      handlingDiv.textContent = problemType.standard_handling;
      detailsDiv.appendChild(handlingDiv);
    }
    
    // 组装标签
    label.appendChild(checkbox);
    label.appendChild(titleSpan);
    label.appendChild(detailsDiv);
    
    itemDiv.appendChild(label);
    return itemDiv;
  }
  
  // 获取工单参数名称
  function getWorkOrderParamName() {
    // 从当前路径或表单中推断参数名
    const path = window.location.pathname;
    if (path.includes('audit_work_orders')) {
      return 'audit_work_order';
    } else if (path.includes('communication_work_orders')) {
      return 'communication_work_order';
    }
    return 'work_order'; // 默认值
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