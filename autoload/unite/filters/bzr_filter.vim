
let s:save_cpo = &cpo
set cpo&vim

function! unite#filters#bzr_filter#define()"{{{
  return s:converter
endfunction"}}}

let s:converter = {
      \ 'name' : 'bzr_filter',
      \ 'description' : 'relative path word converter',
      \}

function! s:converter.filter(candidates, context)
    let s:bzr_delta_file = {}
    let s:bzr_delta_candidate = {}
    let delta_flg = 0

    " fileの集計
    for candidate in a:candidates
      if candidate.source == 'bzr_delta'
          let delta_flg = 1
          echo candidate
          if has_key(s:bzr_delta_file, candidate.bzr_file_path)
              let rev   = s:bzr_delta_file[candidate.bzr_file_path]
              call add(rev, candidate.bzr_revision_number)
              call sort(rev)
              let s:bzr_delta_file[candidate.bzr_file_path] = rev
          else
              let rev = []
              call add(rev, candidate.bzr_revision_number)
              call sort(rev)
              let s:bzr_delta_file[candidate.bzr_file_path] = rev
              let s:bzr_delta_candidate[candidate.bzr_file_path] = candidate
          endif
      endif
    endfor


    let return_candidates = []
    if delta_flg == 1
        " candidate修正
        for deltafile  in keys(s:bzr_delta_file)
            " コマンドの作成
            let s:seq = s:bzr_delta_file[deltafile]
            let max = len(s:seq) - 1

            "let cmd = "call unite#sources#bzr#vimdiff(''".s:last."'',''".s:first."'',''".deltafile."'')"
            let cmd = "call unite#sources#bzr#vimdiff('".s:seq[max]."','".s:seq[0]."','".deltafile."')"

            " candidateのコマンドの修正
            let cand = s:bzr_delta_candidate[deltafile]
            let cand.action__command = cmd
            call add(return_candidates, cand)

        endfor
    else
        let return_candidates = a:candidates
    endif

  return  return_candidates

endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

