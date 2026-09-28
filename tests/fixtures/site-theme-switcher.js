import { rocket } from "datastar-pro";

rocket("site-theme-switcher", {
  mode: "light",
  props: ({ string }) => ({
    lightLabel: string.trim.default("Switch to light theme"),
    darkLabel: string.trim.default("Switch to dark theme"),
  }),
  setup: ({ $$, $, props }) => {
    $$.actionLabel = () => $._theme === "light" ? props.darkLabel : props.lightLabel;
  },
  render: ({ html, props: { lightLabel, darkLabel } }) => html`
    <button
      type="button"
      class="site-button site-theme-switcher__button"
      aria-label="${lightLabel}"
      hidden
      data-ref:toggle
      data-attr:aria-label="$$actionLabel"
      data-on:click__viewtransition="$_theme = $_theme === 'light' ? 'dark' : 'light'"
    >
      <svg class="theme-icon theme-icon--sun" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <circle cx="12" cy="12" r="3.5" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
      <svg class="theme-icon theme-icon--moon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <path d="M20 15.2A8.5 8.5 0 0 1 8.8 4 8.5 8.5 0 1 0 20 15.2Z" />
      </svg>
    </button>
  `,
  onFirstRender: ({ refs }) => {
    refs.toggle.hidden = false;
  },
});
