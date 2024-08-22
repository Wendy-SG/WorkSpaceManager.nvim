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
let s:isWindowsOS = has('win32') || has('win64')

let g:WorkSpaceManagerEnter = '<CR>'
let g:WorkSpaceManagerExit = 'Q'
let g:WorkSpaceManagerDelete = 'd'
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

    let s:workspaceCache.cacheFileFullPath = { 'name': l:fullPath, 'isEmpty': 0, 'isCreated': 0 }

    if l:pathUtils.checkPathInvalid(l:fullPath)
        call s:errorMsg('ReadFile <'.l:fullPath.'> Failed')

        let l:confirm = self.promptUserForRecreation()

        if l:confirm
            if self.attemptToCreateCacheFile(l:fullPath, l:pathUtils)
                return
            endif
        endif
    endif

    if self.ensureCacheFileExists()
        let s:workspaceCache.cacheFileFullPath.isCreated = 1
    endif
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
    let s:workspaceCache.fileContent = l:fileContent
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
    call nvim_buf_set_keymap(l:newBuf, 'n', g:WorkSpaceManagerDelete, ':call <SID>deleteWorkspace()<CR>', { 'nowait': 1, 'silent': v:true })
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

    call l:tree.structured_child()
    let self.tree = l:tree

    call self.createNewTree(l:tree.children, l:blockAreaEnd + 1, l:enteredTreeBufnr, l:uiContent.BarUI)
    call nvim_buf_set_keymap(l:enteredTreeBufnr, 'n', g:WorkSpaceManagerEnter, ':call <SID>toggleNode()<CR>', { 'nowait': 1, 'silent': v:true })
    call nvim_buf_set_keymap(l:enteredTreeBufnr, 'n', 'c', ':call <SID>create_file()<CR>', { 'nowait': 1, 'silent': v:true })
endfunction

function! s:create_file()
    call s:workspaceEntryCache.createFile()
endfunction

function! s:workspaceEntryCache.createFile() dict
    let l:selectedNode = self.getLineNode()

    let l:path = s:pathUtils.new(l:selectedNode)
    let l:node = self.findNodeByPath(l:path.solvePath())
    call l:path.getParent()
    let l:parentPath = l:path.parent[-2]

    let l:createDir = ''
    let l:expandPath = ''

    if !self.isVildNode(l:node)
        call s:error_msg('Invild node.')
        return
    endif

    if l:node.isDirectory
        let l:expandPath = l:node
        let l:createDir = l:node.path
    else
        let l:expandPath = self.getParentNode(l:parentPath)
        let l:createDir = l:parentPath
    endif

    " call self.redrawParentNode(l:expandPath)
    let l:fileName = fnameescape(input('Enter file name: '))
    let l:fileType = input('Enter FileType [d/f]')
    if l:fileType !~= '^[DdFf]$'
        call s:info_msg('Invild file type.')
        return
    endif

    let l:fullCreatePath = l:createDir. l:fileName
    let l:newPath = s:pathUtils.new(l:fullCreatePath)

    let l:include = l:newPath.newFile()
    echo l:include
endfunction

function! s:workspaceEntryCache.findNodeByPath(path) dict
    return self._findNodeByPathRecursive(self.tree.children, a:path)
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

function! s:workspaceEntryCache.redrawParentNode(node)
    call self.collapseNode(a:node)
    call self.expandNode(a:node)
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

        let self.nodeTree = l:tree

        let l:path = s:pathUtils.new(l:selectedNode)
        call l:path.getParent()
        let l:node = self.findNodeByPath(l:path.solvePath())

        if !self.isVildNode(l:node)
            call s:error_msg('Invild node.')
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
        call s:error_msg("Failed to open file: " . a:file . ", Error: " . v:exception)
    endtry
endfunction

function! s:VisibledChildrenCount(node, list)
    for l:child in a:node.children
        if l:child.isDirectory && l:child.isOpen && !empty(l:child.children)
            call s:VisibledChildrenCount(l:child, a:list)
        endif
        call add(a:list, l:child.path)
    endfor
endfunction

function! s:workspaceEntryCache.collapseNode(node) dict
    if empty(a:node.children) && !a:node.isOpen
        return
    endif
    let l:list = []
    call s:VisibledChildrenCount(a:node, l:list)
    let l:count = len(l:list)

    let a:node.isOpen = 0
    let l:lineNum = line('.')
    let l:endLine = l:lineNum + l:count

    for l:child in l:list
        call remove(self.files, index(self.files, l:child))
    endfor

    call deletebufline(self.bufnr, l:lineNum + 1, l:endLine)
    let a:node.children = []
    let l:lineContent = getline('.')
    let l:newline  = substitute(getline('.'), '\~', '+', 'g')

    call setbufline(self.bufnr, l:lineNum, l:newline)
