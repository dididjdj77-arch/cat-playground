-- Patch: D-016 compliance — grant anon execute on public channel RPCs
-- rpc_list_topics and rpc_search_threads must be accessible by anon
-- for SEO/public web surface (D-016: 토픽 전부 공개 읽기 가능)

begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

grant execute on function public.rpc_list_topics() to anon;
grant execute on function public.rpc_search_threads(text, uuid, text, int) to anon;

commit;
