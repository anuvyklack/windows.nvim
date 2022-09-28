# windows.nvim

- Automatically expand width of the current window;
- Maximizes and restores the current window.

And all this with nice animations!

https://user-images.githubusercontent.com/13056013/190786962-01047891-38b1-4e87-bd9b-e8eca9acc8b8.mp4

## Installation and setup

This plugin requires next dependencies:

- [middleclass](https://github.com/anuvyklack/middleclass)  
- [animation.nvim](https://github.com/anuvyklack/animation.nvim) — optional:
  needed if you want animations

Also, if you enable animations, is recommended to set `winwidth`, `winminwidth`
options to some reasonable and equal values (between 5 and 20 will be OK), and
disable `equalalways` option.

You can install and setup **windows.nvim** with [packer](https://github.com/wbthomason/packer.nvim)
plugin manager using next snippet:

- with animation
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

- without animation
  ```lua
  use { "anuvyklack/windows.nvim",
     requires = "anuvyklack/middleclass",
     config = function()
        require('windows').setup()
     end
  }
  ```

## Configuration

Read about plugins configuration in the [documentation](https://github.com/anuvyklack/windows.nvim/blob/main/doc/windows.txt).

## Commands

- `:WindowsMaximize`

  Maximize current window. If the window is already maximized, then restore
  original sizes.  When go to another window while current is maximized - all
  original sizes will be restored.  If the window will be closed while being
  maximized, then all other windows would be equalized.

- `:WindowsMaximizeVertically`

  Maximize width of the current window. Almost the same as `:vertical resize`
  (see `:help CTRL-W_bar'`) but with animation.

- `:WindowsMaximizeHorizontally`

  Maximize height of the current window. Almost the same as `:resize`
  (see `:help CTRL-W__`) but with animation.

- `:WindowsEqualize`

  Equalize all windows heights and widths width animation.
  (see `:help CTRL-W_=`)

- `:WindowsEnableAutowidth`  
  `:WindowsDisableAutowidth`  
  `:WindowsToggleAutowidth`

  Enable, disable or toggle auto-width feature.

## Keymapings

If you want a keymaps thees are a fitting choice:

```lua
local function cmd(command)
   return table.concat({ '<Cmd>', command, '<CR>' })
end

vim.keymap.set('n', '<C-w>z', cmd 'WindowsMaximize')
vim.keymap.set('n', '<C-w>_', cmd 'WindowsMaximizeVertically')
vim.keymap.set('n', '<C-w>|', cmd 'WindowsMaximizeHorizontally')
vim.keymap.set('n', '<C-w>=', cmd 'WindowsEqualize')
```

## Proposals

If you have any proposals, what else can be done with this mechanics, you are
welcome to open an issue.
