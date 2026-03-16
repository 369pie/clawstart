(function () {
  var STORAGE_KEY = "clawstart-analytics-events";
  var MAX_EVENTS = 100;
  var DEFAULT_CONFIG = {
    provider: "plausible",
    plausible: {
      enabled: true,
      domain: window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
        ? "nicekate.github.io"
        : window.location.hostname,
      scriptSrc: "https://plausible.io/js/script.js",
      apiHost: "",
      trackLocalhost: false
    }
  };

  function mergeConfig(baseConfig, overrideConfig) {
    var config = JSON.parse(JSON.stringify(baseConfig));
    var source = overrideConfig || {};

    Object.keys(source).forEach(function (key) {
      if (
        source[key] &&
        typeof source[key] === "object" &&
        !Array.isArray(source[key]) &&
        config[key] &&
        typeof config[key] === "object"
      ) {
        Object.keys(source[key]).forEach(function (nestedKey) {
          config[key][nestedKey] = source[key][nestedKey];
        });
      } else {
        config[key] = source[key];
      }
    });

    return config;
  }

  var runtimeConfig = mergeConfig(DEFAULT_CONFIG, window.CLAWSTART_ANALYTICS_CONFIG);

  function initPlausible(config) {
    if (!config || !config.enabled) return;
    if (!config.trackLocalhost && (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1")) {
      return;
    }
    if (document.querySelector('script[data-clawstart-provider="plausible"]')) {
      return;
    }

    window.plausible = window.plausible || function () {
      (window.plausible.q = window.plausible.q || []).push(arguments);
    };

    var script = document.createElement("script");
    script.defer = true;
    script.dataset.domain = config.domain;
    script.dataset.clawstartProvider = "plausible";
    if (config.apiHost) {
      script.dataset.api = config.apiHost;
    }
    script.src = config.scriptSrc;
    document.head.appendChild(script);
  }

  function getPageName() {
    var path = window.location.pathname.split("/").pop() || "index.html";
    if (path === "") return "index";
    return path.replace(/\.html$/, "");
  }

  function readEvents() {
    try {
      var raw = window.localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch (error) {
      return [];
    }
  }

  function writeEvents(events) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(events.slice(-MAX_EVENTS)));
    } catch (error) {
      // Ignore storage failures; tracking should never break the page.
    }
  }

  function pushEvent(payload) {
    var events = readEvents();
    events.push(payload);
    writeEvents(events);
  }

  function sendToProviders(name, props) {
    if (typeof window.plausible === "function") {
      window.plausible(name, { props: props });
    }

    if (window.umami && typeof window.umami.track === "function") {
      window.umami.track(name, props);
    }

    if (typeof window.gtag === "function") {
      window.gtag("event", name, props);
    }
  }

  function track(name, props) {
    var payload = {
      event: name,
      props: props || {},
      page: getPageName(),
      path: window.location.pathname,
      ts: new Date().toISOString()
    };

    pushEvent(payload);
    sendToProviders(name, payload.props);
    window.dispatchEvent(new CustomEvent("clawstart:track", { detail: payload }));

    if (window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1") {
      console.debug("[ClawStart analytics]", payload);
    }
  }

  window.clawstartTrack = track;

  if (runtimeConfig.provider === "plausible") {
    initPlausible(runtimeConfig.plausible);
  }

  document.addEventListener("DOMContentLoaded", function () {
    track("page_view", {
      page: getPageName()
    });

    document.querySelectorAll("[data-track]").forEach(function (node) {
      node.addEventListener("click", function () {
        var props = {};

        Object.keys(node.dataset).forEach(function (key) {
          if (key !== "track") {
            props[key] = node.dataset[key];
          }
        });

        track(node.dataset.track, props);
      });
    });
  });
})();
