"----------------------------------------------------------+
" execute bzr function                                     |
"----------------------------------------------------------+
let s:save_cpo = &cpo
set cpo&vim


"----------------------------------------------------------+
"  define unite source                                     |
"----------------------------------------------------------+

let s:unite_bzr_log = {
\   'name': 'bzr_log',
\   'action_table': {},
\   'default_action': {'common':'execute'},
\}

let s:unite_bzr_status = {
\   'name': 'bzr_status',
\   'action_table': {},
\   'default_action': {'common':'execute'},
\}

let s:unite_bzr_diff = {
\   'name': 'bzr_diff',
\   'action_table': {},
\   'default_action': {'common':'execute'},
\}

let s:unite_bzr_delta = {
\   'name': 'bzr_delta',
\   'action_table': {},
\   'default_action': {'common':'execute'},
\}

"----------------------------------------------------------+
"  exe bzr                                                 |
"----------------------------------------------------------+

function! s:exe_bzr_log()

    let s:result = []

    " bzr log 実行
    if ! exists("l:bzrlog")
        let l:bzrlog = vimproc#system("bzr log --line")
    endif
    let l:lines   = split(l:bzrlog,'\n')

    " revnoを抽出
    for line in l:lines
        let l:revision   = split(line,':')
        call add(s:result, l:revision)
    endfor

    return s:result

endfunction

function! s:exe_bzr_status()

    let l:result = []

    " bzr root
    let l:abspath = s:exe_bzr_root()
    let l:abspath = substitute(l:abspath, "\n", "", "g")

    " bzr log 実行
    if ! exists("l:bzrstatus")
        let l:bzrstatus = vimproc#system("bzr status")
    endif
    let l:lines   = split(l:bzrstatus,'\n')

    " revnoを抽出
    for line in l:lines
        " typeを特定
        if line=~"added"
            let l:type = "added    : "
        elseif line=~"modified"
            let l:type = "modified : "
        elseif line=~"unknown"
            let l:type = "unknown  : "
        else
            " 空白除去
            let l:file   = substitute(line, '\(^\s\+\)\|\(\s\+$\)', '', 'g')
            let l:absfilepath = l:abspath."/".l:file
            let l:status = [l:type,l:file,l:absfilepath]
            call add(l:result, l:status)
        endif
    endfor

    return l:result

endfunction

function! s:exe_bzr_diff(revno, filepath)

    let s:result = []

    " bzr root
    let l:path = s:exe_bzr_root()
    let l:path = substitute(l:path, "\n", "", "g")
    let l:path = l:path."/".substitute(a:filepath, '\(^\s\+\)\|\(\s\+$\)', '', 'g')

    " bzr diff の引数を決定
    if a:revno != "" && a:filepath != ""
        let l:diff_args = " -c ".a:revno ." ".a:filepath
    elseif a:revno == "" && a:filepath != ""
        let l:diff_args = " ".a:filepath
    elseif a:revno != "" && a:filepath == ""
        let l:diff_args = " -c ".a:revno
    endif

    let l:bzrdiff = vimproc#system("bzr diff ".l:diff_args)
    let l:lines   = split(l:bzrdiff,'\n')

    " revnoを抽出
    for line in l:lines
        let l:diff_line = [line, l:path, 1]
        call add(s:result, l:diff_line)
    endfor

    return s:result

endfunction

function! s:exe_bzr_delta(revno)

    let s:result = []

    let l:bzrdiff = vimproc#system("bzr diff -c ".a:revno)
    let l:lines   = split(l:bzrdiff,'\n')

    " file名を抽出
    for line in l:lines
        if line=~"=== added file"
            let l:type   =  "added"
            let line     = substitute(line, "'", "", "g")
            let l:path   = substitute(line, "=== added file", "", "g")
            let l:delta = [l:type,l:path,a:revno]
            call add(s:result, l:delta)
        elseif line=~"=== modified file"
            let l:type   =  "modified"
            let line     = substitute(line, "'", "", "g")
            let l:path   = substitute(line, "=== modified file", "", "g")
            let l:delta = [l:type,l:path,a:revno]
            call add(s:result, l:delta)
        endif
    endfor

    return s:result

endfunction

function! s:exe_bzr_root()

    let l:bzrroot = vimproc#system("bzr root")
    return l:bzrroot

endfunction

