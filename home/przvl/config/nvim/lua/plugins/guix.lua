-- Guix-specific integration. The rest of this tree is copied intact from Blix.
-- Ordinary downloaded Linux executables do not have Guix's store paths.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { mason = false },
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = { fuzzy = { implementation = "lua" } },
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- StyLua is absent from the pinned official Guix channel. Use the
      -- configured LSP formatting fallback instead of a Mason executable.
      opts.formatters_by_ft.lua = {}
    end,
  },
}
