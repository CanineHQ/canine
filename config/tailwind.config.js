// See the Tailwind default theme values here:
// https://github.com/tailwindcss/tailwindcss/blob/master/stubs/defaultConfig.stub.js
const colors = require('tailwindcss/colors')
const defaultTheme = require('tailwindcss/defaultTheme');
import theme from "daisyui/src/theming/themes"

/** @type {import('tailwindcss').Config */
module.exports = {
  darkMode: 'class',

  plugins: [
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('daisyui'),
  ],

  content: [
    './app/javascript/**/*.js',
    './app/views/**/*.erb',
    './public/*.html',
  ],
  theme: {
    extend: {
      fontSize: {
        xs: "11px",
        sm: "13px",
        base: "15px",
      },
    },
    container: {
      center: true,
      padding: {
        "DEFAULT": "1rem",
        "sm": "2rem",
        "md": "3rem",
        "lg": "4rem",
        "xl": "5rem",
        "2xl": "6rem",
      },
    },
    fontFamily: {
      body: ["DM Sans", "sans-serif"],
    },
  },
  darkMode: "class",
  daisyui: {
    themes: [
      {
        light: {
          ...theme.light,

          "primary": "#3e5eff",
          "primary-content": "#ffffff",
          "secondary": "#494949",
          "secondary-content": "#ffffff",
          "info": "#00a6ff",
          "info-content": "#ffffff",
          "success": "#28a745",
          "success-content": "#ffffff",
          "warning": "#f5a524",
          "warning-content": "#150a00",
          "error": "#f3124e",
          "error-content": "#ffffff",

          "base-100": "#ffffff",
          "base-200": "#e6e9ec",
          "base-300": "#dfe2e6",
          "base-content": "#1e2328",

          "--rounded-box": "0.25rem",
          "--rounded-btn": "0.25rem",
          "--padding-card": "20px",

          "--main-content-background": "#f2f5f8",
          "--leftmenu-background": "#ffffff",
          "--topbar-background": "#ffffff",
        },
        dark: {
          ...theme.dark,

          "primary": "#167bff",
          "primary-content": "#ffffff",
          "secondary": "#494949",
          "secondary-content": "#ffffff",
          "info": "#00e1ff",
          "info-content": "#ffffff",
          "success": "#17c964",
          "success-content": "#ffffff",
          "warning": "#f5a524",
          "warning-content": "#150a00",
          "error": "#f31260",
          "error-content": "#ffffff",

          "base-100": "#191e23",
          "base-200": "#252b32",
          "base-300": "#2a3038",

          "base-content": "#dcebfa",
          "--rounded-box": "0.25rem",
          "--rounded-btn": "0.25rem",

          "--main-content-background": "#14181c",
          "--leftmenu-background": "#1e2328",
          "--topbar-background": "#191e23",
        },
      },
    ],
  },
  safelist: [
    'bg-success/10', 'text-success',
    {
      pattern: /text-(gray|red|green|yellow|blue|purple|cyan)-(1|3|4|5)00/ // LogColorsHelper uses custom tailwind colors
    }
  ]
}