"----------------------------------------------------------+
"  unite source                                            |
"----------------------------------------------------------+

" bzr log
function! s:unite_bzr_log.gather_candidates(args, context)

  "exe bzr log
  let s:bzr_log_res = s:exe_bzr_log()

  return map(copy(s:bzr_log_res), '{
  \   "word": v:val[0].":".v:val[1],
  \   "source": "revision",
  \   "kind": "source",
  \   "action__source_name": [ "bzr_delta", v:val[0] ],
  \   "revision_number": v:val[0],
  \ }')

endfunction

" bzr status
function! s:unite_bzr_status.gather_candidates(args, context)


    let s:bzr_status = s:exe_bzr_status()

    return map(copy(s:bzr_status), '{
    \   "word": v:val[0]." ".v:val[1],
    \   "source": "revision",
    \   "kind": "source",
    \   "action__source_name": [ "bzr_diff", ["",v:val[1]]],
    \   "action__path": v:val[2],
    \ }')

endfunction

" bzr diff
function! s:unite_bzr_diff.gather_candidates(args, context)

    " exe bzr diff
    let l:bzr_diff = s:exe_bzr_diff(a:args[0][0],a:args[0][1])

    " 色を設定
    hi default ADDLINE guifg=DarkBlue guibg=DarkGray gui=none ctermfg=yellow ctermbg=DarkGray cterm=none
    hi default DELLINE guifg=DarkBlue guibg=DarkGray gui=none ctermfg=green ctermbg=DarkGray cterm=none
    call matchadd("ADDLINE","^-   +.*$")
    call matchadd("DELLINE","^-   -.*$")

    "
    return map(copy(l:bzr_diff), '{
    \   "word": v:val[0],
    \   "source": "revision",
    \   "kind": "jump_list",
    \   "action__path": v:val[1],
    \   "action__line": v:val[2],
    \ }')

endfunction

function! s:unite_bzr_delta.gather_candidates(args, context)

    " exe bzr diff
    let l:bzr_delta = s:exe_bzr_delta(a:args[0])

    "
    return map(copy(l:bzr_delta), '{
    \   "word": v:val[0]." : ".v:val[1],
    \   "source": "revision",
    \   "kind": "source",
    \   "action__source_name": [ "bzr_diff", [v:val[2],v:val[1]]],
    \   "revision_number": v:val[1],
    \ }')

endfunction

"----------------------------------------------------------+
"  unite action                                            |
"----------------------------------------------------------+

let s:action_table_status = {}

" bzr add
let s:action_table_status.bzr_add = {
\   'description'   : 'bzr add',
\   'is_selectable' : 1,
\   }

function! s:action_table_status.bzr_add.func(candidates)
    for l:candidate in a:candidates
        let l:bzrstatus = vimproc#system("bzr add ".l:candidate['action__path'])
    endfor
endfunction

" bzr remove
let s:action_table_status.bzr_remove = {
\   'description'   : 'bzr remove',
\   'is_selectable' : 1,
\   }

function! s:action_table_status.bzr_remove.func(candidates)
    for l:candidate in a:candidates
        let l:bzrstatus = vimproc#system("bzr remove ".l:candidate['action__path'])
    endfor
endfunction


" bzr revert
let s:action_table_status.bzr_revert = {
\   'description'   : 'bzr revert',
\   'is_selectable' : 1,
\   }

function! s:action_table_status.bzr_revert.func(candidates)
    for l:candidate in a:candidates
        let l:bzrstatus = vimproc#system("bzr revert ".l:candidate['action__path'])
    endfor
endfunction

"
let s:unite_bzr_status.action_table.common = s:action_table_status




" bzr revert
let s:action_table_status = {}

" bzr add
let s:action_table_status.bzr_add = {
\   'description'   : 'bzr add',
\   'is_selectable' : 1,
\   }

function! s:action_table_status.bzr_add.func(candidates)
    for l:candidate in a:candidates
        let l:bzrstatus = vimproc#system("bzr add ".l:candidate['action__path'])
    endfor
endfunction

"
let s:unite_bzr_status.action_table.common = s:action_table_status


"----------------------------------------------------------+
"                                                          |
"----------------------------------------------------------+

" 登録
function! unite#sources#bzr#define()
    return [s:unite_bzr_log, s:unite_bzr_status, s:unite_bzr_diff, s:unite_bzr_delta]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
