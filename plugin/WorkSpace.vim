" FILENAME: WorkspaceManager.vim
" Create Time: 2024-Aug-18-02:13:36

let s:savedOptions = &cpo
set cpo&vim

let s:workspaceCache = {}
let s:workspaceEntryCache = {}
let s:pathUtils = {}
let s:treeUtils = {}
let s:workspaceUI = {}

let s:workspaceDirCacheName = '.WorkspaceManager'

let g:WorkSpaceManagerEnter = '<CR>'
let g:WorkSpaceManagerExit = 'Q'
let g:WorkSpaceManagerListDelete = 'd'
let g:WorkSpaceManagerTreeCreateFile = 'c'
let g:WorkSpaceCreateFileExpandNode = 1

command! -n=? -complete=dir CreateWorkspace call s:createWorkspace(<q-args>)
command! -n=0 ToggleWorkspaceTree call s:toggleWorkspaceTree()

autocmd BufEnter,VimEnter * call s:initWorkspace()

function! s:workspaceUI.new() dict
    let l:UI_cache_obj = copy(s:workspaceUI)

    let l:UI_cache_obj.isCreated = 1
    let l:UI_cache_obj.ListTreeHeaderUI = {
                \ 'head': 'WorkspaceTree',
                \ 'help1': "    Press `<CR>` to open file",
                \ 'help2': "    Press `d` to delete file",
                \ 'help3': "    Press `c` to create file",
                \ 'help4': "    Press `Q` to close the workspace tree",
                \ 'seg': '-----------------------------',
                \ }

    let l:UI_cache_obj.ListTreeBarUI = {
                \ 'filebar': '|',
                \ 'file': '- ',
                \ 'dir': '+ ',
                \ 'opend': '~ ',
                \ 'listedDir': ' ~ ',
                \ 'turn': '`'
                \ }
    return l:UI_cache_obj
endfunction

function! s:workspaceUI.setup() dict
    highlight WorkspaceTreeHead ctermbg=NONE ctermfg=NONE guifg=#928374 gui=bold
    highlight WorkspaceTreeHelp ctermbg=NONE ctermfg=NONE guifg=#fb4934 gui=NONE
endfunction

function! s:workspaceUI.getUIContent() dict
    return { 'BarUI': self.ListTreeBarUI, 'HeaderUI': self.ListTreeHeaderUI }
endfunction

function! s:workspaceUI.setHighlight() dict
    call matchadd('WorkspaceTreeHead', '^'. self.ListTreeHeaderUI.head .'$')
    call matchadd('WorkspaceTreeHelp', '^    Press')
endfunction

function! s:initWorkspace()
    call s:workspaceCache.createCacheFile()
    call s:workspaceUI.setup()
endfunction

function! s:workspaceCache.ensureCacheFileExists() dict
    if !has_key(self, 'cacheFileFullPath') || !filereadable(self.cacheFileFullPath.name)
        call self.createCacheFile()
    endif
    return has_key(self, 'cacheFileFullPath') && self.cacheFileFullPath.isCreated
endfunction

function! s:workspaceCache.createCacheFile() dict
    let l:pathUtils = s:pathUtils.new(fnamemodify(expand('$MYVIMRC'), ':h'))
    let l:fullPath = l:pathUtils.solvePath() . s:workspaceDirCacheName

    let self.cacheFileFullPath = { 'name': l:fullPath, 'isEmpty': 0, 'isCreated': 0 }

    if !l:pathUtils.checkPathInvalid(l:fullPath)
        let self.cacheFileFullPath.isCreated = 1
        return
    endif

    call s:errorMsg('ReadFile <'.l:fullPath.'> Failed')

    if !self.promptUserForRecreation()
        return
    endif

    if self.attemptToCreateCacheFile(l:fullPath, l:pathUtils)
        return
    endif

    call s:errorMsg('Create File <'.l:fullPath.'> Failed')
endfunction

function! s:workspaceCache.promptUserForRecreation() dict
    return confirm('Do you want to create cacheFile?', "&Yes\n&No") == 1
