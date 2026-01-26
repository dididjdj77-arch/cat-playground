# RLS-POLICY — Supabase RLS 초안(선택)

주의: RLS는 잘못 설계하면 개발이 매우 느려질 수 있음.
v1에서는 공개 읽기를 “뷰/함수”로 제공하고, 쓰기는 Edge Function/RPC로 중앙화하는 방식도 권장.

초안:
- posts: 본인=author_id=auth.uid() / 타인=public+published+not hidden+not deleted (block은 함수/뷰에서)
- threads/replies: is_public + not hidden + not deleted (block은 함수/뷰)
- inventory_items: 본인만 기본. public 공개는 요약 뷰로만 제공 권장.
