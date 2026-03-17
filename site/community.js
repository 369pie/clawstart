(function () {
  // Update these values in one place to publish real private-community entry points site-wide.
  var DEFAULT_COMMUNITY_CONFIG = {
    wecom: {
      image: "assets/community/wecom-qr.png",
      fallbackImage: "assets/community/wecom-qr-placeholder.svg",
      alt: "企业微信二维码预览图",
      hint: "扫码添加企业微信，小助手会为您提供 1 对 1 解答，并可以拉您进入最新交流群。"
    },
    qq: {
      image: "assets/community/qq-qr.png",
      fallbackImage: "assets/community/qq-qr-placeholder.svg",
      alt: "QQ群二维码预览图",
      hint: "扫码加入 QQ 交流群，新手朋友们可以在这里自由提问和互相帮助。"
    },
    wechat: {
      image: "assets/community/wechat-qr.png",
      fallbackImage: "assets/community/wechat-qr-placeholder.svg",
      alt: "微信群二维码预览图",
      hint: "扫码进入微信大群，和大家一起讨论 AI 玩法。如果遇到二维码过期，请先添加企业微信助手。"
    },
    planet: {
      image: "assets/community/planet-qr.png",
      fallbackImage: "assets/community/planet-qr-placeholder.svg",
      alt: "知识星球二维码预览图",
      hint: "扫码加入知识星球，获取海量进阶实操案例、专属模板与最新更新动态。"
    }
  };

  function mergeConfig(baseConfig, overrideConfig) {
    var config = JSON.parse(JSON.stringify(baseConfig));
    var source = overrideConfig || {};

    Object.keys(source).forEach(function (key) {
      if (!config[key]) {
        config[key] = {};
      }

      Object.keys(source[key] || {}).forEach(function (nestedKey) {
        config[key][nestedKey] = source[key][nestedKey];
      });
    });

    return config;
  }

  function resolveChannelEntry(config, channel) {
    var entry = config[channel] || {};
    return {
      image: entry.image || entry.fallbackImage || "",
      fallbackImage: entry.fallbackImage || "",
      alt: entry.alt || "二维码预览图",
      hint: entry.hint || ""
    };
  }

  function applyImageSource(node, entry) {
    if (!node || !entry) {
      return;
    }

    var primaryImage = entry.image || "";
    var fallbackImage = entry.fallbackImage || "";

    node.removeAttribute("data-community-fallback-applied");

    if (fallbackImage && primaryImage && fallbackImage !== primaryImage) {
      node.onerror = function () {
        if (node.dataset.communityFallbackApplied === "1") {
          return;
        }
        node.dataset.communityFallbackApplied = "1";
        node.src = fallbackImage;
      };
    } else {
      node.onerror = null;
    }

    if (primaryImage) {
      node.setAttribute("src", primaryImage);
    }

    node.setAttribute("alt", entry.alt || "二维码预览图");
  }

  document.addEventListener("DOMContentLoaded", function () {
    var config = mergeConfig(DEFAULT_COMMUNITY_CONFIG, window.CLAWSTART_COMMUNITY_CONFIG);
    window.CLAWSTART_COMMUNITY = {
      getEntry: function (channel) {
        return resolveChannelEntry(config, channel);
      },
      getImage: function (channel) {
        return resolveChannelEntry(config, channel).image;
      }
    };

    // 覆盖全局 showQrModal 函数，自动使用真实图片路径而非 placeholder
    var originalShowQrModal = window.showQrModal;
    window.showQrModal = function (channel, title, desc, placeholderImage) {
      var entry = resolveChannelEntry(config, channel);
      var realImage = entry.image || placeholderImage;
      
      if (originalShowQrModal) {
        return originalShowQrModal(channel, title, desc, realImage);
      }
      
      // 如果没有原始函数，直接执行默认逻辑
      var qrModal = document.getElementById('qrModal');
      var qrModalIcon = document.getElementById('qrModalIcon');
      var qrModalTitle = document.getElementById('qrModalTitle');
      var qrModalDesc = document.getElementById('qrModalDesc');
      var qrModalImage = document.getElementById('qrModalImage');
      var qrModalHint = document.getElementById('qrModalHint');
      
      var iconMap = { 'wecom': '💼', 'qq': '🐧', 'wechat': '💬', 'planet': '🪐' };
      var hintMap = {
        'wecom': '打开微信扫码添加企业微信',
        'qq': '打开 QQ 扫码加入群聊',
        'wechat': '打开微信扫码加入群聊',
        'planet': '打开微信扫码加入知识星球'
      };
      
      qrModalIcon.textContent = iconMap[channel] || '💬';
      qrModalTitle.textContent = title;
      qrModalDesc.textContent = desc;
      qrModalImage.src = realImage;
      qrModalHint.textContent = entry.hint || hintMap[channel] || '扫码即可加入';
      qrModal.classList.add('show');
    };

    document.querySelectorAll("[data-community-image]").forEach(function (node) {
      var channel = node.dataset.communityImage;
      var entry = resolveChannelEntry(config, channel);
      applyImageSource(node, entry);
    });

    document.querySelectorAll("[data-community-link]").forEach(function (node) {
      var channel = node.dataset.communityLink;
      var entry = resolveChannelEntry(config, channel);
      if (entry.image) {
        node.setAttribute("href", entry.image);
      }
    });

    document.querySelectorAll("[data-community-hint]").forEach(function (node) {
      var channel = node.dataset.communityHint;
      var entry = resolveChannelEntry(config, channel);
      node.textContent = entry.hint;
    });
  });
})();