endfunction

function! s:workspaceCache.attemptToCreateCacheFile(fullPath, pathUtils)
    call a:pathUtils.writeFileContent(a:fullPath, [])
    if !a:pathUtils.checkPathInvalid(a:fullPath)
        let self.cacheFileFullPath.isCreated = 1
        call s:infoMsg('Cache file created successfully!')
        return 1
    endif
    return 0
endfunction

function! s:workspaceCache.promptUserForRecreation() dict
    return confirm('Do you want to create cacheFile?', "&Yes\n&No") == 1
endfunction

function! s:workspaceCache.attemptToCreateCacheFile(fullPath, pathUtils)
    call a:pathUtils.writeFileContent(a:fullPath, [])
    if !a:pathUtils.checkPathInvalid(a:fullPath)
        let s:workspaceCache.cacheFileFullPath.isCreated = 1
        call s:infoMsg('Created!')
        return 1
    endif

    call s:errorMsg('Create File <'.a:fullPath.'> Failed')
    return 0
endfunction

function! s:toggleWorkspaceTree()
    if !filereadable(s:workspaceCache.cacheFileFullPath.name) || empty(readfile(s:workspaceCache.cacheFileFullPath.name))
        let s:workspaceCache.cacheFileFullPath.isEmpty = 1
    endif

    if s:workspaceCache.cacheFileFullPath.isEmpty
        call s:infoMsg("Workspace Cache File is empty!\nPlease Enter `:CreateWorkspace <dir>` to create it.")
        return
    endif

    let l:workspace = copy(s:workspaceCache)

    if s:isWorkspaceBufferExists()
        call l:workspace.exitBuffer()
    endif
    call l:workspace.drawTree()
endfunction

function! s:workspaceCache.checkUniquePath(index) abort dict
    let l:cacheFileContent = readfile(self.cacheFileFullPath.name)

    if index(l:cacheFileContent, a:index) >= 0
        return 1
    endif

    return 0
endfunction

function! s:workspaceCache.writeFileDirIntoContent(dir) dict
    let l:pathUtils = copy(s:pathUtils)

    if self.checkUniquePath(a:dir)
        return
    endif

    call l:pathUtils.writeFileContent(self.cacheFileFullPath.name, [a:dir], 'a')
endfunction

function! s:workspaceCache.getListTreeBufnr() dict
    if has_key(self, 'listTreeBufnr')
        return self.listTreeBufnr
    endif

    return -1
endfunction

function! s:workspaceCache.drawTree() dict
    let l:newBuf = nvim_create_buf(0, 1)

    if l:newBuf < 1
        call s:errorMsg('Failed to create buffer.')
        return
    endif

    let l:fileContent = readfile(self.cacheFileFullPath.name)

    let l:ui = s:workspaceUI.new()
    let l:HeaderUI = l:ui.getUIContent().HeaderUI

    let l:bufUI = [
                \ l:HeaderUI.head,
                \ '',
                \ l:HeaderUI.help1,
                \ l:HeaderUI.help2,
                \ l:HeaderUI.help3,
                \ l:HeaderUI.help4,
                \ l:HeaderUI.seg
                \ ]

    let s:blockArea = [ 1, len(l:bufUI) ]
    let s:workspaceCache.listTreeBufnr = l:newBuf

    let s:workspaceCache.bufUI = l:bufUI
    let s:workspaceCache.isExists = 1

    call self.setlineForBuffer(l:bufUI, l:newBuf)
    call appendbufline(l:newBuf, len(l:bufUI), l:fileContent)

    call self.splitWindow(l:newBuf)
    call self.bufferOption()
    call l:ui.setHighlight()
    call nvim_buf_set_keymap(l:newBuf, 'n', g:WorkSpaceManagerExit, ':call <SID>exitBuffer()<CR>', { 'nowait': 1, 'silent': v:true })
    call nvim_buf_set_keymap(l:newBuf, 'n', g:WorkSpaceManagerEnter, ':call <SID>enterWorkspace()<CR>', { 'nowait': 1, 'silent': v:true })
    call nvim_buf_set_keymap(l:newBuf, 'n', g:WorkSpaceManagerListDelete, ':call <SID>deleteWorkspace()<CR>', { 'nowait': 1, 'silent': v:true })
