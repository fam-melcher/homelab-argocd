# GitHub Copilot Agent Instructions (homelab-argocd)

These instructions are **for AI coding agents** (VS Code Copilot Agent, GitHub Copilot, etc.).
They are written as **hard rules + checklists**. Follow them exactly.

## 0) Project Context (constraints)

- **Repository purpose:** Reproducible Kubernetes cluster bootstrap using **ArgoCD** on **Kairos OS**.
- **Scope:** Infrastructure-layer only (CRDs, storage, networking, gateways). No application deployments.
- **Delivery model:** Terraform installs ArgoCD → ArgoCD syncs this repo → bootstrap components deploy.
- **Core principle:** **GitOps**. Git is the single source of truth.

If a request conflicts with GitOps (manual cluster mutation, unpinned versions, etc.), stop and propose a GitOps-compliant alternative.

---

## 1) 🚨 Safety Gate (OVERRIDES EVERYTHING)

### 1.1 Branch safety (MUST)

1. **MUST determine current branch before ANY change** (before editing files, running commands, staging, committing, or pushing):
   - `git branch --show-current`
2. **MUST NOT modify files on `main`.**
   - If current branch is `main`: **STOP** and create/switch to a feature branch first (see §2).
3. **MUST NOT push to `main`.**
   - Never run `git push origin main`.

### 1.2 Staging safety (MUST)

- **MUST NOT use bulk staging:**
  - Never use `git add .`
  - Never use `git add -A`
- **MUST stage explicit paths only**, e.g. `git add ./bootstrap/networking/metallb-config.yaml`.

### 1.3 “User tries to force main” rule (MUST)

If the user explicitly asks to work directly on `main`, require this confirmation phrase **verbatim**:

**`I CONFIRM DIRECT MAIN CHANGE`**

If the user does not provide it exactly, refuse and proceed with a feature branch workflow.

---

## 2) Standard Workflow (ALWAYS)

When starting work (unless already on a correct feature branch):

1. Ensure local main is current:
   - `git switch main`
   - `git pull origin main`

2. Create a new branch:
   - `git switch -c <type>/<description>`

3. Only then: implement changes.

4. Validate (see §7).

5. Review diff:
   - `git diff`

6. Commit with explicit paths (see §4).

7. Push feature branch:
   - `git push -u origin <type>/<description>`

8. Prepare for PR (do not merge directly unless user explicitly asks).

---

## 3) Branch Naming (MUST)

Format: `<type>/<description>`

Allowed `<type>` values:

- `feat` `fix` `chore` `docs` `refactor` `test` `ci`

Description rules:

- lowercase only
- choose **one** separator style: hyphens OR underscores (do not mix)
- exception: component names that naturally use underscores (e.g., `envoy_gateway`) may retain them
- no trailing `/` or `.`
- concise but descriptive (typically 3–5 words)

---

## 4) Commits (MUST)

### 4.1 Conventional Commits (MUST)

Format:

- Subject: `<type>: <subject>`
- Optional body separated by a blank line

Rules:

- imperative mood (`add`, `fix`, `upgrade`)
- do not capitalize first letter after colon
- no trailing period
- subject ≤ 50 chars (best effort)
- body wraps at ~72 chars (best effort)
- explain **WHAT and WHY**, not HOW

Allowed commit types:

- `feat:` `fix:` `chore:` `docs:` `refactor:` `test:` `ci:`

### 4.2 Commit execution rules (MUST)

- **Never commit from `main`.**
- **Never stage everything.**
- Prefer committing with explicit paths:
  - `git commit -m "docs: update troubleshooting guide" ./docs/troubleshooting.md`

---

## 5) Repository Structure (GUIDE)

Key directories:

- `argocd/` — ArgoCD installation resources
- `bootstrap/` — bootstrap components applied by ArgoCD
- `docs/` — documentation

When adding a new bootstrap component, prefer `bootstrap/<component>/` with:

- `kustomization.yaml`
- component manifests
- docs updates when behavior changes

---

## 6) Kubernetes / YAML / Kustomize Rules (MUST)

### 6.1 Version pinning (MUST)

- Pin **exact** container image versions.
- Do NOT use `:latest`, `:v1`, or `:v1.5`.

### 6.2 Kustomize patterns (SHOULD)

- Prefer base/overlays when environment-specific differences exist.
- Prefer patches files over editing large outputs.
- Do not manually edit generated resources.

---

## 7) Validation & Linting (REQUIRED)

### 7.1 When validation is required

If you change any of:

- `.yaml` / `.yml` files
- kustomize (`kustomization.yaml`, patches, bases/overlays)
- Kubernetes manifests under `argocd/` or `bootstrap/`

…you **MUST** run the validation pipeline below (or explain exactly what you cannot run and why).

### 7.2 Temp file policy (MUST)

- **MUST write temp files inside the repo directory** (do not assume `/tmp` exists).
- **MUST clean up temp files when done** (even after failures, best effort).
- Use a dedicated temp directory under the repo, e.g.:
  - `./.tmp/` (preferred)
- Temp directory naming:
  - default: `./.tmp/`
  - if collision avoidance needed: `./.tmp/agent-validate/`

### 7.3 Validation pipeline (run in this order)

#### Step 1: yamllint (MUST use repo config)

- The repo has a `.yamllint` config in the root; use it:
  - `yamllint -c .yamllint .`

#### Step 2: kustomize build (REQUIRED)

- Render manifests to repo-local temp files:
  - `mkdir -p ./.tmp`
  - `kustomize build bootstrap/ > ./.tmp/bootstrap.rendered.yaml`
