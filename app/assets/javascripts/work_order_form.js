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

  // Get DOM elements
  const form = document.querySelector('form.formtastic');
  const feeDetailCheckboxes = document.querySelectorAll('.fee-detail-checkbox');
  const problemTypesContainer = document.getElementById('problem-types-container');
  const problemTypesWrapper = document.querySelector('.problem-types-wrapper');
  const validationErrorsContainer = document.getElementById('validation-errors');
  
  // New state management
  const appState = {
    selectedFeeDetailIds: new Set(),
    reimbursementId: null
  };

  // --- Initialization ---
  function initializeApp() {
    debugLog('App initializing...');
    const reimbursementInput = document.querySelector('input[name*="[reimbursement_id]"]');
    if (!reimbursementInput) {
      console.error('Reimbursement ID input not found!');
      return;
    }
    appState.reimbursementId = reimbursementInput.value;
    
    setupEventListeners();
    updateInitialState();
  }

  function setupEventListeners() {
    debugLog('Setting up event listeners...');
    feeDetailCheckboxes.forEach(checkbox => {
      checkbox.addEventListener('change', handleFeeDetailChange);
    });

    if (form) {
      form.addEventListener('submit', validateForm);
    }
    
    // Listen for opinion changes if it's an audit form
    if (isAuditForm) {
      const opinionRadios = document.querySelectorAll('.processing-opinion-radio');
      opinionRadios.forEach(radio => radio.addEventListener('change', handleProcessingOpinionChange));
    }
  }
  
  function updateInitialState() {
    feeDetailCheckboxes.forEach(checkbox => {
      if (checkbox.checked) {
        appState.selectedFeeDetailIds.add(checkbox.value);
      }
    });
    handleFeeDetailChange(); // Trigger initial load if any are checked
  }

  // --- Event Handlers ---
  function handleFeeDetailChange() {
    debugLog('Fee detail selection changed.');
    
    // Update selected IDs
    appState.selectedFeeDetailIds.clear();
    feeDetailCheckboxes.forEach(checkbox => {
      if (checkbox.checked) {
        appState.selectedFeeDetailIds.add(checkbox.value);
      }
    });

    if (appState.selectedFeeDetailIds.size > 0) {
      fetchAndRenderProblemTypes();
    } else {
      hideProblemTypes();
    }
  }

  function handleProcessingOpinionChange(event) {
    validateFormState();
    const selectedValue = event.target.value;
    if (selectedValue === '无法通过') {
      showProblemTypes();
    } else {
      hideProblemTypes();
    }
  }

  // --- API Call ---
  function fetchAndRenderProblemTypes() {
    const feeDetailIds = Array.from(appState.selectedFeeDetailIds).join(',');
    const url = `/admin/problem_type_queries/for_fee_details?reimbursement_id=${appState.reimbursementId}&fee_detail_ids=${feeDetailIds}`;
    
    debugLog('Fetching problem types from:', url);
    
    showProblemTypes(); // Show container with a loading message
    problemTypesWrapper.innerHTML = '<p>正在加载问题类型...</p>';
    
    fetch(url, {
      headers: {
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`API request failed with status ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      debugLog('Received problem types:', data);
      renderProblemTypeCheckboxes(data);
    })
    .catch(error => {
      console.error('Error fetching problem types:', error);
      problemTypesWrapper.innerHTML = '<p class="error">无法加载问题类型。请检查网络连接或联系管理员。</p>';
    });
  }

  // --- UI Rendering ---
  function showProblemTypes() {
    if (problemTypesContainer) {
      problemTypesContainer.style.display = 'block';
    }
  }

  function hideProblemTypes() {
    if (problemTypesContainer) {
      problemTypesContainer.style.display = 'none';
      problemTypesWrapper.innerHTML = '';
    }
  }

  function renderProblemTypeCheckboxes(problemTypes) {
    problemTypesWrapper.innerHTML = ''; // Clear previous content

    if (!problemTypes || problemTypes.length === 0) {
      problemTypesWrapper.innerHTML = '<p>没有找到相关的问题类型。</p>';
      return;
    }
    
    const specificProblems = problemTypes.filter(p => p.fee_type.expense_type_code !== '00');
    const generalProblems = problemTypes.filter(p => p.fee_type.expense_type_code === '00');
    
    if (specificProblems.length > 0) {
      renderProblemGroup('特定问题', specificProblems, 'specific');
    }
    
    if (generalProblems.length > 0) {
      renderProblemGroup('通用问题', generalProblems, 'general');
    }
  }

  function renderProblemGroup(groupTitle, problems, groupType) {
    const section = document.createElement('div');
    section.className = 'problem-type-section';
    
    const title = document.createElement('h5');
    title.textContent = groupTitle;
    section.appendChild(title);
    
    const checkboxesContainer = document.createElement('div');
    checkboxesContainer.className = 'problem-type-checkboxes';
    
    problems.forEach(problem => {
      const checkboxDiv = renderProblemTypeCheckbox(problem);
      checkboxesContainer.appendChild(checkboxDiv);
    });
    
    section.appendChild(checkboxesContainer);
    problemTypesWrapper.appendChild(section);
  }
  
  function renderProblemTypeCheckbox(problemType) {
    const paramName = getWorkOrderParamName();
    const checkboxId = `problem_type_${problemType.id}`;
    
    const container = document.createElement('div');
    container.className = 'problem-type-checkbox';
    
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.name = `${paramName}[problem_type_ids][]`;
    input.id = checkboxId;
    input.value = problemType.id;
    
    const label = document.createElement('label');
    label.htmlFor = checkboxId;
    label.textContent = problemType.display_name;
    
    container.appendChild(input);
    container.appendChild(label);
    
    return container;
  }
  
  function getWorkOrderParamName() {
    return isAuditForm ? 'audit_work_order' : 'communication_work_order';
  }

  // --- Validation ---
  function validateForm(event) {
    const errors = validateFormState();
    if (errors.length > 0) {
      event.preventDefault();
      renderValidationErrors(errors);
      // Highlight the first problematic area
      const firstErrorArea = document.querySelector(errors[0].selector);
      if (firstErrorArea) {
        firstErrorArea.classList.add('highlight-error');
        firstErrorArea.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }
  }

  function validateFormState() {
    const errors = [];
    
    // This validation is only for audit forms
    if (!isAuditForm) {
      return errors;
    }
    
    const opinion = document.querySelector('.processing-opinion-radio:checked');
    const selectedProblemTypes = document.querySelectorAll('input[name*="[problem_type_ids][]"]:checked');
    const auditComment = document.getElementById('audit_comment_field');

    if (opinion && opinion.value === '无法通过') {
      if (selectedProblemTypes.length === 0 && auditComment.value.trim() === '') {
        errors.push({ 
          message: '当处理意见为“无法通过”时，必须选择至少一个问题类型或填写审核意见。',
          selector: '#problem-types-container'
        });
      }
    }
    
    if (appState.selectedFeeDetailIds.size === 0) {
      errors.push({
        message: '请至少选择一个费用明细。',
        selector: '.fee-details-selection'
      });
    }

    renderValidationErrors(errors);
    return errors;
  }

  function renderValidationErrors(errors) {
    // Clear previous highlights
    document.querySelectorAll('.highlight-error').forEach(el => el.classList.remove('highlight-error'));
    
    if (errors.length > 0) {
      validationErrorsContainer.innerHTML = errors.map(e => `<p>${e.message}</p>`).join('');
      validationErrorsContainer.style.display = 'block';
    } else {
      validationErrorsContainer.innerHTML = '';
      validationErrorsContainer.style.display = 'none';
    }
  }

  // --- Initializer Call ---
  initializeApp();
});