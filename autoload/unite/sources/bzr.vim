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
" bzr limit number
let g:bzr_limit_number = 300
function! bzr#SetBzrLimit(num)
    let g:bzr_limit_number = a:num
    unlet s:log_result_list
endfunction
command! -nargs=1 SetBzrLimit :call bzr#SetBzrLimit(<q-args>)

" bzr log
function! s:exe_bzr_log(file)

    " bzr root
    let l:abspath = s:exe_bzr_root()

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
                let line       = matchstr(line, "'.*'")
                let l:path     = substitute(line, "'", "", "g")
                let l:delta = [l:type,l:path,a:revno]
                call add(s:result, l:delta)
            elseif line=~"=== modified file"
                let l:type   =  "modified"
                let line       = matchstr(line, "'.*'")
                let l:path     = substitute(line, "'", "", "g")
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
function! unite#sources#bzr#vimdiff_old(revno, fil)

    setlocal buftype=nofile

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


    " revisionを渡し,ファイルの内容を復元
    let l:file_lines_a = s:exe_bzr_cat(l:after_rev, a:fil)

    if l:before_rev == 0
        let l:file_lines_b = ""
    else
        let l:file_lines_b = s:exe_bzr_cat(l:before_rev, a:fil)
    endif

    " 

    " 一時ファイルを作成
    setlocal buftype=nofile

    if l:after_rev == 0
        let s:tmpfile_a = a:fil
    else
        let s:tmpfile_a = tempname().".php"
        execute "redir! > " . s:tmpfile_a
        "execute "redir! > " . getbufvar(s:tmpfile_a, '&buftype')
            silent! echo l:file_lines_a
        redir END
    endif

    let s:tmpfile_b = tempname().".php"
    execute "redir! > " . s:tmpfile_b
    "execute "redir! > " . getbufvar(s:tmpfile_a, '&buftype')
        silent! echo l:file_lines_b
    redir END

    "" vimdiffを実行する
    "let s:bufnr = bufnr(s:tmpfile_b,1)
    let s:bufnr = bufnr(s:tmpfile_b,1)
    echo s:bufnr
    execute 'buffer' s:bufnr
    execute ':vertical diffsplit ' s:tmpfile_a

    "" no folding
    execute 'set nofoldenable'
    execute 'wincmd p'
    execute 'set nofoldenable'
    execute 'wincmd p'

endfunction


function! unite#sources#bzr#vimdiff(revno, brevno, fil)
    setlocal buftype=nofile


    " 変更後のリビジョン
    let l:after_rev  = a:revno
    let l:before_rev = 0


    " 渡させたファイルに関係するリビジョンを抽出
    if exists('g:bzr_log_res')
        let l:revnos = g:bzr_log_res
    else
        let l:revnos = s:exe_bzr_log(a:fil)
    endif


    " 変更前のリビジョンを取得
    if a:brevno == 0
        let l:before_rev = l:revnos[0][0]
    else
        let l:num = match(map(copy(l:revnos),'v:val[0]'), a:brevno) + 1
        let l:before_rev = l:revnos[l:num][0]
    endif


    " fileを準備する
    if l:after_rev == 0
        let s:tmpfile_a = a:fil

    else
        " revisionを渡し,ファイルの内容を復元
        let l:file_lines_a = s:exe_bzr_cat(l:after_rev, a:fil)

        " tmpfileを作成する
        let s:tmpfile_a = unite#sources#bzr#mk_temp_file(l:file_lines_a)
    endif


    " revisionを渡し,ファイルの内容を復元
    let l:file_lines_b = s:exe_bzr_cat(l:before_rev, a:fil)


    " tmpfileを作成する
    let s:tmpfile_b = unite#sources#bzr#mk_temp_file(l:file_lines_b)


    " vimdiffを実行
    call unite#sources#bzr#exevimdiff(s:tmpfile_b, s:tmpfile_a)


endfunction


function! unite#sources#bzr#mk_temp_file(file_lines)

    let s:tmpfile = tempname().".php"
    execute "redir! > " . s:tmpfile
    "execute "redir! > " . getbufvar(s:tmpfile_a, '&buftype')
        silent! echo a:file_lines
    redir END

    return s:tmpfile

endfunction



function! unite#sources#bzr#exevimdiff(before_file, after_file)
    " rev : リビジョン番号,0の場合は、現在のファイルを指す

    " vimdiffを実行する
    "let s:bufnr = bufnr(s:tmpfile_b,1)
    let s:bufnr = bufnr(a:before_file,1)
    echo s:bufnr
    execute 'buffer' s:bufnr
    execute ':vertical diffsplit ' a:after_file

    "" no folding
    execute 'set nofoldenable'
    execute 'wincmd p'
    execute 'set nofoldenable'
    execute 'wincmd p'

endfunction


"----------------------------------------------------------+
"  unite source                                            |
"----------------------------------------------------------+

