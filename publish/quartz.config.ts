import { QuartzConfig } from "./quartz/cfg"
import * as Plugin from "./quartz/plugins"
import { QuartzFilterPlugin } from "./quartz/plugins/types"

/**
 * Configuración de Quartz 4 para publicar wiki/ como sitio web.
 *
 * Este archivo NO se usa desde aquí directamente: el workflow
 * .github/workflows/publish.yml lo copia sobre el quartz.config.ts de un
 * clon de jackyzha0/quartz (rama v4) y construye el sitio con wiki/ como content/.
 *
 * Privacidad (CLAUDE.md §3): toda nota es publicable salvo que tenga
 * `publish: false` en el frontmatter; wiki/sessions/ no se publica nunca
 * (ignorePatterns). Ver docs/publicacion.md.
 */

// Excluye cualquier nota con `publish: false` (o "false") en el frontmatter.
const RemoveUnpublished: QuartzFilterPlugin<{}> = () => ({
  name: "RemoveUnpublished",
  shouldPublish(_ctx, [_tree, vfile]) {
    const fm = vfile.data?.frontmatter as Record<string, unknown> | undefined
    return fm?.publish !== false && fm?.publish !== "false"
  },
})

const config: QuartzConfig = {
  configuration: {
    pageTitle: "Segundo cerebro",
    pageTitleSuffix: "",
    enableSPA: true,
    enablePopovers: true,
    analytics: null,
    locale: "es-ES",
    baseUrl: "deox420.github.io/second-brain",
    // "sessions" = wiki/sessions/ (el workflow copia wiki/ como content/). Nunca se publica.
    ignorePatterns: ["private", "templates", ".obsidian", "sessions"],
    defaultDateType: "modified",
    theme: {
      fontOrigin: "googleFonts",
      cdnCaching: true,
      typography: {
        header: "Schibsted Grotesk",
        body: "Source Sans Pro",
        code: "IBM Plex Mono",
      },
      colors: {
        lightMode: {
          light: "#faf8f8",
          lightgray: "#e5e5e5",
          gray: "#b8b8b8",
          darkgray: "#4e4e4e",
          dark: "#2b2b2b",
          secondary: "#284b63",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#fff23688",
        },
        darkMode: {
          light: "#161618",
          lightgray: "#393639",
          gray: "#646464",
          darkgray: "#d4d4d4",
          dark: "#ebebec",
          secondary: "#7b97aa",
          tertiary: "#84a59d",
          highlight: "rgba(143, 159, 169, 0.15)",
          textHighlight: "#b3aa0288",
        },
      },
    },
  },
  plugins: {
    transformers: [
      Plugin.FrontMatter(),
      Plugin.CreatedModifiedDate({
        priority: ["frontmatter", "git", "filesystem"],
      }),
      Plugin.SyntaxHighlighting({
        theme: {
          light: "github-light",
          dark: "github-dark",
        },
        keepBackground: false,
      }),
      Plugin.ObsidianFlavoredMarkdown({ enableInHtmlEmbed: false }),
      Plugin.GitHubFlavoredMarkdown(),
      Plugin.TableOfContents(),
      Plugin.CrawlLinks({ markdownLinkResolution: "shortest" }),
      Plugin.Description(),
      Plugin.Latex({ renderEngine: "katex" }),
    ],
    filters: [Plugin.RemoveDrafts(), RemoveUnpublished()],
    emitters: [
      Plugin.AliasRedirects(),
      Plugin.ComponentResources(),
      Plugin.ContentPage(),
      Plugin.FolderPage(),
      Plugin.TagPage(),
      Plugin.ContentIndex({
        enableSiteMap: true,
        enableRSS: true,
      }),
      Plugin.Assets(),
      Plugin.Static(),
      Plugin.Favicon(),
      Plugin.NotFoundPage(),
      // CustomOgImages desactivado: acelera el build diario del radar.
    ],
  },
}

export default config
