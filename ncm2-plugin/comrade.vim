" Integrate the Comrade IntelliJ plugin with the NCM2 completion plugin

let s:source = {
	\ 'name': 'Comrade IntelliJ',
	\ 'mark': 'IDEA',
	\ 'enable': v:true,
	\ 'ready': v:true,
	\ 'priority': 9,
	\ 'scope': ['java', 'xml', 'asciidoc'],
	\ 'complete_pattern': ['\w+'],
	\ 'on_complete': {context -> s:on_complete(context)},
	\ 'complete_length': 1,
\ }

" ---[ Pending request stash ]-------------------------------------------------
" Comrade uses RPC requests to get completion results; in the worst case this
" can block the editor while waiting for results, so it uses a trick from
" Deoplete to keep wait times short: the Deoplete context has a 'is_async'
" entry which can be true (wait for more to come) or false (nothing to display
" yet). Comrade then keeps sending out requests from time to time.
"
" NCM2 on the other hand uses a callback mechanism. Whenever a completion
" request is performed we stash it in a dictionary, and when all results are in
" we remove it and display the completion results.
" let s:pending = {}


" -----------------------------------------------------------------------------
" The callback function, will be called when Comrade wants to display
" completion
function! s:on_complete(context)
	let l:buf_id = a:context['bufnr']
	let l:changedtick = nvim_buf_get_changedtick(l:buf_id)
	let l:buf_name = nvim_buf_get_name(l:buf_id)
	let l:win = nvim_get_current_win()

	let [l:row, l:col] = nvim_win_get_cursor(l:win)

	" a:context['is_async'] is not supported by NCM2, but we can use
	" ncm2#complete_context_data to find out if the context is stale
	let l:dated = ncm2#complete_context_dated(a:context)
	let l:ret = {
		\ 'buf_id': l:buf_id,
		\ 'buf_name': l:buf_name,
		\ 'buf_changedtick': l:changedtick,
		\ 'row': l:row,
		\ 'col': l:col,
		\ 'new_request': v:true,
	\ }

	call s:send_request(a:context, l:buf_id, l:ret)
endfunction

" This function sends a blocking request to IntelliJ; IntelliJ returns almost
" immediately, but the result is incomplete, it keeps building up further
" results in the background.
function! s:send_request(ctx, buf_id, ret)
	" body
	let l:results = comrade#RequestCompletion(a:buf_id, a:ret)
	let a:ret['new_request'] = v:false

	while !l:results['is_finished']
		let l:results = comrade#RequestCompletion(a:buf_id, a:ret)
		if !empty(l:results.candidates)
			call ncm2#complete(a:ctx, a:ctx.startccol, l:results.candidates)
		endif
		call wait(10, { -> v:false })
	endwhile
endfunction

" Not yet ready for use
call ncm2#register_source(s:source)
