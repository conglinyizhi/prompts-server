<script lang="ts">
  import { onMount } from 'svelte'
  import type { PromptHeader } from './api'
  import { fetchRecent, searchPrompts, createPrompt, fetchContent, copyToClipboard, checkHealth } from './api'
  import { t, setLang, getLang, type Lang } from './lib/i18n.svelte'

  // ── State ────────────────────────────────────────────────
  let prompts: PromptHeader[] = $state([])
  interface SearchItem { prompt: PromptHeader; score: number }
  let searchResults: SearchItem[] = $state([])
  let query = $state('')
  let loading = $state(false)
  let error = $state('')
  let mode: 'recent' | 'search' = $state('recent')
  let showForm = $state(false)

  // form fields
  let formTitle = $state('')
  let formDesc = $state('')
  let formKw = $state('')
  let formContent = $state('')
  let submitting = $state(false)

  // backend status
  let backendOnline = $state(true)

  // expand / content
  let expandedIds = $state(new Set<string>())
  let contents = $state(new Map<string, string>())
  let loadingContent = $state(new Set<string>())
  let copyStatus = $state(new Map<string, 'idle' | 'copied' | 'failed'>())

  // ── Lifecycle ────────────────────────────────────────────
  onMount(async () => {
    backendOnline = await checkHealth()
    if (backendOnline) loadRecent()
  })

  // ── Data loading ─────────────────────────────────────────
  async function loadRecent() {
    loading = true
    error = ''
    mode = 'recent'
    try {
      const res = await fetchRecent()
      prompts = res.prompts
    } catch (e) {
      error = String(e)
    } finally {
      loading = false
    }
  }

  async function doSearch() {
    const q = query.trim()
    if (!q) { loadRecent(); return }
    loading = true
    error = ''
    mode = 'search'
    try {
      const res = await searchPrompts(q)
      searchResults = res.results
    } catch (e) {
      error = String(e)
    } finally {
      loading = false
    }
  }

  async function loadContent(id: string) {
    if (contents.has(id) || loadingContent.has(id)) return
    loadingContent = new Set([...loadingContent, id])
    try {
      const res = await fetchContent(id)
      contents = new Map([...contents, [id, res.content]])
    } catch (e) {
      error = String(e)
    } finally {
      const next = new Set(loadingContent)
      next.delete(id)
      loadingContent = next
    }
  }

  // ── Events ──────────────────────────────────────────────
  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') doSearch()
  }

  function toggleExpand(id: string) {
    const next = new Set(expandedIds)
    if (next.has(id)) {
      next.delete(id)
    } else {
      next.add(id)
      loadContent(id)
    }
    expandedIds = next
  }

  async function handleCopy(id: string) {
    const text = contents.get(id)
    if (!text) return
    const ok = await copyToClipboard(text)
    const next = new Map(copyStatus)
    next.set(id, ok ? 'copied' : 'failed')
    copyStatus = next
    if (ok) {
      setTimeout(() => {
        const st = new Map(copyStatus)
        st.set(id, 'idle')
        copyStatus = st
      }, 2000)
    }
  }

  async function handleSubmit() {
    if (!formContent.trim()) return
    submitting = true
    error = ''
    try {
      await createPrompt({
        title: formTitle.trim(),
        description: formDesc.trim(),
        keywords: formKw.trim(),
        content: formContent.trim(),
      })
      formTitle = ''
      formDesc = ''
      formKw = ''
      formContent = ''
      showForm = false
      if (mode === 'recent') await loadRecent()
      else await doSearch()
    } catch (e) {
      error = String(e)
    } finally {
      submitting = false
    }
  }

  function switchLang() {
    setLang(getLang() === 'zh' ? 'en' : 'zh')
  }

  // ── Derived ─────────────────────────────────────────────
  let displayItems = $derived(
    mode === 'search'
      ? searchResults.map(r => ({ prompt: r.prompt, score: r.score, key: r.prompt.id }))
      : prompts.map(p => ({ prompt: p, score: null as number | null, key: p.id }))
  )

  let statusText = $derived(
    loading
      ? t('loading')
      : mode === 'search'
        ? t('results', searchResults.length)
        : t('prompts', prompts.length)
  )
</script>

<svelte:head>
  <title>{t('title')}</title>
</svelte:head>

<!-- Header + LangSwitch -->
<div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:16px;">
  <h1 style="margin:0">{t('title')}</h1>
  <button class="lang-btn" onclick={switchLang}>{t('langSwitch')}</button>
</div>