endfunction

function! s:workspaceCache.splitWindow(bufnr)
    lefta vnew
    vertical resize -10
    exec 'buffer' a:bufnr
endfunction

function! s:workspaceCache.exitBuffer() dict
    let l:bufnr = self.getListTreeBufnr()

    if l:bufnr < 0
        call s:errorMsg('Failed to exit buffer.')
        return
    endif

    exec 'bwipeout' l:bufnr
    let s:workspaceCache.isExists = 0
endfunction

function! s:workspaceCache.checkBlockArea(line) dict
    let [l:blockAreaStart, l:blockAreaEnd] = s:blockArea
    if a:line >= l:blockAreaStart && a:line <= l:blockAreaEnd
        return 1
    endif

    return 0
endfunction

function! s:workspaceCache.deleteWorkspace() dict
    let l:line = line('.')
    let l:pathUtils = copy(s:pathUtils)

    if self.checkBlockArea(l:line)
        return
    endif
    let l:lineContent = getline(l:line)
    let l:workspaceIndex = index(self.fileContent, l:lineContent)

    call remove(self.fileContent, l:workspaceIndex)

    call l:pathUtils.writeFileContent(self.cacheFileFullPath.name, self.fileContent)

    if len(self.fileContent) < 1
        call self.exitBuffer()
        return
    endif

    call self.exitBuffer()
    call self.drawTree()
endfunction

function! s:isWorkspaceBufferExists()
    if has_key(s:workspaceCache, 'isExists') && s:workspaceCache.isExists
        return 1
    endif

    return 0
endfunction

function! s:workspaceCache.enterWorkspace(line, ui) dict
    if self.checkBlockArea(a:line)
        return
    endif
    let self.line = a:line

    let l:lineContent = getline(self.line)
    let self.selectedPath = l:lineContent

    let l:files = s:getChild(l:lineContent)
    let l:path = s:pathUtils.new(l:files)

    let s:workspaceEntryCache.files = l:path.sorted()
    call s:treeUtils.new(self.selectedPath)
    call s:workspaceEntryCache.enterSpace(a:ui)
endfunction

function! s:workspaceEntryCache.createNewTree(files, endline, bufnr, ui) dict
    let l:index = 0
    for l:file in a:files
        let l:last_child_node = (len(a:files) - l:index) <= 1

        let l:ui_bar = l:file.isDirectory ? a:ui.dir : a:ui.file
        let l:tree_part_prefix = (l:last_child_node ? a:ui.turn : a:ui.filebar) . l:ui_bar
        let l:lineContent = l:tree_part_prefix . l:file.components.displayString
        call setbufline(a:bufnr, a:endline + l:index, l:lineContent)
        let l:index += 1
    endfor
endfunction

function! s:workspaceEntryCache.enterSpace(ui) dict
    let l:enteredTreeBufnr = nvim_create_buf(0, 1)
    let l:workspaceCache = copy(s:workspaceCache)

    let l:tree = s:treeUtils.getItem()

    let self.bufnr = l:enteredTreeBufnr
    let l:uiContent = a:ui.getUIContent()

    if s:isWorkspaceBufferExists()
        call l:workspaceCache.exitBuffer()
    endif

    call l:workspaceCache.setlineForBuffer(l:workspaceCache.bufUI, l:enteredTreeBufnr)
    call l:workspaceCache.splitWindow(l:enteredTreeBufnr)
    call cursor(l:workspaceCache.line, 0)

    call a:ui.setHighlight()
    call l:workspaceCache.bufferOption()

    let [_, l:blockAreaEnd] = s:blockArea

    " get child line
    let self.blockend = l:blockAreaEnd

    call l:tree.structured_child()
    let self.tree = l:tree

    call self.createNewTree(l:tree.children, l:blockAreaEnd + 1, l:enteredTreeBufnr, l:uiContent.BarUI)
    call self.setupKeymaps(l:enteredTreeBufnr)
