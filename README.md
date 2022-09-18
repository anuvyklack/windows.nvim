# windows.nvim

- Automatically expand width of the current window;
- Maximizes and restores the current window.

And all this with nice animations!

https://user-images.githubusercontent.com/13056013/190786962-01047891-38b1-4e87-bd9b-e8eca9acc8b8.mp4

## Installation and setup

This plugin requires [middleclass](https://github.com/anuvyklack/middleclass)
and [animation.nvim](https://github.com/anuvyklack/animation.nvim) plugins as
dependencies.

Also recomended to set `'winwidth'`, `'winminwidth'` options to some resonable
and equal values (values between 5 and 20 will be OK).

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

- `:WindowsMaximaze`		

  Maximize current window. If the window is already maximized, then restore
  original sizes. When go to another window while current is maximized - all
  original sizes would restore. If the window will be closed while being
  maximized, then all other windows would be equalized.

## Suggestions

If you have any proposals, what else can be done with this mechanics, you are
welcome to open an issue.