{#if !backendOnline}
  <div class="offline-banner">
    ⚠ {t('backendOffline')}
  </div>
{/if}

<!-- Search bar -->
<div class="search-row">
  <input
    type="text"
    placeholder={t('search') + '…'}
    bind:value={query}
    onkeydown={handleKeydown}
  />
  <button onclick={doSearch} disabled={loading}>{t('search')}</button>
  <button class="secondary" onclick={() => { query = ''; loadRecent() }}>{t('reset')}</button>
</div>

<!-- Create toggle -->
<button class="secondary create-toggle" onclick={() => showForm = !showForm}>
  {showForm ? '− ' + t('cancel') : t('newPrompt')}
</button>

{#if showForm}
  <div class="create-form">
    <input type="text" placeholder={t('titleLabel')} bind:value={formTitle} />
    <input type="text" placeholder={t('keywordsLabel')} bind:value={formKw} />
    <input type="text" placeholder={t('descLabel')} bind:value={formDesc} />
    <textarea placeholder={t('contentLabel')} bind:value={formContent}></textarea>
    <div class="form-actions">
      <button class="secondary" onclick={() => showForm = false}>{t('cancel')}</button>
      <button onclick={handleSubmit} disabled={submitting || !formContent.trim()}>
        {submitting ? t('saving') : t('save')}
      </button>
    </div>
  </div>
{/if}

<!-- Error -->
{#if error}
  <div class="status-bar error">{error}</div>
{/if}

<!-- Results heading -->
<div class="section-title">{statusText}</div>

{#if !loading && displayItems.length === 0}
  <div class="empty">{t('noResults')}</div>
{/if}

<!-- Cards -->
{#each displayItems as { prompt, score, key } (key)}
  {@const isExpanded = expandedIds.has(key)}
  {@const content = contents.get(key)}
  {@const loadingCont = loadingContent.has(key)}
  {@const copySt = copyStatus.get(key) ?? 'idle'}

  <div class="card" class:expanded={isExpanded}>
    <div class="card-header">
      <div class="card-title-row">
        <h3>{prompt.title || t('untitled')}</h3>
        {#if score !== null}
          <span class="score-badge">★ {score.toFixed(1)}</span>
        {/if}
      </div>
      <button class="expand-btn" onclick={() => toggleExpand(key)}>
        {isExpanded ? t('collapse') : t('expand')}
      </button>
    </div>

    {#if prompt.keywords}
      <div class="meta">{t('keywords')}: {prompt.keywords}</div>
    {/if}
    {#if prompt.description}
      <div class="meta">{t('description')}: {prompt.description}</div>
    {/if}

    {#if isExpanded}
      <div class="card-body">
        {#if loadingCont}
          <div class="status-bar">{t('loading')}</div>
        {:else if content !== undefined}
          <pre class="content-text">{content}</pre>
          <button class="copy-btn" onclick={() => handleCopy(key)} disabled={copySt === 'copied'}>
            {copySt === 'copied' ? '✓ ' + t('copied') : copySt === 'failed' ? '✗ ' + t('copyFail') : t('copy')}
          </button>
        {:else}
          <div class="status-bar error">{t('error')}</div>
        {/if}
      </div>
    {/if}
  </div>
{/each}

{#if loading}
  <div class="status-bar">{t('loading')}</div>
{/if}

<style>
  .offline-banner {
    background: #fef2f2;
    border: 1px solid #fecaca;
    color: #b91c1c;
    padding: 10px 14px;
    border-radius: var(--radius);
    font-size: 0.88rem;
    margin-bottom: 12px;
    text-align: center;
  }

  .lang-btn {
    font-size: 0.8rem;
    padding: 4px 12px;
    background: transparent;
    color: var(--primary);
    border: 1px solid var(--primary);
    border-radius: var(--radius);
    cursor: pointer;
    font-weight: 600;
    transition: background 0.15s;
  }
  .lang-btn:hover {
    background: #eef2ff;
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 8px;
  }

  .card-title-row {
    display: flex;
    align-items: baseline;
    gap: 8px;
    flex: 1;
    min-width: 0;
  }

  .expand-btn {
    font-size: 0.78rem;
    padding: 3px 10px;
    background: transparent;
    color: var(--primary);
    border: 1px solid var(--border);
    border-radius: 4px;
    cursor: pointer;
    white-space: nowrap;
    font-weight: 500;
    flex-shrink: 0;
  }
  .expand-btn:hover {
    background: #f0f0ff;
  }

  .card-body {
    margin-top: 10px;
    border-top: 1px solid var(--border);
    padding-top: 10px;
  }

  .content-text {
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    font-size: 0.85rem;
    line-height: 1.6;
    white-space: pre-wrap;
    word-break: break-word;
    background: #f8f8f8;
    border-radius: 6px;
    padding: 12px;
    overflow-x: auto;
    max-height: 60vh;
    overflow-y: auto;
  }

  .copy-btn {
    margin-top: 8px;
    font-size: 0.82rem;
    padding: 6px 16px;
  }

  .card.expanded {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  }
</style>
