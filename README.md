# windows.nvim

- Automatically expand width of the current window;
- Maximizes and restores the current window.

And all this with nice animations!

https://user-images.githubusercontent.com/13056013/190786962-01047891-38b1-4e87-bd9b-e8eca9acc8b8.mp4

## Installation and setup

This plugin requires next dependencies:

- [middleclass](https://github.com/anuvyklack/middleclass)
- [animation.nvim](https://github.com/anuvyklack/animation.nvim) — optional,
  needed if you want animations

Also, if you enable animations, is recommended to set `winwidth`, `winminwidth`
options to some reasonable and equal values (between 5 and 20 will be OK), and
disable `equalalways` option.

You can install and setup **windows.nvim** with [packer](https://github.com/wbthomason/packer.nvim)
plugin manager using next snippet:

```lua
use { "anuvyklack/windows.nvim",
   requires = {
      "anuvyklack/middleclass",
      "anuvyklack/animation.nvim"
   },
   config = function()
      vim.o.winwidth = 10
      vim.o.winminwidth = 10
      vim.o.equalalways = false
      require('windows').setup()
   end
}
```

## Configuration

Read about plugins configuration in the [documentation](https://github.com/anuvyklack/windows.nvim/blob/main/doc/windows.txt).

## Commands

- `:WindowsEnableAutowidth`
  `:WindowsDisableAutowidth`
  `:WindowsToggleAutowidth`

  Enable, disable or toggle auto-width feature.

- `:WindowsMaximize`

  Maximize current window. If the window is already maximized, then restore
  original sizes. When go to another window while current is maximized - all
  original sizes would restore. If the window will be closed while being
  maximized, then all other windows would be equalized.

  If you want a keymap — `<C-w>z` is a fitting choice:
  ```lua
  vim.keymap.set('n', '<C-w>z', '<Cmd>WindowsMaximize<CR>')
  ```

## Proposals

If you have any proposals, what else can be done with this mechanics, you are
welcome to open an issue.
