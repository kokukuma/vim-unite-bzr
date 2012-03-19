
let s:save_cpo = &cpo
set cpo&vim

function! unite#filters#bzr_file_converter#define()"{{{
  return s:converter
endfunction"}}}

let s:converter = {
      \ 'name' : 'bzr_file_converter',
      \ 'description' : 'relative path word converter',
      \}

function! s:converter.filter(candidates, context)
    let s:bzr_delta_file = {}
    let s:bzr_delta_file_mkcmd = {}
    let s:bzr_delta_candidate = {}
    let delta_flg = 0
    let revs = []

    " bzr_delta以外はそのままreturn
    if len(a:candidates)==0 || a:candidates[0].source != 'bzr_delta'
        return  a:candidates
    endif
    if a:candidates[0].source != 'bzr_delta'
        return  a:candidates
    endif


    " fileの集計
    for candidate in a:candidates

      " revision番号の集計
      if index(revs, candidate.bzr_revision_number) < 0
          call add(revs, candidate.bzr_revision_number)
      endif

      " file毎にrevision番号を集計
      if has_key(s:bzr_delta_file, candidate.bzr_file_path)
          let rev   = s:bzr_delta_file[candidate.bzr_file_path]
          call add(rev, candidate.bzr_revision_number)
          call sort(rev)

          let s:bzr_delta_file[candidate.bzr_file_path] = rev
          let s:bzr_delta_file_mkcmd[candidate.bzr_file_path] = rev

          " delta_flg
          let delta_flg = 1

      else
          let rev = []
          call add(rev, candidate.bzr_revision_number)
          call sort(rev)
          let s:bzr_delta_file[candidate.bzr_file_path] = rev

          " candidateを保存しておく
          let s:bzr_delta_candidate[candidate.bzr_file_path] = candidate
      endif
    endfor


    let return_candidates = []

    " candidate修正
    for deltafile  in keys(s:bzr_delta_file_mkcmd)
        " コマンドの作成
        let s:seq = s:bzr_delta_file_mkcmd[deltafile]
        let max = len(s:seq) - 1

        let cmd = "call unite#sources#bzr#vimdiff('".s:seq[max]."','".s:seq[0]."','".deltafile."')"

        " candidateのコマンドの修正
        let cand = remove(s:bzr_delta_candidate,deltafile)
        let cand.action__command = cmd
        call add(return_candidates, cand)

    endfor

    " 残りのcandidateを追加
    for cand in values(s:bzr_delta_candidate)
        call add(return_candidates, cand)
    endfor


    " revision番号の書き出し(初回のみ)
    if g:delta_filter_flg == 0
        let s:str_revs = ""
        for r in revs
            let s:str_revs .= r . ", "
        endfor
        call unite#print_message('[revision] '. s:str_revs)
    endif
    let g:delta_filter_flg = 1


  return  return_candidates

endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

