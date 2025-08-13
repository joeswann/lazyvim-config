# AI Snippets Integration with blink.cmp

Enhanced AI code completion system with full blink.cmp snippet support.

## Features

### 🔧 **Smart Snippet Expansion**
- Automatically detects snippet placeholders (`${1:placeholder}`)
- Converts common patterns to snippets:
  - Function calls: `myFunc(param)` → `myFunc(${1:param})`
  - Assignments: `= value` → `= ${1:value}`
- Supports tab navigation through placeholders

### 🎨 **Enhanced Visual Feedback**
- **AI Icon**: 🤖 for all AI completions
- **Snippet Indicator**: ✨ for snippet-expandable completions
- **Regular AI**: 🔮 for plain text completions
- **Source Attribution**: "• AI Generated" in details
- **Syntax Highlighting**: Markdown code blocks in documentation

### ⚡ **Smart Triggering**
- **Basic Triggers**: `.`, `>`, `:`, `=`, ` `, `(`
- **Snippet Triggers**: `\n`, `}`, `)`, `]`, `;`, `,`
- **Word Starts**: `f`, `c`, `i`, `a`, `v`, `l`, `d`

### 🧠 **Context-Aware Generation**
- Uses dependency files (package.json, requirements.txt, etc.)
- Leverages import analysis and project structure
- Filetype-specific patterns and behaviors
- Project root detection and path resolution

## Configuration

### Basic Setup
```lua
-- Already configured in plugins/ai-snippets.lua
-- Uses ai_context system for smart dependency detection
```

### Advanced Customization
```lua
-- Modify trigger characters
source:get_trigger_characters = function()
  return { "your", "custom", "triggers" }
end

-- Customize transform_items
transform_items = function(_, items)
  for _, item in ipairs(items) do
    item.kind_icon = "your_icon"
    item.label = "prefix " .. item.label
  end
  return items
end
```

## Architecture

### Component Structure
```
ai_snippets/
├── blink_source.lua    # Main blink.cmp integration
├── engine.lua          # AI API communication
└── source.lua          # Legacy nvim-cmp compatibility

ai_context/             # Shared context system
├── builder.lua         # Main context builder
├── typescript.lua      # TypeScript/JS patterns
├── python.lua          # Python patterns
└── generic.lua         # Fallback patterns

ai_core/               # Shared AI infrastructure
├── mcp.lua            # Model Context Protocol support
└── mcp_config_example.lua
```

### Integration Points
1. **Blink Source**: Implements blink.cmp provider interface
2. **Context Builder**: Provides rich project context
3. **AI Engine**: Communicates with AI APIs (Anthropic/OpenRouter)
4. **MCP Support**: Optional Model Context Protocol integration

## Snippet Format Support

### LSP Snippet Format
- `${1:placeholder}` - Numbered placeholders
- `${1|option1,option2|}` - Choice placeholders
- `$0` - Final cursor position

### Auto-Generated Patterns
- **Function Calls**: Parentheses content becomes placeholder
- **Variable Assignments**: Right-hand side becomes placeholder
- **Object Properties**: Values become placeholders

## Performance

### Optimizations
- 200ms debouncing (faster than Copilot's 750ms)
- Parallel API requests for multiple models
- Context size limits to balance speed vs accuracy
- Filetype-specific dependency loading

### Caching
- Request cancellation on rapid typing
- Context reuse within editing session
- Dependency file caching

## API Configuration

### Environment Variables
```bash
# Primary providers (choose one)
export ANTHROPIC_API_KEY="your-key"      # Claude Haiku (fastest)
export OPENROUTER_API_KEY="your-key"     # Multiple models

# Optional MCP integration
export MCP_SERVER_URL="http://localhost:8000"
export MCP_API_KEY="optional-auth-key"
```

### Model Selection
- **Anthropic**: Claude-3-Haiku (optimized for speed)
- **OpenRouter**: Multiple fast models in parallel
- **MCP**: Custom model servers

## Troubleshooting

### Debug Mode
```lua
-- Enable debug logging
print("[AI_SNIPPETS] Debug message")
```

### Common Issues
1. **No completions**: Check API keys and network
2. **Slow responses**: Reduce context size in configuration
3. **Wrong snippets**: Verify filetype detection
4. **Missing dependencies**: Check ai_context modules

## Future Enhancements
- [ ] Custom snippet templates per project
- [ ] Learning from user acceptance patterns
- [ ] Integration with more AI providers
- [ ] Collaborative filtering of suggestions