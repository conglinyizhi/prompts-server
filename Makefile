.PHONY: dev backend frontend build build-backend build-frontend install check clean nuke kill embed

BACKEND_BIN  := _build/native/debug/build/prompts-server.exe
FRONTEND_DIR := frontend

# ── 安装依赖 ────────────────────────────────────────────────
install:
	@echo "[frontend] pnpm install"
	@cd $(FRONTEND_DIR) && pnpm install

# ── 代码检查（依赖嵌入） ────────────────────────────────────
check: embed
	@echo "[backend] moon check"
	@moon check --deny-warn --target native

# ── 构建 ────────────────────────────────────────────────────
build: embed build-backend

# 构建前端并将产物嵌入后端
build-frontend: install
	@echo "[frontend] pnpm build"
	@cd $(FRONTEND_DIR) && pnpm build
	$(MAKE) -s embed

# 将 frontend/dist/ 嵌入为 embedded.mbt
embed:
	@echo "[embed] Generating embedded.mbt…"
	@bash scripts/embed.sh

build-backend:
	@echo "[backend] moon build --target native"
	@moon build --target native

# ── 开发：同时启动前后端 ────────────────────────────────────
dev: kill
	@echo "=== Starting backend + frontend ==="
	@trap 'kill 0' EXIT; \
		$(MAKE) -s backend & \
		$(MAKE) -s frontend & \
		wait

# ── 单独启动 ────────────────────────────────────────────────
backend:
	@echo "[backend] moon run . --target native"
	@moon run . --target native

frontend:
	@echo "[frontend] pnpm dev"
	@cd $(FRONTEND_DIR) && pnpm dev

# ── 清除残留进程 ────────────────────────────────────────────
kill:
	@echo "Cleaning up stale processes…"
	@-lsof -ti:8080 2>/dev/null | xargs -r kill 2>/dev/null; true
	@-lsof -ti:3000 2>/dev/null | xargs -r kill 2>/dev/null; true
	@sleep 0.5

# ── 清理构建产物（不动数据） ─────────────────────────────────
clean:
	@echo "Cleaning build artifacts…"
	@rm -rf _build dist
	@cd $(FRONTEND_DIR) && rm -rf dist
	@echo "Done"

# ── 清理全部（包括 node_modules） ───────────────────────────
distclean: clean
	@echo "Removing node_modules…"
	@cd $(FRONTEND_DIR) && rm -rf node_modules
	@echo "Done"

# ── 核弹（连数据一起清） ────────────────────────────────────
nuke: distclean
	@echo "Removing user data…"
	@rm -rf data
	@echo "Done"