" bzr log
function! s:unite_bzr_log.gather_candidates(args, context)

  "let s:bzr_log_res = s:exe_bzr_log()
  "
  if exists('a:args[0]')
    let s:bzr_log_res = s:exe_bzr_log(a:args[0])
    call unite#print_message('[file_log]'.a:args[0])

  elseif exists('g:unite_bzr_log_file')
    let s:bzr_log_res = s:exe_bzr_log(g:unite_bzr_log_file)
    call unite#print_message('[file_log]'.g:unite_bzr_log_file)
    unlet g:unite_bzr_log_file

  else
    let s:bzr_log_res = s:exe_bzr_log("")
    let g:bzr_log_res = s:bzr_log_res
  endif

  "let s:bzr_log_res = s:exe_bzr_log(a:args[0])
  "let s:bzr_log_res = s:exe_bzr_log("")

  return map(copy(s:bzr_log_res), '{
  \   "word": v:val[0].":".v:val[1],
  \   "source": "bzr_log",
  \   "kind": "source",
  \   "action__source_name": [ "bzr_delta", v:val[0] ],
  \   "revision_number": v:val[0],
  \ }')

endfunction

function! s:unite_bzr_delta.gather_candidates(args, context)

    " exe bzr diff
    let l:bzr_delta = s:exe_bzr_delta(a:args[0])

    " filter_flg
    let g:delta_filter_flg = 0


    return map(copy(l:bzr_delta), '{
    \   "word": v:val[0]." : ".v:val[1],
    \   "source": "bzr_delta",
    \   "kind": "command",
    \   "action__command": "call unite#sources#bzr#vimdiff(''".v:val[2]."'',''".v:val[2]."'',''".v:val[1]."'')",
    \   "action__path":v:val[1],
    \   "bzr_revision_number":v:val[2],
    \   "bzr_file_path":v:val[1],
    \ }')

endfunction

" bzr status
function! s:unite_bzr_status.gather_candidates(args, context)


    let s:bzr_status = s:exe_bzr_status()

    return map(copy(s:bzr_status), '{
    \   "word": v:val[0]." ".v:val[1],
    \   "source": "bzr_status",
    \   "kind": "command",
    \   "action__command": "call unite#sources#bzr#vimdiff(''0'',''0'',''".v:val[1]."'')",
    \   "action__path": v:val[2],
    \ }')

endfunction


"----------------------------------------------------------+
"  unite action                                            |
"----------------------------------------------------------+

"--- unite bzr-status adction
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

let s:unite_bzr_status.action_table.common = s:action_table_status



"--- unite bzr-delta adction
let s:action_table_delta = {}

" bzr vimdiff
let s:action_table_delta.bzr_local_diff = {
\   'description'   : 'diff with local',
\   'is_selectable' : 1,
\   'is_quit' : 0,
\   }
function! s:action_table_delta.bzr_local_diff.func(candidates)
    for l:candidate in a:candidates
        call unite#sources#bzr#vimdiff('0','0',l:candidate['action__path'])
    endfor
endfunction

" bzr log 
let s:action_table_delta.bzr_log = {
\   'description'   : 'bzr log',
\   'is_selectable' : 1,
\   'is_quit' : 0,
\   }
function! s:action_table_delta.bzr_log.func(candidates)

    "------------------------
    "let l:context = unite#get_context()
    " let a:candidates[0].action__source_name = 'bzr_log'
    " let a:candidates[0].action__source_args = [ a:candidates[0].action__path ]

    " let a:candidates[0].action__source_name = 'bzr_delta'
    " let a:candidates[0].action__source_args = [9]

    " call unite#start_temporary(map(copy(a:candidates),
    "     \ 'has_key(v:val, "action__source_args") ?'
    "     \  . 'insert(copy(v:val.action__source_args), v:val.action__source_name) :'
    "     \  . 'v:val.action__source_name'))

    "call s:unite_bzr_log.gather_candidates(a:candidates, l:context)


    "------------------------
    "let l:sources = unite#get_sources('bzr_log')
    let l:context = unite#get_context()
    let file_path = a:candidates[0]['action__path']
    "call unite#start([['bzr_log', file_path,]], l:context )
    "call unite#start(['bzr_log', file_path], l:context )

    "let l:context['source__sources'] = ''
    "let l:context['old_buffer_info'] = ''

    "let l:context.no_quit = 1 
    """"""""""call unite#start([['bzr_log', file_path]])
    "echo l:context
    "call unite#start(['bzr_log', file_path]], l:context)
    call unite#start(['bzr_log', file_path]], l:context)
    "call unite#start([['bzr_log', file_path]])
    "
    "call unite#start([['bzr_log',file_path]], l:context)

    "call unite#start([file_path],l:context)
    "call unite#start([['bzr_delta',file_path]],l:context)
    "call unite#start([[file_path]],l:context)
    "
    "echo l:context
    "echo l:sources
    "call unite#start([l:sources, file_path],l:context)
    "call unite#start(l:sources, l:context)
    "
    " call unite#start_temporary(l:sources)
    return

endfunction

let s:unite_bzr_delta.action_table.common = s:action_table_delta
let s:unite_bzr_status.action_table.common = s:action_table_delta

"----------------------------------------------------------+
" filter                                                   |
"----------------------------------------------------------+
call unite#set_profile('bzr', 'filters', ['bzr_file_converter',])


"----------------------------------------------------------+
"                                                          |
"----------------------------------------------------------+

" 登録
function! unite#sources#bzr#define()
    return [s:unite_bzr_log, s:unite_bzr_status, s:unite_bzr_delta]
endfunction


let &cpo = s:save_cpo
unlet s:save_cpo
