const CLAWHUB_API_URL = "https://wry-manatee-359.convex.cloud/api/query";
const CLAWHUB_SKILLS_PATH = "skills:listPublicPageV2";
const CLAWHUB_COUNT_PATH = "skills:countPublicSkills";
const PAGE_SIZE = 36;

const CATEGORY_CONFIG = {
  search: {
    label: "搜索与信息查询",
    description: "适合第一次就想看到结果的小白用户。",
    keywords: ["search", "weather", "news", "docs", "documentation", "youtube", "transcript", "web", "query", "research"]
  },
  office: {
    label: "办公与内容处理",
    description: "适合文档、整理、总结、协作和内容工作。",
    keywords: ["summarize", "pdf", "notion", "gmail", "slack", "trello", "workspace", "calendar", "drive", "docs", "email", "obsidian", "blog"]
  },
  dev: {
    label: "开发与仓库工具",
    description: "适合开发者和半技术用户的仓库、代码、MCP 工具链。",
    keywords: ["github", "git", "repo", "code", "mcp", "api gateway", "whisper", "video", "model usage", "porter", "docs expert"]
  },
  automation: {
    label: "自动化与代理增强",
    description: "适合希望让 AI 更主动、更稳定、更可复用的用户。",
    keywords: ["automation", "workflow", "updater", "improving", "proactive", "ontology", "memory", "vetter", "free ride", "agent"]
  },
  media: {
    label: "多媒体与素材处理",
    description: "适合音频、视频、图片和 PDF 相关任务。",
    keywords: ["image", "video", "frames", "banana", "whisper", "pdf", "audio"]
  }
};

const FEATURED_SKILLS = [
  {
    owner: "steipete",
    slug: "weather",
    displayName: "Weather",
    category: "search",
    zhSummary: "查询当前天气和未来预报，不需要 API Key，最适合第一次验证搜索类 Skill 的效果。"
  },
  {
    owner: "ide-rea",
    slug: "baidu-search",
    displayName: "baidu web search",
    category: "search",
    zhSummary: "用百度搜索做实时资料查询，比较适合中国大陆用户作为第一批信息检索类 Skill。"
  },
  {
    owner: "steipete",
    slug: "summarize",
    displayName: "Summarize",
    category: "office",
    zhSummary: "总结网页、PDF、图片、音频和 YouTube 内容，适合内容用户和办公用户快速出成果。"
  },
  {
    owner: "steipete",
    slug: "github",
    displayName: "Github",
    category: "dev",
    zhSummary: "用 gh CLI 读取仓库、Issue、PR 和 Action，适合开发者第一次感受 Skill 带来的直接差异。"
  },
  {
    owner: "steipete",
    slug: "notion",
    displayName: "Notion",
    category: "office",
    zhSummary: "连接 Notion 页面、数据库和区块，适合做知识库整理、协作文档和内容沉淀。"
  },
  {
    owner: "steipete",
    slug: "openai-whisper",
    displayName: "Openai Whisper",
    category: "media",
    zhSummary: "用本地 Whisper 做语音转文字，适合会议录音、播客和视频音频整理。"
  }
];

const state = {
  items: [],
  cursor: null,
  isDone: false,
  loading: false,
  totalCount: null,
  sort: "downloads",
  category: "all",
  query: ""
};

const elements = {};

function installCommand(slug) {
  return "npx clawhub@latest install " + slug;
}

function skillUrl(owner, slug) {
  return "https://clawhub.ai/" + encodeURIComponent(owner) + "/" + encodeURIComponent(slug);
}

function formatNumber(value) {
  return new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 0 }).format(Number(value || 0));
}

function containsAny(text, keywords) {
  return keywords.some((keyword) => text.includes(keyword));
}

function inferCategory(item) {
  const text = (item.skill.displayName + " " + (item.skill.summary || "")).toLowerCase();
  if (containsAny(text, CATEGORY_CONFIG.search.keywords)) return "search";
  if (containsAny(text, CATEGORY_CONFIG.office.keywords)) return "office";
  if (containsAny(text, CATEGORY_CONFIG.media.keywords)) return "media";
  if (containsAny(text, CATEGORY_CONFIG.dev.keywords)) return "dev";
  return "automation";
}

