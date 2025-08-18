-- ~/.config/nvim/lua/snippets/typescriptreact.lua
-- TSX snippets tailored for your codebase (DCI, CSS Modules, classnames, Sanity, Shopify, forms)

local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

-- ========= Helpers =========
local function pesc(s)
  return (s:gsub("([^%w])", "%%%1"))
end

local function sr(trig_regex, nodes, opts)
  opts = opts or {}
  local base = {
    trig = trig_regex,
    regTrig = true,
    wordTrig = false,
    show_condition = function(line)
      -- only show when cursor word matches the regex suffix
      return line:match(trig_regex .. "$") ~= nil
    end,
  }
  return s(vim.tbl_extend("force", base, opts), nodes)
end

local function srp(prefix, nodes, opts)
  return sr(pesc(prefix) .. "%w*", nodes, opts) -- matches prefix + rest of the word
end

local function base_name()
  local base = vim.fn.expand("%:t:r")
  if base == nil or base == "" then
    return "Component"
  end
  local out = {}
  for w in tostring(base):gmatch("[A-Za-z0-9]+") do
    out[#out + 1] = (w:sub(1, 1):upper() .. w:sub(2))
  end
  return table.concat(out)
end

-- current group (e.g. "home", "product") from .../components/<group>/File.tsx
local function current_group()
  local dir = vim.fn.expand("%:h")
  local g = dir:match("/components/([^/]+)/")
  return g
end

-- relative path to components/<group>/<file> from current file
local function rel_import(group, file)
  local g = current_group()
  if not g then
    return ("~/components/%s/%s"):format(group, file)
  end
  if g == group then
    return ("./%s"):format(file)
  end
  return ("../%s/%s"):format(group, file)
end

local function insert_after_imports(line_to_insert)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local insert_at = 0
  for idx, line in ipairs(lines) do
    if line:match("^import%s") then
      insert_at = idx
    elseif insert_at > 0 and not line:match("^%s*$") and not line:match("^//") then
      break
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, { line_to_insert })
  return insert_at
end

local function ensure_default_import(alias, from)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local pat = "^import%s+" .. pesc(alias) .. "%s+from%s+['\"]" .. pesc(from) .. "['\"];?%s*$"
  for _, line in ipairs(lines) do
    if line:match(pat) then
      return
    end
  end
  insert_after_imports(('import %s from "%s";'):format(alias, from))
end

local function ensure_named_import(name, from)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local from_pat = "['\"]" .. pesc(from) .. "['\"]%s*;?%s*$"
  for idx, line in ipairs(lines) do
    if line:match("^import%s+.*from%s+" .. from_pat) then
      if line:match("{") then
        if line:match("{[^}]*%f[%w]" .. pesc(name) .. "%f[^%w][^}]*}") then
          return
        end
        local updated = line:gsub("{%s*", "{ "):gsub("%s*}%s*from", ", " .. name .. " } from")
        vim.api.nvim_buf_set_lines(bufnr, idx - 1, idx, false, { updated })
        return
      else
        insert_after_imports(('import { %s } from "%s";'):format(name, from))
        return
      end
    end
  end
  insert_after_imports(('import { %s } from "%s";'):format(name, from))
end

local function ensure_styles_import()
  local base = vim.fn.expand("%:t:r")
  if base == nil or base == "" then
    base = "Component"
  end
  local path = "./" .. base .. ".module.scss"
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local pat = "^import%s+styles%s+from%s+['\"]" .. pesc(path) .. "['\"];?%s*$"
  for _, line in ipairs(lines) do
    if line:match(pat) then
      return
    end
  end
  insert_after_imports(('import styles from "%s";'):format(path))
end

-- group-aware helpers
local function imp_default(group, alias, file)
  ensure_default_import(alias, rel_import(group, file or alias))
end
local function imp_named(group, name, file)
  ensure_named_import(name, rel_import(group, file or name))
end

