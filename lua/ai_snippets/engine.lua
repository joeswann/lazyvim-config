local E = {}

local Client = require("ai_client.client")

local function get_system_prompt()
  return table.concat({
    "You are a fast code completion engine for Neovim.",
    "You receive a context object with:",
    "- before: lines before cursor",
    "- current: text on current line up to cursor position",
    "- after: lines after cursor",
    "- snippets: array of {name, array_text} with snippet definitions",
    "- imports: already imported modules with their code samples",
    "- dependencies: available packages",
    "- github_similar: similar files from other projects with the same name",
    "",
    "COMPLETION RULES:",
    "- Analyze the context to understand what the user is typing",
    "- Try to complete from the CURRENT line using the context to guess what the user will type next",
    "- If the user appears to be using shorthand (emmet style etc), attempt to complete based on their intention",
    -- "- Do not complete earlier or later lines, and do not remove text in the current line",
    "- If context contains relevant code, adapt as needed. use directly ONLY when everything else matches",
    "- Match the user's typing pattern - don't suggest unrelated components",
    "- Only use snippets from context.snippets when the user is actually typing something that matches",
    "- If adding a new component, remember to import it using the additionalTextEdits response",
    "",
    "CRITICALLY IMPORTANT RULES DO NOT FORGET THESE",
    "- Response must be ONLY valid JSON in the exact structure below",
    "- newText: The actual code to insert at cursor (just the code, no JSON).",
    "- label: Brief description (max 40 chars).",
    "- range: These are the start and end coordinates of the replacement(s) 0-indexed line and character, end-exclusive",
    "--  the LSP line is offset -1 from the cursor, so if cursor line is 9 to edit it you would use 8",
    "--  your line replacement should start from the beginning of the text you are replacing and end at the end of the text, wrap it completely or it will cause duplicates",
    "--  your character replacement should start from the start column of the text you are replacing and finish at the last column, usually the column at the end of the line being replaced",
    "- Always output JSON only (no before or after text, no fences, no markdown, no backticks, no extra text) this is ABSOLUTELY CRITICAL.",
    "",
    "{",
    '  "label":"description",',
    '  "newText":"completed code to insert",',
    '  "range": {',
    '    "start": {',
    '      "line": 0,',
    '      "character": 0',
    "    },",
    '    "end": {',
    '      "line": 0,',
    '     "character": 0',
    "    }",
    "  },",
    '  additionalTextEdits": [',
    "    {",
    '      "newText": "additional code to insert, eg import..."',
    '      "range": {',
    '        "start": {',
    '          "line": 0,',
    '          "character": 0',
    "        },",
    '        "end": {',
    '          "line": 0,',
    '          "character": 0',
    "        }",
    "      },",
    "    }",
    "  ]",
    "}",
  }, "\n")
end

-- Parse response and extract completion JSON
local function parse_completion_response(response_text)
  if not response_text then
    return nil
  end

  local clean_text = response_text:gsub("\n", "") or ""
  local ok, json = pcall(vim.json.decode, clean_text)
  if ok and json then
    return json
  end

  return nil
end

function E.suggest(ctx, cb)
  local client = Client.get_default_client()

  if not client then
    return cb(false, nil)
  end

  local config = client.get_config()
  if not config then
    return cb(false, nil)
  end

  client.make_request(ctx, config, get_system_prompt(), function(response_text)
    local result = parse_completion_response(response_text)
    print(vim.inspect(response_text))
    print(vim.inspect(result))

    if result then
      cb(true, { result })
    end

    cb(false, nil)
  end)

  return function() end
end

return E