function buildChineseSummary(item, categoryId) {
  const text = (item.skill.displayName + " " + (item.skill.summary || "")).toLowerCase();
  if (text.includes("weather")) return "查询当前天气和未来预报，适合第一次用一句自然语言就验证 Skill 是否工作。";
  if (text.includes("baidu")) return "用百度搜索做实时信息查询，更贴近中文搜索场景，适合中国大陆用户起步。";
  if (text.includes("brave")) return "用 Brave 做网页搜索和内容提取，适合查资料、查文档和做轻量研究。";
  if (text.includes("summarize")) return "快速总结网页、文档或多媒体内容，适合内容用户和办公用户做高频整理。";
  if (text.includes("pdf")) return "用自然语言处理 PDF，适合合同、资料、论文和报告类文件的提炼与编辑。";
  if (text.includes("notion")) return "连接 Notion 页面和数据库，适合知识整理、协作文档和内容沉淀。";
  if (text.includes("github") || text.includes("git")) return "连接 GitHub 和仓库流程，适合看提交、查 PR、读 Issue 和做代码复盘。";
  if (text.includes("youtube")) return "抓取 YouTube 字幕和内容，适合视频总结、课程整理和资料提炼。";
  if (text.includes("whisper")) return "把语音转成文字，适合会议录音、播客、视频和采访内容整理。";
  if (text.includes("obsidian")) return "连接 Obsidian 笔记库，适合把个人知识和工作资料整理成长期可复用资产。";
  if (text.includes("gmail") || text.includes("email")) return "连接邮箱收发与管理流程，适合邮件整理、草稿生成和日常沟通。";
  if (text.includes("trello")) return "连接 Trello 看板和卡片，适合任务管理、项目跟踪和协作安排。";
  if (text.includes("slack")) return "连接 Slack 做消息处理和协作动作，适合团队沟通与频道管理。";
  if (text.includes("workspace") || text.includes("calendar") || text.includes("drive")) return "连接 Google Workspace，适合邮件、日历、文档和云盘相关任务。";
  if (text.includes("automation") || text.includes("workflow")) return "用于自动化重复任务和日常流程，适合想把高频动作沉淀成工作流的用户。";
  if (text.includes("improving") || text.includes("proactive") || text.includes("memory")) return "增强代理的学习、记忆或自我改进能力，适合希望 AI 更主动、更稳定的用户。";

  const category = CATEGORY_CONFIG[categoryId];
  if (categoryId === "search") return "这是一个偏搜索和资料查询的 Skill，适合第一次装上后立刻问一句话验证效果。";
  if (categoryId === "office") return "这是一个偏办公、整理或内容处理的 Skill，适合把日常重复任务做得更省时间。";
  if (categoryId === "dev") return "这是一个偏开发和仓库工具链的 Skill，适合半技术用户和开发者提升效率。";
  if (categoryId === "media") return "这是一个偏多媒体处理的 Skill，适合音频、视频、图片和 PDF 相关任务。";
  return "这是一个偏自动化和代理增强的 Skill，适合把已有经验沉淀成更稳定的长期工作方式。";
}

async function postQuery(path, args) {
  const response = await fetch(CLAWHUB_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Convex-Client": "clawstart-skills-hub"
    },
    body: JSON.stringify({
      path,
      format: "convex_encoded_json",
      args: [args]
    })
  });
  const payload = await response.json();
  if (payload.status !== "success") {
    throw new Error(payload.errorMessage || "Failed to fetch skills");
  }
  return payload.value;
}

function mapSkill(item) {
  const categoryId = inferCategory(item);
  return {
    id: item.skill._id,
    slug: item.skill.slug,
    owner: item.ownerHandle || item.owner?.handle || "unknown",
    displayName: item.skill.displayName,
    summaryZh: buildChineseSummary(item, categoryId),
    categoryId,
    downloads: item.skill.stats.downloads || 0,
    stars: item.skill.stats.stars || 0,
    url: skillUrl(item.ownerHandle || item.owner?.handle || "unknown", item.skill.slug),
    command: installCommand(item.skill.slug)
  };
}

function getFilteredItems() {
  let list = state.items.slice();
  if (state.category !== "all") {
    list = list.filter((item) => item.categoryId === state.category);
  }
  if (state.query) {
    const q = state.query.toLowerCase();
    list = list.filter((item) => {
      const categoryLabel = CATEGORY_CONFIG[item.categoryId]?.label || "";
      return (
        item.displayName.toLowerCase().includes(q) ||
        item.slug.toLowerCase().includes(q) ||
        item.summaryZh.includes(q) ||
        categoryLabel.includes(q)
      );
    });
  }
  return list;
}

function groupByCategory(items) {
  const groups = {};
  for (const item of items) {
    if (!groups[item.categoryId]) {
      groups[item.categoryId] = [];
    }
    groups[item.categoryId].push(item);
  }
  return groups;
}

function renderFeatured() {
  elements.featured.innerHTML = FEATURED_SKILLS.map((skill) => {
    const category = CATEGORY_CONFIG[skill.category];
    return `
      <article class="skill-card">
        <div class="skill-card-header">
          <div>
            <div class="skill-card-title">
              <h3>${skill.displayName}</h3>
              <span class="skill-badge">${category.label}</span>
            </div>
            <p>${skill.zhSummary}</p>
          </div>
        </div>
        <div class="skill-meta">
          <span>来自 ClawHub</span>
          <span>@${skill.owner}</span>
        </div>
        <div class="skill-command"><code>${installCommand(skill.slug)}</code></div>
        <div class="skill-card-actions">
          <a href="${skillUrl(skill.owner, skill.slug)}" class="btn btn-primary btn-sm" target="_blank" rel="noopener">查看 ClawHub 页面 →</a>
          <a href="tutorial-install-first-skill.html" class="btn btn-outline-dark btn-sm">回安装教程 →</a>
        </div>
      </article>
    `;
  }).join("");
}

