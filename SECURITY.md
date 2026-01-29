# Security Policy

## Scope
This repository contains security-sensitive smart contract primitives.
Please treat any suspected vulnerability as confidential until coordinated disclosure.

## Supported Versions
- Current development: `main`
- Released tags: see GitHub Releases

## Reporting a Vulnerability
Please report security issues privately.
Preferred channels (in order):
1. GitHub Security Advisories (recommended)
2. Email: 202547711+MissCyber9@users.noreply.github.com

Include:
- impact and threat scenario
- minimal reproduction steps
- affected commit/tag
- suggested mitigation (if known)

## What to Expect
- We will acknowledge receipt as soon as possible.
- We will triage and validate the report.
- We will coordinate a fix and release timeline.

## Hardening Practices (Project Posture)
- Foundry unit tests + invariants
- Tagged releases + provenance docs
- CI checks on every push/PR
- Minimal, composable primitives with explicit non-goals
