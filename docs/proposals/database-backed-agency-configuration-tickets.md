# Jira Tickets: Database-Backed Agency Configuration

Parent epic for all tickets below.

---

## Epic: Migrate Agency Configuration to Database

**Summary:** Replace YAML-based agency configuration with a database-backed system using bedrock defaults + per-agency overrides

**Description:**
Agency configuration currently lives in a static YAML file (`config/client-agency-config.yml`). This requires a code deploy for every settings change and offers no self-service for state admins. This epic migrates configuration to a database table with a "bedrock + override" inheritance model, where a bedrock record defines defaults and each agency record only stores its overrides. A write-through cache ensures zero DB queries on the hot path.

See proposal: [link to proposal doc]

---

## Ticket 1: Create `agency_configurations` table and model

**Type:** Story
**Summary:** Create the `agency_configurations` database table, `AgencyConfiguration` model, and bedrock inheritance logic

**Description:**

Create the foundational data layer for database-backed agency configuration.

**Acceptance criteria:**
- [ ] Migration creates `agency_configurations` table with all columns defined in the proposal (display/identity, feature flags, income verification, transmission, SSO, weekly reporting, applicant attributes, activity types)
- [ ] `AgencyConfiguration` model includes:
  - Validations (agency_id presence/uniqueness, pay_income_days inclusion, etc.)
  - `effective(attr)` method that falls back to bedrock when a value is nil
  - `effective_settings` method that merges agency overrides onto bedrock defaults
- [ ] `is_bedrock` flag distinguishes the bedrock record from agency records
- [ ] Model specs cover:
  - Bedrock record returns its own values directly
  - Agency record returns its own value when set
  - Agency record falls back to bedrock when value is nil
  - Validations reject invalid `pay_income_days` and `application_reporting_months` values
  - Bedrock requires `agency_name` and `transmission_method`; agency records do not
- [ ] JSONB columns (`applicant_attributes`, `activity_types`, `transmission_custom_headers`) use full replacement, not deep merge

**Notes:**
- Secret columns (`transmission_sftp_password`, `sso_client_secret`) should use `t.text` (not `t.string`) to accommodate encrypted ciphertext
- Use `public_send(attr)` instead of `read_attribute(attr)` in the `effective` method to support Rails encrypted attributes

---

## Ticket 2: Create `AgencyConfigurationAdapter` compatibility layer

**Type:** Story
**Summary:** Create an adapter class that presents the same interface as `ClientAgencyConfig::ClientAgency` but reads from the database

**Depends on:** Ticket 1

**Description:**

The rest of the app accesses agency config through methods like `current_agency.pay_income_days`, `current_agency.transmission_method_configuration`, `current_agency.sso`, etc. The adapter reconstructs these hash/object shapes from discrete database columns so that no downstream code needs to change.

**Acceptance criteria:**
- [ ] `AgencyConfigurationAdapter` delegates simple scalar attributes directly to the model
- [ ] `pay_income_days` returns `{ w2: ..., gig: ... }` hash from discrete columns
- [ ] `transmission_method_configuration` reconstructs the hash that transmitters expect (with keys like `"user"`, `"password"`, `"json_api_url"`, etc.), compacting nil values
- [ ] `sso` returns the hash transmitters expect (with keys `"client_id"`, `"client_secret"`, etc.), or nil if no SSO configured
- [ ] `weekly_report` returns `{ "recipient" => ..., "report_variant" => ... }` or nil
- [ ] `applicant_attributes` and `activity_types` pass through from `effective()` with appropriate defaults
- [ ] `id` returns `agency_id` from the model
- [ ] Adapter specs verify that each method produces output matching what the current YAML-based `ClientAgency` class produces for each existing agency

---

## Ticket 3: Implement write-through caching

**Type:** Story
**Summary:** Add write-through caching so the hot path reads are a single `Rails.cache.fetch` with zero DB queries

**Depends on:** Ticket 2

**Description:**

The current YAML system loads once at boot and lives in memory. The DB-backed system must be equally fast on the read path. Implement write-through caching: when an `AgencyConfiguration` record is saved, eagerly compute the effective adapter and write it to `Rails.cache`. Reads hit the cache first and fall through to DB only on a miss.

**Acceptance criteria:**
- [ ] `after_save` callback on `AgencyConfiguration` writes the computed `AgencyConfigurationAdapter` to cache
- [ ] When the bedrock record is saved, cache is rebuilt for all agency records (not just bedrock)
- [ ] `agency_ids` list is also cached and invalidated on save
- [ ] Cache key format: `agency_config/{agency_id}`
- [ ] Boot-time cache warming: an initializer calls `AgencyConfiguration.find_each(&:cache_effective_adapter)` so the first request is never slow
- [ ] `Rails.cache.fetch` block falls through to DB read on cache miss (graceful degradation)
- [ ] Specs verify: saving an agency record updates its cache; saving bedrock updates all agency caches; cache miss triggers DB read

---

## Ticket 4: Seed bedrock and agency records from current YAML

**Type:** Story
**Summary:** Write a data migration that translates the current YAML config into database records

**Depends on:** Ticket 1

**Description:**

Create a data migration (or seed task) that reads the current `client-agency-config.yml` values and creates corresponding `AgencyConfiguration` records. The bedrock record should capture the common defaults. Each agency record should only store values that differ from bedrock.

