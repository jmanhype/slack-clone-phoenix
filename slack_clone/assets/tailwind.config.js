// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/slack_clone_web.ex",
    "../lib/slack_clone_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        slack: {
          purple: "#4A154B",
          "dark-purple": "#3E1242",
          "light-purple": "#ECE8F1",
          green: "#2EB67D",
          blue: "#1264A3",
          red: "#E01E5A",
          orange: "#FF6B35",
          yellow: "#FFD23F",
          bg: {
            primary: "#FFFFFF",
            secondary: "#F8F8F8",
            tertiary: "#F4F4F4",
            sidebar: "#3F0E40",
            channel: "#1A0B1E",
            hover: "rgba(255,255,255,0.1)",
            active: "rgba(255,255,255,0.2)",
          },
          text: {
            primary: "#1D1C1D",
            secondary: "#616061",
            muted: "#868686",
            "on-dark": "#FFFFFF",
            "on-dark-muted": "rgba(255,255,255,0.7)",
          },
          border: {
            DEFAULT: "#E1E1E1",
            dark: "rgba(255,255,255,0.13)",
            focus: "#1264A3",
          }
        }
      },
      fontFamily: {
        slack: ['Lato', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
      },
      fontSize: {
        'slack-xs': ['0.75rem', '1rem'],
        'slack-sm': ['0.875rem', '1.25rem'],
        'slack-base': ['0.9375rem', '1.375rem'],
        'slack-lg': ['1.125rem', '1.5rem'],
      },
      spacing: {
        'slack-sidebar': '240px',
        'slack-channels': '260px',
        'slack-thread': '320px',
      },
      boxShadow: {
        'slack': '0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24)',
        'slack-lg': '0 4px 6px rgba(0,0,0,0.07), 0 1px 3px rgba(0,0,0,0.06)',
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ]
}