- If `argocd/` is also kustomize-managed and changed:
  - `kustomize build argocd/ > ./.tmp/argocd.rendered.yaml`

#### Step 3: kube-linter (MUST lint the rendered output)

- **Do not lint the raw directories**; lint the rendered YAML:
  - `kube-linter lint ./.tmp/bootstrap.rendered.yaml`
  - `kube-linter lint ./.tmp/argocd.rendered.yaml` (if rendered)

#### Step 4: kubeconform (MUST validate the rendered output)

- Validate rendered outputs (use strict mode when possible):
  - `kubeconform -strict -summary ./.tmp/bootstrap.rendered.yaml`
  - `kubeconform -strict -summary ./.tmp/argocd.rendered.yaml` (if rendered)

#### Step 5: cleanup (REQUIRED)

- Remove temp artifacts created by validation:
  - `rm -rf ./.tmp`

If running on Windows where `rm` may not exist, tell the user the equivalent:

- PowerShell: `Remove-Item -Recurse -Force .\.tmp`

### 7.4 If tools are missing: install guidance (MUST)

If any required tool is not available (`yamllint`, `kustomize`, `kube-linter`, `kubeconform`), you must:

1. tell the user which tool(s) are missing, and
2. provide install commands **for their OS**, preferring system package managers **if the user has admin/root**.

**Important:** Do **not** assume the user has admin/root rights.
Ask (or infer from user message) whether they can use admin/root. If not, provide the no-admin fallback.

#### macOS (prefer Homebrew if possible)

- Preferred (brew):
  - `brew install yamllint kustomize kube-linter kubeconform`
- No-admin fallback (user-local installs):
  - `pipx install yamllint` (or `python3 -m pip install --user yamllint`)
  - Download release binaries for `kustomize`, `kube-linter`, `kubeconform` into `~/.local/bin` and add it to PATH.

#### Windows (prefer winget if possible)

- Preferred (winget):
  - `winget install --id Kubernetes.kubectl` (if needed for related workflows)
  - `winget install --id Kubernetes.kustomize`
  - For `kubeconform` / `kube-linter` / `yamllint`, if winget packages exist in the user’s environment, use them.
- No-admin fallback (user-local installs):
  - Create `%USERPROFILE%\bin` and add it to user PATH.
  - Download `.exe` releases for `kustomize`, `kube-linter`, `kubeconform` into `%USERPROFILE%\bin`.
  - `pipx install yamllint` (recommended) or `py -m pip install --user yamllint`.

#### Linux (prefer distro packages if possible)

- Preferred (admin/root available):
  - Debian/Ubuntu: `sudo apt install yamllint` (+ install other tools via distro packages if available)
  - openSUSE: `sudo zypper in yamllint`
  - Alpine: `sudo apk add yamllint`
  - For `kustomize`, `kube-linter`, `kubeconform`: use distro packages if present; otherwise use release binaries.
- No-admin fallback (user-local installs):
  - `pipx install yamllint` (or `python3 -m pip install --user yamllint`)
  - Download release binaries for `kustomize`, `kube-linter`, `kubeconform` into `~/.local/bin` and add it to PATH.

**User-local binary install pattern (no admin, cross-platform idea)**

- Use a per-user bin dir and PATH update:
  - macOS/Linux: `~/.local/bin`
  - Windows: `%USERPROFILE%\bin`
- Download the correct release for OS/arch and place the executable in that directory.

### 7.5 If validation can’t be run (MUST)

If you cannot run validations (missing tools, no local environment, etc.), you must:

- state exactly which commands you would run (from §7.3)
- list which tools are missing
- provide install steps (from §7.4) tailored to the user’s OS and admin/root constraints

---

## 8) Documentation Rules (MUST when behavior changes)

If you add/change a bootstrap component or alter behavior:

- Update or add docs describing:
  - what it does
  - why it exists
  - how to troubleshoot

Prefer `docs/` for detailed guides.

---

## 9) Agent Execution Protocol (MUST)

When performing any change request:

1. State current branch (from `git branch --show-current`).
2. If on `main`, stop and create/switch to feature branch.
3. Read existing files before editing when you will touch them.
4. Plan: list the exact files you will change and why.
5. Make edits.
6. Review diff (`git diff`).
7. Run validation pipeline (§7) when applicable.
8. Commit with explicit paths and Conventional Commit message.
9. Push feature branch.

If any step cannot be performed, explicitly say which step and why.

---

## 10) Hard Prohibitions (MUST NOT)

- MUST NOT commit or push directly to `main` (unless confirmation phrase is provided; even then, prefer PR).
- MUST NOT use `git add .` or `git add -A`.
- MUST NOT introduce unpinned image tags.
- MUST NOT commit secrets (passwords, keys, tokens). If any secret-like value is detected, stop and ask for remediation.

---

## 11) Quick Pre-Push Checklist (MUST)

Before pushing:

- [ ] Not on `main`
- [ ] Branch name matches `<type>/<description>`
- [ ] Versions pinned (no `latest`)
- [ ] `yamllint -c .yamllint .` run (if YAML changed)
- [ ] `kustomize build ... > ./.tmp/*.rendered.yaml` run (if kustomize/manifests changed)
- [ ] `kube-linter lint ./.tmp/*.rendered.yaml` run (rendered manifests)
- [ ] `kubeconform -strict -summary ./.tmp/*.rendered.yaml` run (rendered manifests)
- [ ] Temp files cleaned (`rm -rf ./.tmp` or Windows equivalent)
- [ ] `git diff` reviewed; only intended files changed
- [ ] Commit message follows Conventional Commits
- [ ] No secrets included
- [ ] Docs updated if behavior changed
