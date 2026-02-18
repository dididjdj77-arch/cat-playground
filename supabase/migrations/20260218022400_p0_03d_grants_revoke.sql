begin;

set local lock_timeout = '3s';
set local statement_timeout = '30s';

revoke select on table public.profiles from anon, authenticated;
revoke select on table public.profile_settings from anon, authenticated;
revoke select on table public.cats from anon, authenticated;
revoke select on table public.catalog_items from anon, authenticated;
revoke select on table public.catalog_aliases from anon, authenticated;
revoke select on table public.catalog_suggestions from anon, authenticated;
revoke select on table public.house_profiles from anon, authenticated;
revoke select on table public.house_slots from anon, authenticated;
revoke select on table public.inventory_items from anon, authenticated;
revoke select on table public.observation_groups from anon, authenticated;
revoke select on table public.observations from anon, authenticated;
revoke select on table public.observation_patch_dedup from anon, authenticated;
revoke select on table public.observation_inventory_refs from anon, authenticated;
revoke select on table public.topics from anon, authenticated;
revoke select on table public.topic_follows from anon, authenticated;
revoke select on table public.threads from anon, authenticated;
revoke select on table public.replies from anon, authenticated;
revoke select on table public.posts from anon, authenticated;
revoke select on table public.comments from anon, authenticated;
revoke select on table public.comment_revisions from anon, authenticated;
revoke select on table public.reply_revisions from anon, authenticated;
revoke select on table public.likes from anon, authenticated;
revoke select on table public.blocks from anon, authenticated;
revoke select on table public.reports from anon, authenticated;
revoke select on table public.moderation_actions from anon, authenticated;
revoke select on table public.notifications from anon, authenticated;
revoke select on table public.ops_metrics from anon, authenticated;
revoke select on table public.payload_versions from anon, authenticated;
revoke select on table public.payload_version_events from anon, authenticated;
revoke select on table public.payload_version_rollups from anon, authenticated;
revoke select on table public.app_config from anon, authenticated;

commit;
