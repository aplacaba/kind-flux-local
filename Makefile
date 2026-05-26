.PHONY: setup teardown verify dev-only prod-only git-init

# ─── Default ─────────────────────────────────────────
all: setup

# ─── Bootstrap ───────────────────────────────────────
setup: git-init
	@echo "=== Bootstrapping dev + prod clusters ==="
	./scripts/setup.sh

teardown:
	@echo "=== Tearing down dev + prod clusters ==="
	./scripts/teardown.sh

# ─── Per-cluster ─────────────────────────────────────
dev-only: git-init
	@echo "=== Bootstrapping dev cluster ==="
	CLUSTERS=dev ./scripts/setup.sh

prod-only: git-init
	@echo "=== Bootstrapping prod cluster ==="
	CLUSTERS=prod ./scripts/setup.sh

# ─── Verification ────────────────────────────────────
verify:
	@echo "=== Verifying Flux status ==="
	./scripts/verify.sh

# ─── Git init (idempotent) ───────────────────────────
git-init:
	@if [ ! -d .git ]; then \
		echo "→ Initialising git repo..."; \
		git init; \
		git add -A; \
		git commit -m "Initial commit: Flux GitOps structure" --allow-empty; \
		echo "✓ Git repo initialised"; \
	else \
		echo "→ Git repo already exists"; \
	fi
w
