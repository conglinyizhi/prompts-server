export type Lang = 'zh' | 'en'

export const messages = {
  zh: {
    title: '提示词管理',
    search: '搜索',
    reset: '重置',
    newPrompt: '+ 新建',
    cancel: '取消',
    save: '保存',
    saving: '保存中…',
    loading: '加载中…',
    copy: '复制',
    copied: '已复制！',
    expand: '展开',
    collapse: '收起',
    noResults: '暂无提示词，点击上方新建',
    results: (n: number) => `${n} 条结果`,
    prompts: (n: number) => `${n} 条提示词`,
    titleLabel: '标题（可选）',
    keywordsLabel: '关键词（可选，空格分隔）',
    descLabel: '描述（可选）',
    contentLabel: '内容（必填）',
    contentTooLong: '内容过长（最大 5000 字符）',
    langSwitch: 'English',
    error: '请求失败',
    copyFail: '复制失败',
    backendOffline: '后端服务未启动，请运行后端后再试',
    untitled: '(未命名)',
    keywords: '关键词',
    description: '描述',
  },
  en: {
    title: 'Prompts',
    search: 'Search',
    reset: 'Reset',
    newPrompt: '+ New',
    cancel: 'Cancel',
    save: 'Save',
    saving: 'Saving…',
    loading: 'Loading…',
    copy: 'Copy',
    copied: 'Copied!',
    expand: 'Expand',
    collapse: 'Collapse',
    noResults: 'No prompts yet. Create one above.',
    results: (n: number) => `${n} result${n !== 1 ? 's' : ''}`,
    prompts: (n: number) => `${n} prompt${n !== 1 ? 's' : ''}`,
    titleLabel: 'Title (optional)',
    keywordsLabel: 'Keywords (optional, space-separated)',
    descLabel: 'Description (optional)',
    contentLabel: 'Content (required)',
    contentTooLong: 'Content too long (max 5000 chars)',
    langSwitch: '中文',
    error: 'Request failed',
    copyFail: 'Copy failed',
    backendOffline: 'Backend is not running. Start it first.',
    untitled: '(untitled)',
    keywords: 'Keywords',
    description: 'Description',
  },
}

export type MessageKeys = keyof typeof messages.en

let currentLang = $state<Lang>('zh')

export function getLang(): Lang {
  return currentLang
}

export function setLang(l: Lang) {
  currentLang = l
}

export function t(key: MessageKeys, ...args: any[]): string {
  const msg = (messages[currentLang] as any)[key]
  if (typeof msg === 'function') return msg(...args)
  return msg ?? key
}