endfunction

function! s:workspaceEntryCache.setupKeymaps(bufnr)
    call nvim_buf_set_keymap(a:bufnr, 'n', g:WorkSpaceManagerEnter, ':call <SID>toggleNode()<CR>', { 'nowait': 1, 'silent': v:true })
    call nvim_buf_set_keymap(a:bufnr, 'n', g:WorkSpaceManagerTreeCreateFile, ':call <SID>create_file()<CR>', { 'nowait': 1, 'silent': v:true })
    call nvim_buf_set_keymap(a:bufnr, 'n', 'd', ':call <SID>delete_file()<CR>', { 'nowait': 1, 'silent': v:true })
endfunction

function! s:workspaceEntryCache.setupNewBuffer(bufnr, ui) dict
    let l:workspaceCache = copy(s:workspaceCache)
    call l:workspaceCache.setlineForBuffer(l:workspaceCache.bufUI, a:bufnr)
    call l:workspaceCache.splitWindow(a:bufnr)
    call cursor(l:workspaceCache.line, 0)
    call a:ui.setHighlight()
    call l:workspaceCache.bufferOption()
endfunction

function! s:create_file()
    call s:workspaceEntryCache.createFile()
endfunction
function! s:delete_file()
    call s:workspaceEntryCache.deleteFile()
endfunction

function! s:workspaceEntryCache.deleteFile()
    let l:selectedNode = self.getLineNode()
    let l:path = s:pathUtils.new(l:selectedNode)

    let l:node = self.findNodeByPath(l:path.solvePath())
    if has_key(l:node, 'islastNode')
        call remove(l:node, 'islastNode')
    endif

    let l:expandPath = self.getParentNode(fnamemodify(l:path.path, ':h'))

    let l:confirm = input('Do you wanto remove ['. l:node.path .'] file? [y/N]')
    if l:confirm !~# '^[YyNn]$'
        call s:infoMsg('File delete cancelled.')
        return
    endif

    if l:confirm !~# '^[Yy]$'
        call s:infoMsg('File delete cancelled.')
        return
    endif

    call delete(l:node.path, 'rf')
    if filereadable(l:node.path) || isdirectory(l:node.path)
        call s:errorMsg('File delete failed!')
        return
    endif

    let l:index = s:workspaceEntryCache.findLineByNode(l:node) - self.blockend - 2
    call remove(self.files, index(self.files, self.files[l:index]))

    call self.collapseNode(l:expandPath)
    " call self.expandNode(l:expandPath)
endfunction

