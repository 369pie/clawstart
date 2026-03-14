(function () {
  // Update these values in one place to publish real private-community entry points site-wide.
  var DEFAULT_COMMUNITY_CONFIG = {
    wecom: {
      image: "assets/community/wecom-qr.png",
      fallbackImage: "assets/community/wecom-qr-placeholder.svg",
      alt: "企业微信二维码预览图",
      hint: "扫码添加企业微信，适合 1 对 1 分流、拉微信群和复杂问题排查。"
    },
    qq: {
      image: "assets/community/qq-qr.png",
      fallbackImage: "assets/community/qq-qr-placeholder.svg",
      alt: "QQ群二维码预览图",
      hint: "扫码加入 QQ 群，适合公开提问、发截图和集中答疑。"
    },
    wechat: {
      image: "assets/community/wechat-qr.png",
      fallbackImage: "assets/community/wechat-qr-placeholder.svg",
      alt: "微信群二维码预览图",
      hint: "扫码进入微信群，适合高频陪跑；如果微信群二维码常变动，建议优先放企微入口。"
    },
    planet: {
      image: "assets/community/planet-qr.png",
      fallbackImage: "assets/community/planet-qr-placeholder.svg",
      alt: "知识星球二维码预览图",
      hint: "扫码进入知识星球，承接案例、模板、更新和后续转化。"
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
