// API 类型定义

/** 提示词头部（搜索/列表用，不含正文） */
export interface PromptHeader {
  id: string
  title: string
  description: string
  keywords: string
  created_at: string
}

/** 提示词正文内容 */
export interface PromptContent {
  id: string
  content: string
}

export interface SearchResult {
  prompt: PromptHeader
  score: number
}

export interface SearchResponse {
  query: string
  results: SearchResult[]
}

export interface RecentResponse {
  prompts: PromptHeader[]
  count: number
}

export interface ContentResponse {
  id: string
  content: string
}

export interface CreateResponse {
  id: string
  message: string
}

export interface CreateRequest {
  title: string
  description: string
  keywords: string
  content: string
}

export interface ErrorResponse {
  error: string
}

const BASE = '/api'

async function handleRes<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = await res.json().catch(() => ({ error: res.statusText }))
    throw new Error(body.error ?? res.statusText)
  }
  return res.json()
}

/** 获取最近提示词列表（仅头部） */
export function fetchRecent(): Promise<RecentResponse> {
  return fetch(`${BASE}/prompts`).then(handleRes<RecentResponse>)
}

/** 搜索提示词（仅匹配头部字段） */
export function searchPrompts(q: string): Promise<SearchResponse> {
  return fetch(`${BASE}/prompts/search?q=${encodeURIComponent(q)}`)
    .then(handleRes<SearchResponse>)
}

/** 获取指定提示词的完整 markdown 内容 */
export function fetchContent(id: string): Promise<ContentResponse> {
  return fetch(`${BASE}/prompts/content?id=${encodeURIComponent(id)}`)
    .then(handleRes<ContentResponse>)
}

/** 健康检查 */
export function checkHealth(): Promise<boolean> {
  return fetch(`${BASE}/health`)
    .then(res => res.ok)
    .catch(() => false)
}

/** 创建提示词 */
export function createPrompt(data: CreateRequest): Promise<CreateResponse> {
  return fetch(`${BASE}/prompts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).then(handleRes<CreateResponse>)
}

/** 复制文本到剪贴板（自动降级方案：Async Clipboard API → execCommand） */
export async function copyToClipboard(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    // HTTP 降级：使用 document.execCommand('copy')
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    textarea.style.pointerEvents = 'none'
    document.body.appendChild(textarea)
    try {
      textarea.select()
      return document.execCommand('copy')
    } catch {
      return false
    } finally {
      document.body.removeChild(textarea)
    }
  }
}