**Acceptance criteria:**
- [ ] Bedrock record created with sensible defaults (pay_income_days 90/90, invitation_valid_days 14, application_reporting_months 1, staff_portal_enabled false, pilot_ended false, generic_links_disabled false, pinwheel/argyle environment "sandbox", transmission_method "shared_email")
- [ ] `az_des` record created with only its overrides (pay_income_days_gig 182, invitation_valid_days 10, generic_links_disabled true, transmission_method "sftp", SFTP config, SSO config, weekly report config, etc.)
- [ ] `la_ldh` record created with only its overrides
- [ ] `sandbox` record created with only its overrides
- [ ] Migration is idempotent (safe to run multiple times)
- [ ] Secrets are populated from ENV variables during migration
- [ ] After migration, accessing each agency through the adapter produces identical output to the current YAML-based system

---

## Ticket 5: Wire up DB-backed `ClientAgencyConfig` as the config source

**Type:** Story
**Summary:** Replace the YAML-loading `ClientAgencyConfig` with the new DB-backed version so the app reads configuration from the database

**Depends on:** Tickets 2, 3, 4

**Description:**

Update `config/application.rb` to use the new `ClientAgencyConfig` that reads from DB + cache instead of YAML. This is the cutover point. The adapter ensures the same interface, so no other code should need to change.

**Acceptance criteria:**
- [ ] `Rails.application.config.client_agencies` uses the new DB-backed `ClientAgencyConfig`
- [ ] `ClientAgencyConfig#[]` returns an `AgencyConfigurationAdapter` (via cache)
- [ ] `ClientAgencyConfig#client_agency_ids` returns agency IDs from DB (via cache)
- [ ] All existing controller, model, and service specs continue to pass without modification
- [ ] The old YAML file is kept in the repo (not deleted yet) as a reference
- [ ] Smoke test: boot the app locally, verify `current_agency` works correctly for each agency

---

## Ticket 6: Add encrypted attributes for secret columns

**Type:** Story
**Summary:** Protect sensitive configuration values (SFTP password, SSO client secret) using Rails encrypted attributes

**Depends on:** Ticket 5

**Description:**

Secret values are now stored in discrete database columns. Use Rails `encrypts` to encrypt them at rest. The app already has the three required encryption ENV vars (`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, etc.).

**Acceptance criteria:**
- [ ] `AgencyConfiguration` model declares `encrypts` for: `transmission_sftp_password`, `sso_client_secret`, and any other columns identified as secrets
- [ ] Secret columns use `t.text` type (not `t.string`) to accommodate ciphertext length
- [ ] `effective` method uses `public_send` (not `read_attribute`) so decryption works through the inheritance chain
- [ ] Existing specs continue to pass
- [ ] Verify in Rails console: writing a secret value and reading it back returns the plaintext; inspecting the raw DB column shows ciphertext

---

## Ticket 7: Replace static route constraints with dynamic lookup

**Type:** Story
**Summary:** Replace boot-time `Regexp.union` route constraints with a dynamic constraint class that checks the database

**Depends on:** Ticket 5

**Description:**

Route constraints currently use `Regexp.union(client_agency_ids)` evaluated at boot time. New agencies added to the DB won't be recognized until restart. Replace with an `AgencyRouteConstraint` class that checks existence dynamically.

**Acceptance criteria:**
- [ ] `AgencyRouteConstraint` class with `self.matches?(request)` that checks `AgencyConfiguration.exists?(agency_id: ...)`
- [ ] Routes updated to use the new constraint class instead of `Regexp.union`
- [ ] Both CBV and Activity flow route scopes updated
- [ ] Existing route specs pass
- [ ] Verify: adding a new agency record to the DB makes its routes accessible without restart

**Notes:**
- The constraint hits the DB, but this only fires for requests matching the route pattern (not every request). Could also check the cached agency_ids list instead if preferred.

---

## Ticket 8: Parallel validation period

**Type:** Story
**Summary:** Run YAML and DB config sources in parallel, logging discrepancies, to validate correctness before full cutover

**Depends on:** Ticket 5

**Description:**

Before removing the YAML file, run both config sources simultaneously for a validation period. On each config read, compare the DB-backed result to the YAML-backed result and log any discrepancies. This catches migration errors before they affect users.

**Acceptance criteria:**
- [ ] Wrapper class reads from both YAML and DB sources
- [ ] Compares output for each accessed attribute
- [ ] Logs warnings for any discrepancy (attribute name, YAML value, DB value, agency ID)
- [ ] App uses the DB value as the primary source (YAML is shadow/comparison only)
- [ ] Easy to remove: a feature flag or ENV var disables the comparison once validated
- [ ] After a clean validation period with no discrepancies, this ticket is considered done

---

## Ticket 9: Remove YAML config and clean up

**Type:** Story
**Summary:** Remove the YAML configuration file, old loader code, and parallel validation wrapper after successful migration

**Depends on:** Ticket 8

**Description:**

Final cleanup once the DB-backed system has been validated in production.

**Acceptance criteria:**
- [ ] `config/client-agency-config.yml` removed
- [ ] Old YAML-loading `ClientAgencyConfig` code removed (the `ERB.new File.read` path, `ClientAgency` inner class)
- [ ] Parallel validation wrapper removed
- [ ] Agency-specific ENV variables that were only used in the YAML (not by other parts of the system) are documented for removal from deployment config
- [ ] All specs pass
- [ ] No references to the old YAML file remain in the codebase