function! s:workspaceEntryCache.createFile() dict
    let l:selectedNode = self.getLineNode()

    let l:path = s:pathUtils.new(l:selectedNode)
    let l:node = self.findNodeByPath(l:path.solvePath())

    if l:node.isDirectory
        let l:expandPath = l:node
        let l:createDir = l:node.path
    else
        let l:expandPath = self.getParentNode(fnamemodify(l:path.path, ':h'))
        let l:createDir = fnamemodify(l:path.path, ':h')
    endif

    let l:fileName = input('Enter file/directory name: ')
    if empty(l:fileName)
        call s:infoMsg('File creation cancelled.')
        return
    endif

    let l:fileType = input('Enter type (f for file, d for directory): ')
    if l:fileType !~# '^[fd]$'
        call s:errorMsg('Invalid type. Please enter f for file or d for directory.')
        return
    endif

    let l:fullCreatePath = l:createDir . l:fileName
    let l:newPath = s:pathUtils.new(l:fullCreatePath)
    let l:newPath.isDirectory = (l:fileType ==# 'd')

    if ((l:fileType ==# 'f') && filereadable(l:fullCreatePath)) || ((l:fileType ==# 'd') && isdirectory(l:fullCreatePath))
        call s:errorMsg('Failed to create ' . (l:newPath.isDirectory ? 'directory' : 'file') . ': ' . l:fullCreatePath. ', File is exists.')
        return
    endif
    if l:newPath.isDirectory
        call mkdir(l:fullCreatePath, 'p')
    else
        call writefile([], l:fullCreatePath)
    endif

    if ((l:fileType ==# 'f') && !filereadable(l:fullCreatePath)) || ((l:fileType ==# 'd') && !isdirectory(l:fullCreatePath))
        call s:errorMsg('Failed to create ' . (l:newPath.isDirectory ? 'directory' : 'file') . ': ' . l:fullCreatePath)
        return
    endif

    let l:newNode = l:newPath.newFile()

    let l:blockend = self.blockend

    call add(l:expandPath.children, l:newNode)
    let l:index = s:workspaceEntryCache.findLineByNode(l:newNode)
    call insert(self.files, l:newNode.path, l:index - l:blockend + 1)

    call self.collapseNode(l:expandPath)
    call self.expandNode(l:expandPath)

    call s:infoMsg((l:newPath.isDirectory ? 'Directory' : 'File') . ' created: ' . l:fullCreatePath)
endfunction


function! s:workspaceEntryCache.findNodeByPath(path) dict
    return self._findNodeByPathRecursive(self.tree.children, a:path)
endfunction

function! s:workspaceEntryCache.findLineByNode(node) dict
    if type(a:node) != v:t_dict
        return -1  " Invalid node
    endif
    
    let l:blockend = self.blockend

    let l:result = self._findLineByNodeRecursive(self.tree, a:node, l:blockend + 1)
    return l:result
endfunction

function! s:workspaceEntryCache._findLineByNodeRecursive(currentNode, targetNode, currentLine) dict
    if a:currentNode.path ==# a:targetNode.path
        return a:currentLine
    endif

    let l:line = a:currentLine + 1
    for l:child in a:currentNode.children
        if l:child.path ==# a:targetNode.path
            return l:line
        endif

        if l:child.isDirectory && l:child.isOpen
            let l:result = self._findLineByNodeRecursive(l:child, a:targetNode, l:line)
            if l:result != -1
                return l:result
            endif

            let l:line += self._countVisibleNodes(l:child)
        endif

        let l:line += 1
    endfor

    return -1  " Node not found in this branch
endfunction

function! s:workspaceEntryCache._countVisibleNodes(node) dict
    let l:count = 0
    if a:node.isDirectory && a:node.isOpen
        for l:child in a:node.children
            let l:count += 1

            if l:child.isDirectory && l:child.isOpen
                let l:count += self._countVisibleNodes(l:child)
            endif
        endfor
    endif
    return l:count
endfunction

function! s:workspaceEntryCache.isVildNode(node)
    return !empty(a:node)
endfunction

function! s:workspaceEntryCache._findNodeByPathRecursive(nodes, path) dict
    for l:node in a:nodes
        if l:node.path == a:path
            return l:node
        endif

        if has_key(l:node, 'children') && !empty(l:node.children)
            let self.indent += 1

            let l:result = self._findNodeByPathRecursive(l:node.children, a:path)
            if !empty(l:result)
                return l:result
            endif
        endif
    endfor

    return {}
endfunction

function! s:workspaceEntryCache.getLineNode() dict
    let l:line = line('.')
    let [_, l:blockAreaEnd] = s:blockArea

    if s:workspaceCache.checkBlockArea(l:line)
        return -1
    endif

    let l:actuallyLine = l:line - l:blockAreaEnd
    return self.files[l:actuallyLine - 1]
endfunction

function! s:workspaceEntryCache.getParentNode(node)
    let l:path = s:pathUtils.new(a:node)
    let l:node = self.findNodeByPath(l:path.solvePath())

    return l:node
endfunction

function! s:workspaceEntryCache.toggleNode() dict
    let l:selectedNode = self.getLineNode()

    if l:selectedNode < 0
        return
    endif

    if filereadable(l:selectedNode)
        call self.handleFile(l:selectedNode)
    endif

    if isdirectory(l:selectedNode)
        call s:treeUtils.new(copy(l:selectedNode))
        let l:tree = s:treeUtils.getItem()
        call l:tree.structured_child()

        let self.selectedPathNodeTree = l:tree

        let l:path = s:pathUtils.new(l:selectedNode)
        call l:path.getParent()
        let l:node = self.findNodeByPath(l:path.solvePath())

        if !self.isVildNode(l:node)
            call s:errorMsg('Invild node.')
            return
        endif

        let l:indent_width = 2

        let self.indentWidth = repeat(' ', l:indent_width)
        let self.indent = len(l:path.parent) * l:indent_width

        if !empty(l:node) && l:node.isOpen
            call self.collapseNode(l:node)
        else
            call self.expandNode(l:node)
        endif
    endif
endfunction

function! s:workspaceEntryCache.handleFile(file) dict
    try
        wincmd l
        exec 'edit' a:file
    catch
        call s:errorMsg("Failed to open file: " . a:file . ", Error: " . v:exception)
    endtry
endfunction

function! s:VisibledChildrenCount(node, list)
    let l:count = 0
    
    for l:child in a:node.children
        call add(a:list, l:child.path)
        let l:count += 1

        if l:child.isDirectory && l:child.isOpen
            let l:count += s:VisibledChildrenCount(l:child, a:list)
        endif
    endfor

    return l:count
endfunction

function! s:workspaceEntryCache.collapseNode(node) dict
    if !self.isValidNode(a:node)
        call s:errorMsg("Invalid node provided for collapsing")
        return
    endif

    if empty(a:node.children) && !a:node.isOpen
        return
    endif

    let l:visibleChildren = []
    let l:childrenCount = s:VisibledChildrenCount(a:node, l:visibleChildren)
    let l:nodeLineNumber = self.findLineByNode(a:node) - 1
    let l:endLine = l:nodeLineNumber + l:childrenCount

    let a:node.isOpen = 0
    let a:node.children = []

    for l:child in l:visibleChildren
        call remove(self.files, index(self.files, l:child))
    endfor

    call self.updateBufferContent(self.bufnr, l:nodeLineNumber + 1, l:endLine)
endfunction

function! s:workspaceEntryCache.updateBufferContent(bufnr, startLine, endLine) abort
    call deletebufline(a:bufnr, a:startLine, a:endLine)

    let l:newline  = substitute(getline('.'), '\~', '+', 'g')
    call setbufline(a:bufnr, a:startLine - 1, l:newline)
endfunction

function! s:workspaceEntryCache.isValidNode(node) abort
    return type(a:node) == v:t_dict && has_key(a:node, 'path')
endfunction

function! s:workspaceEntryCache.expandNode(node) dict

    if !self.isValidNode(a:node)
        call s:errorMsg("Invalid node provided for expansion")
        return
    endif

    let l:ui = s:workspaceUI.new()

    let a:node.isOpen = 1
    let a:node.children = self.selectedPathNodeTree.children

    let l:lineNum = self.findLineByNode(a:node) - 1
    let l:lineNumContent = getline(l:lineNum)

    let l:updatedLine = s:updateLineAppearance(l:lineNumContent, a:node)

    call setbufline(self.bufnr, l:lineNum, l:updatedLine)

    let l:newLines = []
    let l:endLine = l:lineNum

    call self.prepareNewTreeLines(l:newLines, a:node.children, l:ui.getUIContent().BarUI)
    if !empty(l:newLines)
        call append(l:endLine, l:newLines)
        call self.updateFilesWithNewNodes(a:node, l:lineNum)
    endif

    call cursor(l:lineNum, 0)
endfunction

function! s:updateLineAppearance(line, node) abort
    let l:updatedLine = substitute(a:line, '+', '~', 'g')
    return get(a:node, 'islastNode', 0) ? substitute(l:updatedLine, '`', '|', 'g') : l:updatedLine
endfunction

function! s:workspaceEntryCache.prepareNewTreeLines(lines, children, uiBarUI) dict
    let l:indentWidth = self.indentWidth
    call s:prepareTreeLinesRecursive(a:lines, a:children, a:uiBarUI, self.indent, '', l:indentWidth)
endfunction

" Recursively prepares the visual representation of a tree structure.
"
" This function generates the lines that represent a tree structure in the
" workspace manager UI. It handles the creation of the tree's visual hierarchy,
" including proper indentation and branch symbols.
"
" Parameters:
" a:lines      - List to which the generated lines will be added
" a:children   - List of child nodes to process
" a:uiBarUI    - Dictionary containing UI elements for tree visualization
" a:indent     - Current indentation level
" a:prefix     - Prefix string for the current line (carries over parent prefixes)
" a:indentWidth - Width of each indentation level
"
" Behavior:
" - Iterates through each child node, creating a line representation for it
" - Handles both files and directories, using appropriate symbols
" - For directories, recursively processes their children if the directory is open
" - Adjusts indentation and prefixes based on the node's depth and position in the tree
"
" Note: This function modifies the 'a:lines' list in-place, adding new lines
" as it processes the tree structure.
function! s:prepareTreeLinesRecursive(lines, children, uiBarUI, indent, prefix, indentWidth) abort
    let l:childCount = len(a:children)
    let l:levelBar = repeat(a:uiBarUI.filebar . a:indentWidth, a:indent / 2)
    
    for l:index in range(l:childCount)
        let l:child = a:children[l:index]
        let l:isLastChild = l:index == l:childCount - 1

        let l:childPrefix = s:getChildPrefix(a:uiBarUI, l:isLastChild, l:child.isDirectory)
        
        let l:line = a:prefix . l:levelBar . l:childPrefix . l:child.components.displayString
        call add(a:lines, l:line)
        
        if l:child.isDirectory && get(l:child, 'isOpen', 0)
            let l:newPrefix = a:prefix . (l:isLastChild ? repeat(' ', len(a:uiBarUI.filebar . a:indentWidth)) : a:uiBarUI.filebar . a:indentWidth)
            call s:prepareTreeLinesRecursive(a:lines, get(l:child, 'children', []), a:uiBarUI, a:indent + 2, l:newPrefix, a:indentWidth)
        endif
    endfor
endfunction

function! s:getChildPrefix(uiBarUI, isLastChild, isDirectory) abort
    let l:turnBar = a:isLastChild ? a:uiBarUI.turn : a:uiBarUI.filebar
    let l:typeBar = a:isDirectory ? a:uiBarUI.dir : a:uiBarUI.file
    return l:turnBar . l:typeBar
endfunction

function! s:workspaceEntryCache.updateFilesWithNewNodes(node, lineNum) dict
    let l:index = a:lineNum - s:blockArea[1]

    for l:child in a:node.children
        call insert(self.files, l:child.path, l:index)
        let l:index += 1
    endfor
endfunction

function! s:toggleNode()
    call s:workspaceEntryCache.toggleNode()
endfunction

function! s:enterWorkspace()
    let l:line = line('.')
    let l:spaceUi = s:workspaceUI.new()

    call s:workspaceCache.enterWorkspace(l:line, l:spaceUi)
endfunction
function! s:deleteWorkspace()
    call s:workspaceCache.deleteWorkspace()
endfunction
function! s:exitBuffer()
    call s:workspaceCache.exitBuffer()
endfunction

function! s:workspaceCache.bufferOption() dict
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nowrap
    setlocal foldcolumn=0
    setlocal nobuflisted
    setlocal nospell
    setlocal nonu
endfunction

function! s:workspaceCache.setlineForBuffer(list, bufnr)
    for l:i in range(0, len(a:list) - 1)
        call setbufline(a:bufnr, l:i + 1, a:list[l:i])
    endfor
endfunction

function! s:treeUtils.new(workspace_root) dict
    let l:obj = self
    let l:obj.path = a:workspace_root
    let l:obj.children = []
    return l:obj
endfunction

function! s:treeUtils.structured_child() dict
    let l:path_util = s:pathUtils.new(self.path)
    let self.children = map(s:getChild(self.path), {_, file -> s:pathUtils.new(file).newFile()})
    call self.sorted()
endfunction

function! s:treeUtils.sorted() dict
    call sort(self.children, {a, b -> b.isDirectory - a.isDirectory})
endfunction

function! s:treeUtils.getItem() dict
    return deepcopy(self)
endfunction

function! s:pathUtils.new(path)
    let l:path = deepcopy(self)
    let l:path.path = a:path
    let l:path.isDirectory = 0

    if type(a:path) is# v:t_string
        let l:path.segments = split(a:path, '/')
    endif

    return l:path
endfunction

function! s:pathUtils.getParent()
    let l:parent_paths = []

    let l:current_path = s:workspaceCache.selectedPath  . '/'
    let l:segments = copy(self.segments)


    let l:base_segments = split(s:workspaceCache.selectedPath, '/')

    for l:seg in l:base_segments
        call remove(l:segments, index(l:segments, l:seg))
    endfor

    for l:i in l:segments
        let l:current_path .= l:i .'/'
        call add(l:parent_paths, l:current_path)
    endfor

    let self.parent = l:parent_paths
endfunction

function! s:pathUtils.sorted() dict
    let l:dirs = filter(copy(self.path), 'isdirectory(v:val)')
    let l:files = filter(copy(self.path), '!isdirectory(v:val)')
    return l:dirs + l:files
endfunction

function! s:getChild(path)
    let l:child = []
    let l:path = s:pathUtils.new(a:path)
    let l:child_path = readdir(a:path)

    for l:file in l:child_path
        let l:full_path = l:path.solvePath() . l:file
        call add(l:child, l:full_path)
    endfor

    return l:child
endfunction

function! s:pathUtils.writeFileContent(dir, content, flag = '') dict
    call writefile(a:content, a:dir, a:flag)
endfunction

function! s:pathUtils.removeBrokenFileOrDir(path = '') dict
    let l:path = has_key(self, 'path') ? self.path : a:path
    call delete(l:path, 'rf')
endfunction

function! s:pathUtils.checkPathInvalid(path)
    return !filereadable(a:path) && !filewritable(a:path)
endfunction

function! s:pathUtils.getLastSegment()
    return self.segments[-1]
endfunction

function! s:pathUtils.seg()
    return has('win32') || has('win64') ? '\' : '/'
endfunction

function! s:pathUtils.solvePath(path = '') dict
    let l:path = has_key(self, 'path') ? self.path : a:path
    return l:path !~# self.seg(). '$' && isdirectory(self.path) ? l:path. self.seg() : l:path
endfunction

function! s:pathUtils.checkPathInvild(path) dict
    return filereadable(a:path) && filewritable(a:path)
endfunction

function! s:pathUtils.newFile() dict
    let l:include = { 'components': {} }
    let l:include.path = self.path

    let l:include.isDirectory = 0
    let l:include.components.segments = self.segments

    if isdirectory(self.path) || self.isDirectory
        let l:include.path = self.solvePath(self.path)
        let l:include.isDirectory = 1
        let l:include.isOpen = 0
        let l:include.children = []
        let l:include.components.displayString = self.getLastSegment(). self.seg()
    else
        let l:include.components.displayString = self.getLastSegment()
    endif

    return l:include
endfunction

function! s:createWorkspace(dir = '')
    let l:dir = a:dir ==# '' ? expand('%:p:h') : fnamemodify(a:dir, ':p')

    if !isdirectory(l:dir)
        call s:errorMsg(l:dir. ' is not a directory.')
        return
    endif

    call s:workspaceCache.writeFileDirIntoContent(resolve(l:dir))
endfunction

function! s:errorMsg(msg)
    echohl ErrorMsg | echo a:msg | echohl None
endfunction

function! s:infoMsg(msg)
    echo a:msg
endfunction

let &cpo = s:savedOptions
unlet s:savedOptions