-- ========= Snippets =========
return {
  srp("clas", { t("className={styles."), i(1), t("}") }, {
    desc = "className={styles.foo}",
    snippetType = "autosnippet",
  }),
  s("cn", {
    f(function()
      ensure_default_import("cn", "classnames")
      return ""
    end, {}),
    t("cn("),
    i(1),
    t(")"),
  }),

  srp("export c", {
    t("export const "),
    f(function()
      return base_name()
    end, {}),
    i(1),
  }, {
    snippetType = "autosnippet",
  }),
  srp(": DCI", {
    f(function()
      ensure_styles_import()
      ensure_named_import("DCI", "~/types/DCI")
      return ""
    end, {}),
    t(": DCI = ({ className,  }) => {"),
    i(1),
  }, {
    snippetType = "autosnippet",
  }),

  srp("return (", {
    f(function()
      ensure_styles_import()
      ensure_default_import("cn", "classnames")
      return ""
    end, {}),
    t("return ("),
    t("<div className={cn(className,styles.container)}>"),
    i(1),
    t("</div>"),
    t(");"),
  }, {
    snippetType = "autosnippet",
  }),
  srp("icom", {
    f(function()
      ensure_styles_import()
      ensure_default_import("cn", "classnames")
      ensure_named_import("DCI", "~/types/DCI")
      return ""
    end, {}),
    t("const "),
    f(function()
      return base_name()
    end, {}),
    t(": DCI<"),
    i(1, "{ }"),
    t({ "> = ({ className, ...props }) => {", "  return (" }),
    t({ "", "    <div className={cn(styles.container, className)}>" }),
    i(0),
    t({ "</div>", "  )", "}", "", "export default " }),
    f(function()
      return base_name()
    end, {}),
    t(";"),
  }, {
    snippetType = "autosnippet",
  }),
  srp("ihook", {
    t("export const "),
    f(function()
      return base_name()
    end, {}),
    t({ " = () => {" }),
    i(1),
    t({ "}" }),
  }, {
    snippetType = "autosnippet",
  }),

  -- ===== Sanity patterns =====
  -- <SanityImage className={styles.image} asset={...} />
  srp("<SanityIm", {
    f(function()
      imp_default("sanity", "SanityImage") -- ../sanity/SanityImage
      ensure_styles_import()
      return ""
    end, {}),
    t("<SanityImage className={styles.image} asset={"),
    i(1, "asset"),
    t("}"),
    t({ " />" }),
  }, {
    snippetType = "autosnippet",
  }),

  srp("<SanityCo", {
    f(function()
      imp_default("sanity", "SanityContent") -- ../sanity/SanityImage
      ensure_styles_import()
      return ""
    end, {}),
    t("<SanityContent className={styles.content} blocks={"),
    i(1, "blocks"),
    t("}"),
    t({ " />" }),
  }, {
    snippetType = "autosnippet",
  }),

  srp("<SanityLi", {
    f(function()
      imp_default("sanity", "SanityLink") -- ../sanity/SanityImage
      ensure_styles_import()
      return ""
    end, {}),
    t("<SanityContent className={styles.link} link={"),
    i(1, "link"),
    t("}"),
    t({ " />" }),
  }, {
    snippetType = "autosnippet",
  }),

  --
  -- -- ===== Shopify media =====
  -- s("shopimg", {
  --   f(function()
  --     imp_default("shopify", "ShopifyImage")
  --     return ""
  --   end, {}),
  --   t("<ShopifyImage image={"),
  --   i(1, "image"),
  --   t("} ratio={"),
  --   i(2, "5/7"),
  --   t("} />"),
  -- }),
  -- s("shopmedia", {
  --   f(function()
  --     imp_default("shopify", "ShopifyMedia")
  --     return ""
  --   end, {}),
  --   t("<ShopifyMedia media={"),
  --   i(1, "media"),
  --   t("} ratio={"),
  --   i(2, "7/10"),
  --   t("} />"),
  -- }),
  --
  -- -- ===== Pricing =====
  -- s("prender", {
  --   f(function()
  --     imp_default("price", "PriceRender")
  --     return ""
  --   end, {}),
  --   t("<PriceRender amount={"),
  --   i(1, "amountNumber"),
  --   t("}"),
  --   t({ " />" }),
  -- }),
  -- s("pprice", {
  --   f(function()
  --     imp_default("product", "ProductPrice")
  --     return ""
  --   end, {}),
  --   t("<ProductPrice shopifyProduct={"),
  --   i(1, "product.shopify"),
  --   t("}"),
  --   t({ " />" }),
  -- }),
  -- s("prange", {
  --   f(function()
  --     imp_default("price", "PriceRange")
  --     return ""
  --   end, {}),
  --   t("<PriceRange priceRange={"),
  --   i(1, "product.shopify.priceRange"),
  --   t("} showCurrency={"),
  --   i(2, "true"),
  --   t("} />"),
  -- }),
  --
  -- -- ===== Common links =====
  -- s("cl", {
  --   f(function()
  --     imp_default("common", "CommonLink")
  --     return ""
  --   end, {}),
  --   t('<CommonLink mode="'),
  --   i(1, "FADE_OUT"),
  --   t('" href="'),
  --   i(2, "/"),
  --   t('">'),
  --   i(3, "Label"),
  --   t({ "</CommonLink>" }),
  -- }),
  -- s("ccl", {
  --   f(function()
  --     imp_default("common", "CommonCoverLink")
  --     return ""
  --   end, {}),
  --   t('<CommonCoverLink href="'),
  --   i(1, "/"),
  --   t('">'),
  --   i(2, "Hidden label"),
  --   t({ "</CommonCoverLink>" }),
  -- }),
  --
  -- -- ===== Forms (useAppForm + AppField family) =====
  -- s("useform", {
  --   f(function()
  --     ensure_named_import("useAppForm", "~/hooks/useForm")
  --     return ""
  --   end, {}),
  --   t({ "const form = useAppForm({", "  defaultValues: { " }),
  --   i(1, "name: ''"),
  --   t({ " },", "  validators: {", "    onSubmit: ({ value }) => ({", "      fields: { " }),
  --   i(2, "name: value.name ? undefined : 'Required'"),
  --   t({
  --     " },",
  --     "    }),",
  --     "  },",
  --     "  onSubmit: async ({ value }) => {",
  --     "    ",
  --     i(3, "console.log(value)"),
  --     "",
  --     "  },",
  --     "})",
  --   }),
  -- }),
  -- s("formwrap", {
  --   t({ "<form className={styles.form} onSubmit={(e) => { e.preventDefault(); form.handleSubmit(); }}>", "  " }),
  --   i(0),
  --   t({ "", "</form>" }),
  -- }),
  -- s("afieldtxt", {
  --   t('<form.AppField name="'),
  --   i(1, "field"),
  --   t({ '" children={(field) => (', '  <field.InputText label="' }),
  --   i(2, "Label"),
  --   t({ '" />', ")}", "}/>" }),
  -- }),
  -- s("afieldarea", {
  --   t('<form.AppField name="'),
  --   i(1, "field"),
  --   t({ '" children={(field) => (', '  <field.InputTextArea className={styles.wide} label="' }),
  --   i(2, "Message"),
  --   t({ '" />', ")}", "}/>" }),
  -- }),
  -- s("afieldradio", {
  --   t('<form.AppField name="'),
  --   i(1, "accept"),
  --   t({ '" children={(field) => (', '  <field.InputRadio mode="' }),
  --   i(2, "MUTE"),
  --   t({ '" label="' }),
  --   i(3, "I agree"),
  --   t({ '" />', ")}", "}/>" }),
  -- }),
  -- s("afieldsubmit", {
  --   t({ "<form.AppForm>", "  <div className={styles.submit}>", '    <form.InputSubmit label="' }),
  --   i(1, "Submit"),
  --   t({ '" />', "  </div>", "</form.AppForm>" }),
  -- }),
  --
  -- -- ===== Popup & toggles =====
  -- s("usepopup", {
  --   f(function()
  --     ensure_named_import("usePopup", "~/hooks/usePopup")
  --     return ""
  --   end, {}),
  --   t("const [popup, setPopup] = usePopup()"),
  -- }),
  -- s("togglenews", {
  --   f(function()
  --     ensure_named_import("usePopup", "~/hooks/usePopup")
  --     return ""
  --   end, {}),
  --   t({ 'onClick={() => setPopup(popup === "' }),
  --   i(1, "NEWSLETTER"),
  --   t({ '" ? "" : "' }),
  --   f(function(args)
  --     return args[1][1]
  --   end, { 1 }),
  --   t({ '")})' }),
  -- }),
  -- s("hover", {
  --   f(function()
  --     ensure_named_import("useHoverToggle", "~/hooks/useHoverToggle")
  --     return ""
  --   end, {}),
  --   t({
  --     "const { isOpen, handleMouseEnter, handleMouseLeave, handleClick, close } = ",
  --     "  useHoverToggle({ disabled: ",
  --   }),
  --   i(1, "false"),
  --   t({ ", delay: " }),
  --   i(2, "150"),
  --   t({ " })" }),
  -- }),
  --
  -- -- ===== Util overlays =====
  -- s("uref", {
  --   f(function()
  --     imp_default("util", "UtilReference")
  --     return ""
  --   end, {}),
  --   t('<UtilReference name="'),
  --   i(1, "home"),
  --   t('" />'),
  -- }),
  -- s("ugrid", {
  --   f(function()
  --     imp_default("util", "UtilGrid")
  --     return ""
  --   end, {}),
  --   t("<UtilGrid />"),
  -- }),
  --
  -- -- ===== Slideshow bits =====
  -- s("slprov", {
  --   f(function()
  --     imp_named("slideshow", "SlideshowProvider", "SlideshowDefault") -- same folder group "slideshow"
  --     imp_default("slideshow", "SlideshowDefault")
  --     return ""
  --   end, {}),
  --   t({ "<SlideshowProvider settings={{ align: 'start', containScroll: 'keepSnaps' }}>", "  " }),
  --   t("<SlideshowDefault>"),
  --   i(1, "<div />"),
  --   t({ "</SlideshowDefault>", "</SlideshowProvider>" }),
  -- }),
  --
  -- -- ===== Misc =====
  -- s("dshtml", {
  --   t("dangerouslySetInnerHTML={{ __html: "),
  --   i(1, "htmlString"),
  --   t(" }}"),
  -- }),
  -- s("cont", {
  --   t("<div className={cn(styles.container, className)}>"),
  --   i(0),
  --   t("</div>"),
  -- }),
}
