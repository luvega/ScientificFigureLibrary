// Progressive enhancement only: navigation and documentation work without JS.
if (navigator.clipboard?.writeText && window.isSecureContext) {
  document.documentElement.classList.add("copy-ready");
  for (const button of document.querySelectorAll(".copy-code")) {
    button.addEventListener("click", async () => {
      const code = button.closest(".code-block")?.querySelector("pre code");
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code.textContent ?? "");
        button.textContent = "已复制";
        button.setAttribute("aria-label", "代码已复制");
      } catch {
        button.textContent = "请手动选择代码";
      }
      window.setTimeout(() => {
        button.textContent = "复制代码";
        button.setAttribute("aria-label", "复制代码");
      }, 2000);
    });
  }
}
