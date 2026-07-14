#!/usr/bin/env bash

{
  echo "===== versions ====="
  nvim --version | head -1; git --version
  echo "===== git config (checking for ssh rewrites) ====="
  git config --list --show-origin | grep -iE 'url\.|insteadof|protocol' || echo '(none)'
  echo "===== lazy sync (clone/build errors here) ====="
  nvim --headless "+Lazy! sync" +qa
  echo "===== lazy error state ====="
  nvim --headless "+lua for _,p in ipairs(require('lazy').plugins()) do if p._ and p._.error then io.stderr:write(p.name..': '..tostring(p._.error)..'\n') end end" +qa
  echo "===== luasnip submodule origin (ssh vs https?) ====="
  ls ~/.local/share/nvim/lazy/luasnip/deps 2>&1
  git -C ~/.local/share/nvim/lazy/luasnip remote get-url origin 2>&1
  git -C ~/.local/share/nvim/lazy/luasnip/deps/jsregexp remote get-url origin 2>&1
  echo "===== yazi submodule ====="
  ls ~/.local/share/nvim/lazy/yazi.nvim/yazi-plugin 2>&1
} > ~/nvim-debug.log 2>&1
echo "wrote ~/nvim-debug.log"
