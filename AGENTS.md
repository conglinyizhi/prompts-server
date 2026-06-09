# 协议式提交规范

本项目使用**约定式提交（Conventional Commits）**，commit message 使用**中文**。

## 格式

```
<类型>: <简短描述>

<可选详细说明>
```

## 类型

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `refactor` | 重构（不改变外部行为） |
| `style` | 代码格式调整（无功能变化） |
| `docs` | 文档变更 |
| `test` | 测试相关 |
| `chore` | 构建、CI、工具链等杂项 |
| `perf` | 性能优化 |

## 示例

```
feat: 添加 SQLite 存储支持
fix: 搜索接口返回 502 的问题
refactor: 将文件存储改为 SQLite
chore: 初始化 Git 仓库
```
