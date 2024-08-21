# WorkspaceManager.vim

WorkspaceManager.vim is a Vim plugin for managing workspaces and providing a tree-like view of your project structure.

## Table of Contents

1. [Installation](#installation)
2. [Usage](#usage)
3. [Commands](#commands)
4. [Key Mappings](#key-mappings)
5. [FAQ](#faq)

## Installation

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'Wendy-SG/WorkspaceManager.nvim'
```

Then run `:PlugInstall` in NeoVim.

## Usage

WorkspaceManager.nvim allows you to create and manage workspaces, providing a tree-like view of your project structure.
Not available for `vim` users.

To get started:

1. Run `:CreateWorkspace` to initialize the workspace. And write directory into `~/.config/nvim/.WorkSapceManager`
2. Use `:ToggleWorkspaceTree` to open/close the workspace tree view.

## Commands

- `:CreateWorkspace [directory]`: Initialize a workspace. If no directory is specified, the current directory is used.
- `:ToggleWorkspaceTree`: Toggle the workspace tree view.

## Key Mappings

WorkSpaceTree view and WorkSapceList view

In the  WorkSpaceList view:

- `<CR>`: Enter workspace
- `d`: Delete workspace
- `Q`: Close the WorkSpaceList view

In the WorkSpaceTree view
- `<CR>`: Open file or expand/collapse directory
- `Q`: Close the WorkSpaceTree view

## FAQ

Q: How do I refresh the workspace tree?
A: Currently, the tree refreshes automatically when you toggle it. To force a refresh, close and reopen the tree.

Q: Can I have multiple workspaces open at once?
A: The current version supports only one active workspace at a time.

Q: How do I add files to the workspace?
A: Files in the directory where you created the workspace are automatically included. To add new files, create them through your file system or use the 'c' key in the tree view.