endfunction

function! s:workspaceEntryCache.expandNode(node) dict
    let l:ui = s:workspaceUI.new()

    let a:node.isOpen = 1
    let a:node.children = self.nodeTree.children

    let l:newline  = substitute(getline('.'), '+', '~', 'g')
    if has_key(a:node, 'islastNode')
        let l:newline = substitute(l:newline, '`', '|', 'g')
    endif
    call setbufline(self.bufnr, line('.'), l:newline)

    let l:lineNum = line('.')
    let l:newLines = []
    let l:endLine = l:lineNum + 1

    call self.prepareNewTreeLines(l:newLines, a:node.children, l:ui.getUIContent().BarUI, [])
    call append(l:endLine - 1, l:newLines)
    call self.updateFilesWithNewNodes(a:node, l:lineNum)

    call cursor(l:lineNum, 0)
endfunction

function! s:workspaceEntryCache.prepareNewTreeLines(lines, children, uiBarUI, second_level) dict
    let l:index = 0
    let l:childCount = len(a:children)
    
    for l:child in a:children
        let l:last_child_node = (l:childCount - l:index) <= 1
        let l:indent_count = repeat(' ', self.indent)

        if l:last_child_node
            let l:child.islastNode = 1
        endif

        let l:dir_bar = (l:child.isDirectory ? a:uiBarUI.dir : a:uiBarUI.file)
        let l:turn_bar = (l:last_child_node ? a:uiBarUI.turn : a:uiBarUI.filebar)

        let l:level_file_bar = has_key(l:child, 'islastNode') ? a:uiBarUI.turn : a:uiBarUI.filebar
        let l:level_bar = repeat(a:uiBarUI.filebar . self.indentWidth, (self.indent - 2) / 2)

        let l:tree_part_prefix = a:uiBarUI.filebar. self.indentWidth . l:level_bar . l:turn_bar . l:dir_bar
        let l:child_line = l:tree_part_prefix . l:child.components.displayString
        call add(a:lines, l:child_line)

        if l:child.isDirectory && l:child.isOpen && empty(l:child.children)
            call self.prepareNewTreeLines(a:lines, l:child.children, a:uiBarUI)
        endif

        let l:index += 1
    endfor
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
    let l:obj.root_path = a:workspace_root
    let l:obj.children = []
    return l:obj
endfunction

function! s:treeUtils.structured_child() dict
    let l:path = s:pathUtils.new(self.root_path)

    for l:file in s:getChild(self.root_path)

        let l:path = s:pathUtils.new(l:file)
        let l:include = l:path.newFile()

        call add(self.children, l:include)
    endfor

    call self.sorted()
endfunction

function! s:treeUtils.sorted() dict
    let l:root_children = copy(self.children)
    let l:dir = []

    for l:file in l:root_children
        if !l:file.isDirectory
            continue
        endif

        call add(l:dir, l:file)
        call remove(l:root_children, index(l:root_children, l:file))
    endfor

    let self.children = l:dir + l:root_children
endfunction

function! s:treeUtils.getItem() dict
    return copy(self)
endfunction

function! s:pathUtils.new(path)
    let l:path = copy(self)
    let l:path.path = a:path
    let l:path.times = []
    let l:path.isDirectory = 0

    if type(a:path) is# v:t_string
        let l:path.segments = split(a:path, '/')
    endif

    return l:path
endfunction

function! s:pathUtils.joinPath(base, path)
    return fnamemodify(a:base . '/' . a:path, ':p')
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

function! s:pathUtils.sorted()
    let l:sort_path = copy(self.path)
    let l:dirs = []

    for l:path in l:sort_path
        if !isdirectory(l:path)
            continue
        endif

        call add(l:dirs, l:path)
        call remove(l:sort_path, index(l:sort_path, l:path))
    endfor

    return l:dirs + l:sort_path
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
    let l:path = a:path
    if has_key(self, 'path')
        let l:path = self.path
    endif

    call delete(l:path, 'rf')
endfunction

function! s:pathUtils.checkPathInvalid(path)
    return !filereadable(a:path) && !filewritable(a:path)
endfunction

function! s:pathUtils.getLastSegment()
    return self.segments[-1]
endfunction

function! s:pathUtils.seg()
    if s:isWindowsOS
        return '\'
    endif

    return '/'
endfunction

function! s:pathUtils.solvePath(path = '') dict
    let l:path = a:path
    if has_key(self, 'path')
        let l:path = self.path
    endif

    if l:path !~# self.seg(). '$' && isdirectory(self.path)
        return l:path. self.seg()
    endif
    " let self.solvedPath = l:path

    return l:path
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
