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

let s:unite_bzr_delta = {
\   'name': 'bzr_delta',
\   'action_table': {},
\   'default_action': {'common':'execute'},
\}

"----------------------------------------------------------+
"  exe bzr                                                 |
"----------------------------------------------------------+
"
let g:bzr_limit_number = 300

function! s:exe_bzr_log(file)
    " key
    if a:file == ""
        let l:key = "all"
    else
        let l:key = a:file
    endif

    " check cache
    if ! exists('s:log_result_list')
        let l:type = 0
        let s:log_result_list = {}
        let s:log_result =[]
    elseif ! has_key(s:log_result_list, l:key)
        let l:type = 0
        let s:log_result =[]
    else
        let l:type = 1
    endif

    " 
    if l:type == 0
        " bzr log 実行
        let l:bzrlog = vimproc#system("bzr log --line --limit ".g:bzr_limit_number." ".a:file)
        let l:lines   = split(l:bzrlog,'\n')

        " revnoを抽出
        for line in l:lines
            let l:revision   = split(line,':')
            call add(s:log_result, l:revision)
        endfor

        "
        let s:log_result_list[l:key] = s:log_result
    endif

    return s:log_result_list[l:key]

endfunction

function! s:exe_bzr_status()

    if ! exists('s:stat_result')
        let s:stat_result = []

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
                call add(s:stat_result, l:status)
            endif
        endfor
    endif

    return s:stat_result

endfunction

function! s:exe_bzr_delta(revno)

    " key
    let l:key = "revno".a:revno

    " chk exe
    let l:exeflg = 1
    if ! exists('s:delta_res')
        let s:delta_res = {}
        let l:exeflg = 1
    else
        for haskey in keys(s:delta_res)
            if haskey == l:key
                let l:exeflg = 0
            endif
        endfor
    endif


    " get result
    if l:exeflg == 1
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

        let s:delta_res[l:key] = s:result
    else
        let s:result = get(s:delta_res, l:key)
    endif

    return s:result

endfunction

function! s:exe_bzr_root()

    let l:bzrroot = vimproc#system("bzr root")
    return l:bzrroot

endfunction

function! s:exe_bzr_cat(revno, file)

    let l:bzrcat = vimproc#system("bzr cat -r ".a:revno." ".a:file)
    return l:bzrcat

endfunction



" 一時ファイルを作成
function! unite#sources#bzr#vimdiff(revno, fil)

    " 変更後のリビジョン
    let l:after_rev  = a:revno
    let l:before_rev = 0

    " 渡させたファイルに関係するリビジョンを抽出
    let l:revnos = s:exe_bzr_log(a:fil)

    "echo l:revnos

    " 変更前のリビジョンを取得
    if l:after_rev == 0
        let l:before_rev = l:revnos[0][0]
    else
        let l:num = match(map(copy(l:revnos),'v:val[0]'), a:revno) + 1
        let l:before_rev = l:revnos[l:num][0]
    endif
    "echo l:after_rev
    "echo l:before_rev
    "else
    "    let l:flg = 0
    "    for rev in l:revnos
    "        if l:flg == 1
    "           let l:before_rev = rev[0]
    "           let l:flg = 0
    "        elseif rev[0] == a:revno
    "            let l:flg = 1
    "        endif
    "    endfor
    "endif


    " revisionを渡し,ファイルの内容を復元
    let l:file_lines_a = s:exe_bzr_cat(l:after_rev, a:fil)

    if l:before_rev == 0
        let l:file_lines_b = ""
    else
        let l:file_lines_b = s:exe_bzr_cat(l:before_rev, a:fil)
    endif


    " 一時ファイルを作成
    if l:after_rev == 0
        let s:tmpfile_a = a:fil
    else
        let s:tmpfile_a = tempname().".php"
        execute "redir! > " . s:tmpfile_a
            silent! echo l:file_lines_a
        redir END
    endif

    let s:tmpfile_b = tempname().".php"
    execute "redir! > " . s:tmpfile_b
        silent! echo l:file_lines_b
    redir END

    "" vimdiffを実行する
    let s:bufnr = bufnr(s:tmpfile_b,1)
    echo s:bufnr
    execute 'buffer' s:bufnr
    execute ':vertical diffsplit ' s:tmpfile_a

endfunction




"----------------------------------------------------------+
"  unite source                                            |
"----------------------------------------------------------+

" bzr log
function! s:unite_bzr_log.gather_candidates(args, context)

  "exe bzr log
  let s:bzr_log_res = s:exe_bzr_log("")

  return map(copy(s:bzr_log_res), '{
  \   "word": v:val[0].":".v:val[1],
  \   "source": "revision",
  \   "kind": "source",
  \   "action__source_name": [ "bzr_delta", v:val[0] ],
  \   "revision_number": v:val[0],
  \ }')

endfunction

function! s:unite_bzr_delta.gather_candidates(args, context)

    " exe bzr diff
    let l:bzr_delta = s:exe_bzr_delta(a:args[0])

    "
    return map(copy(l:bzr_delta), '{
    \   "word": v:val[0]." : ".v:val[1],
    \   "source": "revision",
    \   "kind": "command",
    \   "action__command": "call unite#sources#bzr#vimdiff(''".v:val[2]."'',''".v:val[1]."'')",
    \   "revision_number": v:val[1],
    \ }')

endfunction

" bzr status
function! s:unite_bzr_status.gather_candidates(args, context)


    let s:bzr_status = s:exe_bzr_status()

    return map(copy(s:bzr_status), '{
    \   "word": v:val[0]." ".v:val[1],
    \   "source": "revision",
    \   "kind": "command",
    \   "action__command": "call unite#sources#bzr#vimdiff(''0'',''".v:val[1]."'')",
    \   "action__path": v:val[2],
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


"----------------------------------------------------------+
"                                                          |
"----------------------------------------------------------+

" 登録
function! unite#sources#bzr#define()
    return [s:unite_bzr_log, s:unite_bzr_status, s:unite_bzr_delta]
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
