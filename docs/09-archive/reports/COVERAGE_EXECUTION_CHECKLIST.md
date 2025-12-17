# Coverage Execution Checklist
**Target**: 65.85% coverage (+6.42% from current 59.43%)
**Recommended Path**: Fast Track (6-7 hours)

---

## ✅ Phase 1: Quick Wins (2-3 hours, +2.66%)

### Services (2 files, 2h)
- [ ] `app/services/express_receipt_work_order_service.rb` (1h, +0.37%)
  - Spec: `spec/services/express_receipt_work_order_service_spec.rb`
  - Test: Core workflow, error handling, validations

- [ ] `app/services/shared/command_result.rb` (1h, +0.33%)
  - Spec: `spec/services/shared/command_result_spec.rb`
  - Test: Success/failure cases, data structure

### Controllers (3 files, 1.5h)
- [ ] `app/controllers/application_controller.rb` (1h, +0.31%)
  - Spec: `spec/controllers/application_controller_spec.rb`
  - Test: Base controller methods, filters, helpers

- [ ] `app/controllers/admin/problem_type_queries_controller.rb` (0.5h, +0.36%)
  - Spec: `spec/controllers/admin/problem_type_queries_controller_spec.rb`
  - Test: Index, create actions

- [ ] `app/controllers/admin/base_controller.rb` (0.5h, +0.14%)
  - Spec: `spec/controllers/admin/base_controller_spec.rb`
  - Test: Admin authentication, authorization

### Models (7 files, 1h - batch test)
- [ ] `app/models/communication_record.rb` (0.3h, +0.26%)
  - Spec: `spec/models/communication_record_spec.rb`

- [ ] **Options Models (6 files, 0.7h total, +0.89%)**
  - [ ] `problem_type_options.rb` → `spec/models/problem_type_options_spec.rb`
  - [ ] `problem_description_options.rb` → `spec/models/problem_description_options_spec.rb`
  - [ ] `initiator_role_options.rb` → `spec/models/initiator_role_options_spec.rb`
  - [ ] `communicator_role_options.rb` → `spec/models/communicator_role_options_spec.rb`
  - [ ] `communication_method_options.rb` → `spec/models/communication_method_options_spec.rb`
  - [ ] `processing_opinion_options.rb` → `spec/models/processing_opinion_options_spec.rb`
  - **Pattern**: All are enum-like option classes, use same test template

**Phase 1 Total**: 12 files, ~2.5h, +2.66% → **Reach 62.09%**

---

## 🔥 Phase 2: Core Business Logic (4-6 hours, +2.65%)

### Services (1 file, 3.5h)
- [ ] `app/services/simple_batch_reimbursement_import_service.rb` (3.5h, +2.07%)
  - Spec: `spec/services/simple_batch_reimbursement_import_service_spec.rb`
  - Test: Batch import logic, validation, error handling, edge cases
  - **Business Critical**: Core reimbursement processing

### Models (1 file, 2h)
- [ ] `app/models/ability.rb` (2h, +0.58%)
  - Spec: `spec/models/ability_spec.rb`
  - Test: CanCanCan authorization rules for all roles
  - **Business Critical**: Security and access control

**Phase 2 Total**: 2 files, ~5.5h, +2.65% → **Reach 64.74%**

---

## 🎯 Final Push to 65.85% (1-2 hours, +1.11%)

Choose **ANY 2-3** from remaining files to exceed target:

### Recommended Options
- [ ] `app/services/problem_type_query_service.rb` (2h, +1.07%)
  - Spec: `spec/services/problem_type_query_service_spec.rb`
  - **Recommended**: Pushes coverage to **66.21%** (exceeds target)

- [ ] `app/services/problem_code_migration_service.rb` (2h, +1.01%)
  - Spec: `spec/services/problem_code_migration_service_spec.rb`

- [ ] `app/models/import_performance.rb` (2h, +0.63%)
  - Spec: `spec/models/import_performance_spec.rb`

- [ ] `app/controllers/admin/communication_work_orders_controller.rb` (2h, +0.78%)
  - Spec: `spec/controllers/admin/communication_work_orders_controller_spec.rb`

---

## Validation Checklist

After each phase:
- [ ] Run tests: `COVERAGE=true bundle exec rspec`
- [ ] Check coverage report: `open coverage/index.html`
- [ ] Verify coverage percentage increase
- [ ] Ensure all tests pass (green)
- [ ] Commit changes with descriptive message

---

## Coverage Milestones

| Milestone | Coverage | Files Completed | Cumulative Gain |
|-----------|----------|-----------------|-----------------|
| Start | 59.43% | 0 | - |
| Phase 1 Complete | 62.09% | 12 | +2.66% |
| Phase 2 Complete | 64.74% | 14 | +5.31% |
| **Target Achieved** | **65.85%** | 15-16 | **+6.42%** |
| Stretch Goal | 66.21% | 16 | +6.78% |

---

## Quick Reference

### Test Template Locations
- Services: `spec/services/`
- Models: `spec/models/`
- Controllers: `spec/controllers/`
- Repositories: `spec/repositories/`

### Run Coverage
```bash
COVERAGE=true bundle exec rspec
```

### View Report
```bash
open coverage/index.html
```

### Run Specific Test
```bash
bundle exec rspec spec/services/[service_name]_spec.rb
```

---

## Tips for Success

1. **Start with Phase 1** - Build momentum with quick wins
2. **Validate incrementally** - Check coverage after each file
3. **Use templates** - Options models can share similar test structure
4. **Focus on critical paths** - Don't aim for 100% coverage on each file
5. **Document edge cases** - Note any complex scenarios for future reference

---

## Estimated Timeline

- **Day 1**: Phase 1 (2-3 hours) → 62.09%
- **Day 2**: Phase 2 (4-6 hours) → 64.74%
- **Day 3**: Final push (1-2 hours) → 66.21%+ ✓

**Total**: 7-11 hours over 3 days
