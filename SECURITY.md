# Security Policy

## Supported versions

| Version | Supported |
| :------ | :-------: |
| Latest 2.x release | ✅ |
| Previous minor release | ✅ |
| All other releases | ❌ |

## Reporting a vulnerability

Please use [GitHub's private vulnerability reporting](
https://github.com/ErwinM/acts_as_tenant/security/advisories/new), or email the
maintainers listed in `acts_as_tenant.gemspec`. Please do not open public
issues for security problems.

Include when possible:

- the acts_as_tenant version and Rails version
- a minimal reproduction (script or steps) against the dummy app in `spec/dummy`
- the affected file/line if known
- your assessment of impact and severity

## What we consider security issues

- Tenant isolation breaks reachable through the gem's documented API or
  default configuration (e.g. #378, #384)
- Crashes or unhandled exceptions remotely triggerable by unauthenticated
  input (e.g. crafted Host headers, form-supplied polymorphic type columns)
- Cross-request/cross-thread tenant leakage in supported Rails and job-runner

## What we do not consider security issues

- Applications deliberately disabling `require_tenant` and exposing unscoped
  models — this is a documented configuration choice
- Issues that require write access to your job/queue backend (Redis) or
  application code changes to trigger
- Bugs in unreleased branches, or in an application's own tenant-resolution
  code

## Disclosure

We follow coordinated disclosure. Reports are acknowledged within 7 days.
We aim to fix accepted issues within 90 days of the report, coordinating
publication (and CVE issuance via GitHub) with the reporter. Reporters are
credited in the advisory if they wish.
