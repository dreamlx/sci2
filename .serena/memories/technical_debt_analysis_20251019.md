
# Project Analysis & Refactoring Plan Summary (2025-10-19)

## Key Findings

1.  **Massive ActiveAdmin Resources ("God" Objects):** Files like `app/admin/reimbursements.rb` are excessively large, mixing UI, controller logic, and business rules.
2.  **MVC Architecture Violations:** Business logic and database queries are improperly placed in ActiveAdmin resources, views, and models.
3.  **"Callback Hell" & Tight Coupling:** Heavy reliance on `after_create`/`after_save` callbacks creates a tangled, unpredictable web of model dependencies.
4.  **Complex Authorization:** The `Ability.rb` class is monolithic and difficult to manage, with auth logic also scattered in resources.
5.  **Duplicated Logic (STI):** The `WorkOrder` STI models have significant code duplication.
6.  **Poor Code Quality & Fragile Dependencies:** Numerous RuboCop offenses and severe `Gemfile` dependency conflicts indicate a lack of automated quality gates.

## AI-Driven Refactoring Strategy

A phased approach leveraging a fleet of AI coders, where I act as the architect/orchestrator.

*   **Phase 0: Foundation & Safety Net:**
    *   **DevOps Agent:** Resolve all `Gemfile` dependency issues.
    *   **Quality Engineer Agent:** Generate a baseline `.rubocop.yml` and a comprehensive RSpec test suite to cover existing behavior.

*   **Phase 1: Automated Cleanup Swarm:**
    *   Programmatically identify all auto-correctable RuboCop offenses.
    *   Deploy thousands of micro-AI agents in parallel to fix each offense individually.

*   **Phase 2: Surgical Service Layer Extraction:**
    *   Use a **(Generate -> Test -> Replace)** pattern with specialized AI agents:
        1.  **Refactoring Expert:** Extracts logic into a new Service Object.
        2.  **Quality Engineer:** In parallel, writes unit tests for the new service.
        3.  **Refactoring Expert:** Replaces the old logic with a call to the new, tested service.

*   **Phase 3: Architectural Refinement:**
    *   **System Architect Agent:** Extracts duplicated `WorkOrder` logic into a shared Rails Concern.
    *   **Security Engineer Agent:** Refactors the monolithic `Ability.rb` into a clear, role-based system.

*   **Phase 4: Comprehensive Validation:**
    *   Expand test coverage for all new services.
    *   Use AI to write system/integration tests that simulate user flows.
