.PHONY: dev backend frontend build build-backend build-frontend clean kill

BACKEND_BIN  := _build/native/debug/build/prompts-server.exe
FRONTEND_DIR := frontend

# ── Dev: run both together ──────────────────────────────────
dev: kill
	@echo "=== Starting backend + frontend ==="
	@trap 'kill 0' EXIT; \
		$(MAKE) -s backend & \
		$(MAKE) -s frontend & \
		wait

# ── Kill stale processes ────────────────────────────────────
kill:
	@echo "Cleaning up stale processes…"
	@-lsof -ti:8080 2>/dev/null | xargs -r kill 2>/dev/null; true
	@-lsof -ti:3000 2>/dev/null | xargs -r kill 2>/dev/null; true
	@sleep 0.5

# ── Individual ──────────────────────────────────────────────
backend:
	@echo "[backend] moon run . --target native"
	@moon run . --target native

frontend:
	@echo "[frontend] pnpm dev"
	@cd $(FRONTEND_DIR) && pnpm dev

# ── Build ───────────────────────────────────────────────────
build: build-backend build-frontend

build-backend:
	@echo "[backend] moon build --target native"
	@moon build --target native

build-frontend:
	@echo "[frontend] pnpm build"
	@cd $(FRONTEND_DIR) && pnpm build

# ── Clean (only build artifacts, NOT user data) ─────────────
clean:
	@echo "Cleaning build artifacts…"
	@rm -rf _build
	@cd $(FRONTEND_DIR) && rm -rf dist node_modules
	@echo "Done"

# ── Nuke (everything including data) ───────────────────────
nuke: clean
	@echo "Removing user data…"
	@rm -rf data
	@echo "Done"
