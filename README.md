# Prompts Server

一个轻量的提示词管理服务——保存、搜索、获取提示词，通过 HTTP API 完成所有操作。

## 快速部署

从 GitHub Actions 下载编译好的二进制文件，直接运行：

```bash
# 下载 prompts-server.exe
chmod +x prompts-server.exe
./prompts-server.exe
```

服务默认监听 `127.0.0.1:8080`，所有数据存储在 `data/prompts.db`。

### 从源码构建

```bash
make build
```

产物在 `_build/native/debug/build/prompts-server.exe`，单文件，拷贝到任何 Linux x86-64 机器即可运行。

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/prompts` | 创建提示词 |
| `GET` | `/api/prompts` | 最近 20 条 |
| `GET` | `/api/prompts/search?q=` | 搜索（标题/关键词/描述） |
| `GET` | `/api/prompts/content?id=` | 获取完整内容 |
| `POST` | `/api/prompts/clean` | 清理孤儿数据 |
| `GET` | `/api/health` | 健康检查 |

### 创建提示词

```bash
curl -X POST http://127.0.0.1:8080/api/prompts \
  -H "Content-Type: application/json" \
  -d '{"title":"示例","description":"介绍","keywords":"关键词","content":"提示词正文"}'
```

### 搜索

```bash
curl "http://127.0.0.1:8080/api/prompts/search?q=关键词"
```

搜索匹配 title（权重 10×）、keywords（8×）、description（3×），按分数降序返回。

### 向量搜索（可选）

设置环境变量以启用语义搜索：

```bash
export EMBEDDING_API_KEY="sk-xxx"
export EMBEDDING_API_URL="https://api.openai.com/v1/embeddings"
./prompts-server.exe
```

启用后创建提示词时会自动生成向量，搜索时采用关键词 + 向量混合排序。

## 技术栈

| 层 | 技术 |
|----|------|
| 语言 | MoonBit |
| 存储 | SQLite（内嵌） |
| 前端 | Svelte 5 + Vite（编译进二进制） |
| 部署 | 单文件，零依赖 |

### 架构说明

前后端构建为单个二进制，前端静态文件在构建时通过 base64 嵌入，运行时解码加载。部署时不需要 Nginx、Node.js 或其他运行时。

## 开发

```bash
make dev       # 同时启动前后端（开发模式）
make build     # 构建生产版本
make clean     # 清理构建产物
```

- 后端：`main.mbt`
- 前端：`frontend/src/`
- 数据库：SQLite，自动初始化