function renderStats() {
  elements.totalCount.textContent = state.totalCount ? formatNumber(state.totalCount) : "--";
  elements.loadedCount.textContent = formatNumber(state.items.length);
  elements.visibleCount.textContent = formatNumber(getFilteredItems().length);
}

function renderCatalog() {
  const filtered = getFilteredItems();
  renderStats();

  if (!filtered.length) {
    elements.catalog.innerHTML = `
      <div class="skill-empty">
        <h3>当前筛选条件下还没有结果</h3>
        <p>可以先清空关键词，或者继续从 ClawHub 加载更多技能。</p>
      </div>
    `;
    return;
  }

  const groups = groupByCategory(filtered);
  const orderedCategories = Object.keys(CATEGORY_CONFIG);

  elements.catalog.innerHTML = orderedCategories
    .filter((categoryId) => groups[categoryId] && groups[categoryId].length)
    .map((categoryId) => {
      const category = CATEGORY_CONFIG[categoryId];
      const cards = groups[categoryId]
        .sort((a, b) => b.downloads - a.downloads)
        .map((item) => `
          <article class="skill-card">
            <div class="skill-card-header">
              <div>
                <div class="skill-card-title">
                  <h3>${item.displayName}</h3>
                  <span class="skill-badge">${category.label}</span>
                </div>
                <p>${item.summaryZh}</p>
              </div>
            </div>
            <div class="skill-meta">
              <span>下载 ${formatNumber(item.downloads)}</span>
              <span>星标 ${formatNumber(item.stars)}</span>
              <span>@${item.owner}</span>
            </div>
            <div class="skill-command"><code>${item.command}</code></div>
            <div class="skill-card-actions">
              <a href="${item.url}" class="btn btn-primary btn-sm" target="_blank" rel="noopener">查看 ClawHub 页面 →</a>
            </div>
          </article>
        `).join("");

      return `
        <section class="skill-catalog-group">
          <div class="skill-catalog-heading">
            <div>
              <p class="section-title">${category.label}</p>
              <h2 class="text-h2">${category.description}</h2>
            </div>
            <p>${groups[categoryId].length} 个已加载技能</p>
          </div>
          <div class="skill-catalog-grid">${cards}</div>
        </section>
      `;
    }).join("");
}

async function fetchCount() {
  try {
    const value = await postQuery(CLAWHUB_COUNT_PATH, {});
    state.totalCount = Number(value || 0);
    renderStats();
  } catch (error) {
    console.error(error);
  }
}

async function fetchSkills(reset) {
  if (state.loading) return;
  state.loading = true;
  elements.loadMore.disabled = true;
  elements.loadMore.textContent = "正在从 ClawHub 获取技能...";

  if (reset) {
    state.items = [];
    state.cursor = null;
    state.isDone = false;
  }

  try {
    const value = await postQuery(CLAWHUB_SKILLS_PATH, {
      paginationOpts: {
        cursor: state.cursor,
        numItems: PAGE_SIZE
      },
      sort: state.sort,
      dir: state.sort === "name" ? "asc" : "desc",
      nonSuspiciousOnly: true
    });

    const mapped = value.page.map(mapSkill).filter((item) => {
      return !state.items.some((existing) => existing.id === item.id);
    });

    state.items = state.items.concat(mapped);
    state.cursor = value.continueCursor;
    state.isDone = Boolean(value.isDone);
    renderCatalog();
  } catch (error) {
    console.error(error);
    elements.catalog.innerHTML = `
      <div class="skill-empty">
        <h3>技能列表暂时加载失败</h3>
        <p>ClawHub 公开接口可能暂时不稳定。你可以稍后重试，或者先使用上面的精选技能。</p>
      </div>
    `;
  } finally {
    state.loading = false;
    elements.loadMore.disabled = state.isDone;
    elements.loadMore.textContent = state.isDone ? "已加载到当前页尽头" : "继续从 ClawHub 加载更多技能";
  }
}

function bindEvents() {
  elements.search.addEventListener("input", (event) => {
    state.query = event.target.value.trim();
    renderCatalog();
  });

  elements.category.addEventListener("change", (event) => {
    state.category = event.target.value;
    renderCatalog();
  });

  elements.sort.addEventListener("change", async (event) => {
    state.sort = event.target.value;
    await fetchSkills(true);
  });

  elements.loadMore.addEventListener("click", async () => {
    await fetchSkills(false);
  });
}

async function init() {
  elements.totalCount = document.getElementById("skillsTotalCount");
  elements.loadedCount = document.getElementById("skillsLoadedCount");
  elements.visibleCount = document.getElementById("skillsVisibleCount");
  elements.featured = document.getElementById("featuredSkillsGrid");
  elements.catalog = document.getElementById("skillsCatalog");
  elements.search = document.getElementById("skillsHubSearch");
  elements.category = document.getElementById("skillsHubCategory");
  elements.sort = document.getElementById("skillsHubSort");
  elements.loadMore = document.getElementById("skillsHubLoadMore");

  renderFeatured();
  renderStats();
  bindEvents();
  await fetchCount();
  await fetchSkills(true);
}

init();
