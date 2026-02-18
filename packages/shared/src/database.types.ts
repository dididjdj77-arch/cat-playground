export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      app_config: {
        Row: {
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
        }
        Insert: {
          key: string
          updated_at?: string
          updated_by?: string | null
          value: Json
        }
        Update: {
          key?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "app_config_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      blocks: {
        Row: {
          blocked_id: string
          blocker_id: string
          created_at: string
        }
        Insert: {
          blocked_id: string
          blocker_id: string
          created_at?: string
        }
        Update: {
          blocked_id?: string
          blocker_id?: string
          created_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "blocks_blocked_id_fkey"
            columns: ["blocked_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "blocks_blocker_id_fkey"
            columns: ["blocker_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      catalog_aliases: {
        Row: {
          alias: string
          catalog_item_id: string
          created_at: string
          id: string
          type: string
        }
        Insert: {
          alias: string
          catalog_item_id: string
          created_at?: string
          id?: string
          type: string
        }
        Update: {
          alias?: string
          catalog_item_id?: string
          created_at?: string
          id?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_aliases_catalog_item_id_fkey"
            columns: ["catalog_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_items: {
        Row: {
          brand: string | null
          created_at: string
          id: string
          metadata: Json
          standard_name: string
          type: string
          updated_at: string
        }
        Insert: {
          brand?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          standard_name: string
          type: string
          updated_at?: string
        }
        Update: {
          brand?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          standard_name?: string
          type?: string
          updated_at?: string
        }
        Relationships: []
      }
      catalog_suggestions: {
        Row: {
          created_at: string
          id: string
          raw_text: string
          resolved_catalog_item_id: string | null
          review_note: string | null
          reviewed_by: string | null
          status: string
          suggested_by: string
          type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          raw_text: string
          resolved_catalog_item_id?: string | null
          review_note?: string | null
          reviewed_by?: string | null
          status?: string
          suggested_by: string
          type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          raw_text?: string
          resolved_catalog_item_id?: string | null
          review_note?: string | null
          reviewed_by?: string | null
          status?: string
          suggested_by?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_suggestions_resolved_catalog_item_id_fkey"
            columns: ["resolved_catalog_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_suggestions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "catalog_suggestions_suggested_by_fkey"
            columns: ["suggested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      cats: {
        Row: {
          avatar_key: string | null
          avatar_url: string | null
          birth_date: string | null
          breed: string | null
          created_at: string
          deleted_at: string | null
          id: string
          name: string
          owner_id: string
          sex: string | null
          updated_at: string
        }
        Insert: {
          avatar_key?: string | null
          avatar_url?: string | null
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          name: string
          owner_id: string
          sex?: string | null
          updated_at?: string
        }
        Update: {
          avatar_key?: string | null
          avatar_url?: string | null
          birth_date?: string | null
          breed?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          name?: string
          owner_id?: string
          sex?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "cats_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      comment_revisions: {
        Row: {
          comment_id: string
          created_at: string
          id: string
          previous_body: string
        }
        Insert: {
          comment_id: string
          created_at?: string
          id?: string
          previous_body: string
        }
        Update: {
          comment_id?: string
          created_at?: string
          id?: string
          previous_body?: string
        }
        Relationships: [
          {
            foreignKeyName: "comment_revisions_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: true
            referencedRelation: "comments"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          author_id: string
          body: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          hidden_at: string | null
          id: string
          like_count: number
          post_id: string
          updated_at: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          id?: string
          like_count?: number
          post_id: string
          updated_at?: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          id?: string
          like_count?: number
          post_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      house_profiles: {
        Row: {
          created_at: string
          deleted_at: string | null
          hidden_at: string | null
          published_at: string | null
          updated_at: string
          user_id: string
          visibility: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          hidden_at?: string | null
          published_at?: string | null
          updated_at?: string
          user_id: string
          visibility?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          hidden_at?: string | null
          published_at?: string | null
          updated_at?: string
          user_id?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "house_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      house_slots: {
        Row: {
          created_at: string
          deleted_at: string | null
          equipped_at: string | null
          id: string
          inventory_item_id: string | null
          owner_id: string
          room_key: string
          slot_key: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          equipped_at?: string | null
          id?: string
          inventory_item_id?: string | null
          owner_id: string
          room_key?: string
          slot_key: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          equipped_at?: string | null
          id?: string
          inventory_item_id?: string | null
          owner_id?: string
          room_key?: string
          slot_key?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "house_slots_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "house_slots_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      inventory_items: {
        Row: {
          catalog_item_id: string | null
          changed_at: string
          created_at: string
          deleted_at: string | null
          ended_at: string | null
          id: string
          is_current: boolean
          meta: Json
          note: string | null
          owner_id: string
          raw_text: string | null
          reason_code: string
          reason_note: string | null
          type: string
          updated_at: string
        }
        Insert: {
          catalog_item_id?: string | null
          changed_at?: string
          created_at?: string
          deleted_at?: string | null
          ended_at?: string | null
          id?: string
          is_current?: boolean
          meta?: Json
          note?: string | null
          owner_id: string
          raw_text?: string | null
          reason_code?: string
          reason_note?: string | null
          type: string
          updated_at?: string
        }
        Update: {
          catalog_item_id?: string | null
          changed_at?: string
          created_at?: string
          deleted_at?: string | null
          ended_at?: string | null
          id?: string
          is_current?: boolean
          meta?: Json
          note?: string | null
          owner_id?: string
          raw_text?: string | null
          reason_code?: string
          reason_note?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_items_catalog_item_id_fkey"
            columns: ["catalog_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_items_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      likes: {
        Row: {
          created_at: string
          id: string
          target_id: string
          target_type: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          target_id: string
          target_type: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          target_id?: string
          target_type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      moderation_actions: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: string
          meta: Json | null
          target_id: string
          target_type: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: string
          meta?: Json | null
          target_id: string
          target_type: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: string
          meta?: Json | null
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "moderation_actions_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      notifications: {
        Row: {
          actor_id: string
          created_at: string
          id: string
          read_at: string | null
          target_id: string
          target_type: string
          type: string
          user_id: string
        }
        Insert: {
          actor_id: string
          created_at?: string
          id?: string
          read_at?: string | null
          target_id: string
          target_type: string
          type: string
          user_id: string
        }
        Update: {
          actor_id?: string
          created_at?: string
          id?: string
          read_at?: string | null
          target_id?: string
          target_type?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      observation_groups: {
        Row: {
          common_payload: Json
          created_at: string
          deleted_at: string | null
          id: string
          idempotency_key: string
          log_date: string
          owner_id: string
          payload_version: string
          updated_at: string
          version: number
        }
        Insert: {
          common_payload?: Json
          created_at?: string
          deleted_at?: string | null
          id?: string
          idempotency_key: string
          log_date: string
          owner_id: string
          payload_version: string
          updated_at?: string
          version?: number
        }
        Update: {
          common_payload?: Json
          created_at?: string
          deleted_at?: string | null
          id?: string
          idempotency_key?: string
          log_date?: string
          owner_id?: string
          payload_version?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "observation_groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      observation_inventory_refs: {
        Row: {
          created_at: string
          group_id: string
          id: string
          inv_type: string
          inventory_item_id: string
          owner_id: string
        }
        Insert: {
          created_at?: string
          group_id: string
          id?: string
          inv_type: string
          inventory_item_id: string
          owner_id: string
        }
        Update: {
          created_at?: string
          group_id?: string
          id?: string
          inv_type?: string
          inventory_item_id?: string
          owner_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "observation_inventory_refs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "observation_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observation_inventory_refs_inventory_item_id_fkey"
            columns: ["inventory_item_id"]
            isOneToOne: false
            referencedRelation: "inventory_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observation_inventory_refs_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      observation_patch_dedup: {
        Row: {
          created_at: string
          group_id: string
          id: string
          idempotency_key: string
          owner_id: string
          result_json: Json | null
        }
        Insert: {
          created_at?: string
          group_id: string
          id?: string
          idempotency_key: string
          owner_id: string
          result_json?: Json | null
        }
        Update: {
          created_at?: string
          group_id?: string
          id?: string
          idempotency_key?: string
          owner_id?: string
          result_json?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "observation_patch_dedup_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "observation_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observation_patch_dedup_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      observations: {
        Row: {
          cat_id: string
          created_at: string
          deleted_at: string | null
          group_id: string
          id: string
          override_payload: Json | null
          owner_id: string
          status: string
          updated_at: string
        }
        Insert: {
          cat_id: string
          created_at?: string
          deleted_at?: string | null
          group_id: string
          id?: string
          override_payload?: Json | null
          owner_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          cat_id?: string
          created_at?: string
          deleted_at?: string | null
          group_id?: string
          id?: string
          override_payload?: Json | null
          owner_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "observations_cat_id_fkey"
            columns: ["cat_id"]
            isOneToOne: false
            referencedRelation: "cats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observations_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "observation_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "observations_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      ops_metrics: {
        Row: {
          created_at: string
          id: string
          meta: Json | null
          metric_key: string
          metric_value_num: number | null
          metric_value_text: string | null
          ts: string
        }
        Insert: {
          created_at?: string
          id?: string
          meta?: Json | null
          metric_key: string
          metric_value_num?: number | null
          metric_value_text?: string | null
          ts?: string
        }
        Update: {
          created_at?: string
          id?: string
          meta?: Json | null
          metric_key?: string
          metric_value_num?: number | null
          metric_value_text?: string | null
          ts?: string
        }
        Relationships: []
      }
      payload_version_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          reason: string | null
          request_id: string | null
          ts: string
          version: string
        }
        Insert: {
          created_at?: string
          event_type: string
          id?: string
          reason?: string | null
          request_id?: string | null
          ts?: string
          version: string
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          reason?: string | null
          request_id?: string | null
          ts?: string
          version?: string
        }
        Relationships: []
      }
      payload_version_rollups: {
        Row: {
          bucket_ts: string
          last_seen_at: string | null
          normalize_fail_count: number
          reject_count: number
          seen_count: number
          unknown_count: number
          version: string
        }
        Insert: {
          bucket_ts: string
          last_seen_at?: string | null
          normalize_fail_count?: number
          reject_count?: number
          seen_count?: number
          unknown_count?: number
          version: string
        }
        Update: {
          bucket_ts?: string
          last_seen_at?: string | null
          normalize_fail_count?: number
          reject_count?: number
          seen_count?: number
          unknown_count?: number
          version?: string
        }
        Relationships: []
      }
      payload_versions: {
        Row: {
          created_at: string
          meta: Json | null
          state: string
          updated_at: string
          version: string
        }
        Insert: {
          created_at?: string
          meta?: Json | null
          state: string
          updated_at?: string
          version: string
        }
        Update: {
          created_at?: string
          meta?: Json | null
          state?: string
          updated_at?: string
          version?: string
        }
        Relationships: []
      }
      posts: {
        Row: {
          author_id: string
          body: string
          comment_count: number
          created_at: string
          deleted_at: string | null
          hidden_at: string | null
          hide_from_profile: boolean
          id: string
          like_count: number
          log_date: string
          meta: Json
          published_at: string | null
          updated_at: string
          visibility: string
        }
        Insert: {
          author_id: string
          body: string
          comment_count?: number
          created_at?: string
          deleted_at?: string | null
          hidden_at?: string | null
          hide_from_profile?: boolean
          id?: string
          like_count?: number
          log_date: string
          meta?: Json
          published_at?: string | null
          updated_at?: string
          visibility?: string
        }
        Update: {
          author_id?: string
          body?: string
          comment_count?: number
          created_at?: string
          deleted_at?: string | null
          hidden_at?: string | null
          hide_from_profile?: boolean
          id?: string
          like_count?: number
          log_date?: string
          meta?: Json
          published_at?: string | null
          updated_at?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      profile_settings: {
        Row: {
          created_at: string
          default_post_visibility: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          default_post_visibility?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          default_post_visibility?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "profile_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_key: string | null
          avatar_url: string | null
          bio: string | null
          created_at: string
          deleted_at: string | null
          id: string
          is_admin: boolean
          nickname: string
          nickname_changed_at: string | null
          terms_agreed_at: string | null
          updated_at: string
          user_id: string | null
        }
        Insert: {
          avatar_key?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          is_admin?: boolean
          nickname: string
          nickname_changed_at?: string | null
          terms_agreed_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          avatar_key?: string | null
          avatar_url?: string | null
          bio?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          is_admin?: boolean
          nickname?: string
          nickname_changed_at?: string | null
          terms_agreed_at?: string | null
          updated_at?: string
          user_id?: string | null
        }
        Relationships: []
      }
      replies: {
        Row: {
          author_id: string
          body: string
          created_at: string
          deleted_at: string | null
          edited_at: string | null
          hidden_at: string | null
          id: string
          like_count: number
          thread_id: string
          updated_at: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          id?: string
          like_count?: number
          thread_id: string
          updated_at?: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          deleted_at?: string | null
          edited_at?: string | null
          hidden_at?: string | null
          id?: string
          like_count?: number
          thread_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "replies_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "replies_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "threads"
            referencedColumns: ["id"]
          },
        ]
      }
      reply_revisions: {
        Row: {
          created_at: string
          id: string
          previous_body: string
          reply_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          previous_body: string
          reply_id: string
        }
        Update: {
          created_at?: string
          id?: string
          previous_body?: string
          reply_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "reply_revisions_reply_id_fkey"
            columns: ["reply_id"]
            isOneToOne: true
            referencedRelation: "replies"
            referencedColumns: ["id"]
          },
        ]
      }
      reports: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          note: string | null
          reason_code: string
          reporter_id: string
          snapshot: Json | null
          target_id: string
          target_type: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          note?: string | null
          reason_code: string
          reporter_id: string
          snapshot?: Json | null
          target_id: string
          target_type: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          note?: string | null
          reason_code?: string
          reporter_id?: string
          snapshot?: Json | null
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "reports_reporter_id_fkey"
            columns: ["reporter_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      threads: {
        Row: {
          author_id: string
          body: string
          created_at: string
          deleted_at: string | null
          fts_vector: unknown
          hidden_at: string | null
          id: string
          like_count: number
          reply_count: number
          title: string
          topic_id: string
          updated_at: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string
          deleted_at?: string | null
          fts_vector?: unknown
          hidden_at?: string | null
          id?: string
          like_count?: number
          reply_count?: number
          title: string
          topic_id: string
          updated_at?: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string
          deleted_at?: string | null
          fts_vector?: unknown
          hidden_at?: string | null
          id?: string
          like_count?: number
          reply_count?: number
          title?: string
          topic_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "threads_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "threads_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
        ]
      }
      topic_follows: {
        Row: {
          created_at: string
          topic_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          topic_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          topic_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "topic_follows_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "topic_follows_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      topics: {
        Row: {
          created_at: string
          deleted_at: string | null
          description: string | null
          id: string
          is_public: boolean
          name: string
          slug: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          is_public?: boolean
          name: string
          slug: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          description?: string | null
          id?: string
          is_public?: boolean
          name?: string
          slug?: string
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      check_auto_hide: {
        Args: { p_target_id: string; p_target_type: string }
        Returns: undefined
      }
      guard_block: {
        Args: { p_target_user_id: string; p_viewer_id: string }
        Returns: boolean
      }
      guard_soft_state: {
        Args: { p_deleted_at: string; p_hidden_at: string }
        Returns: boolean
      }
      guard_terms_agreed: { Args: never; Returns: Json }
      guard_visibility_published: {
        Args: { p_published_at: string; p_visibility: string }
        Returns: boolean
      }
      rpc_block_user: { Args: { p_blocked_user_id: string }; Returns: Json }
      rpc_create_comment: {
        Args: { p_body: string; p_post_id: string }
        Returns: Json
      }
      rpc_create_post: {
        Args: {
          p_body: string
          p_hide_from_profile?: boolean
          p_log_date: string
          p_meta?: Json
          p_visibility: string
        }
        Returns: Json
      }
      rpc_delete_comment: { Args: { p_comment_id: string }; Returns: Json }
      rpc_delete_post: { Args: { p_post_id: string }; Returns: Json }
      rpc_get_app_config: { Args: { p_keys: string[] }; Returns: Json }
      rpc_get_public_post_comments: {
        Args: { p_cursor?: string; p_limit?: number; p_post_id: string }
        Returns: Json
      }
      rpc_get_public_post_detail: { Args: { p_post_id: string }; Returns: Json }
      rpc_get_public_posts_feed: {
        Args: { p_cursor?: string; p_limit?: number }
        Returns: Json
      }
      rpc_inventory_correction: {
        Args: {
          p_catalog_item_id?: string
          p_changed_at?: string
          p_raw_text: string
          p_reason_note?: string
          p_type: string
        }
        Returns: Json
      }
      rpc_inventory_discontinue: {
        Args: { p_reason_note?: string; p_type: string }
        Returns: Json
      }
      rpc_inventory_switch: {
        Args: {
          p_catalog_item_id?: string
          p_changed_at?: string
          p_raw_text: string
          p_reason_note?: string
          p_type: string
        }
        Returns: Json
      }
      rpc_patch_observation_items: {
        Args: {
          p_expected_version: number
          p_group_id: string
          p_idempotency_key: string
          p_patches: Json
        }
        Returns: Json
      }
      rpc_publish_post: { Args: { p_post_id: string }; Returns: Json }
      rpc_report_content: {
        Args: {
          p_note?: string
          p_reason_code: string
          p_target_id: string
          p_target_type: string
        }
        Returns: Json
      }
      rpc_toggle_like: {
        Args: { p_target_id: string; p_target_type: string }
        Returns: Json
      }
      rpc_unblock_user: { Args: { p_blocked_user_id: string }; Returns: Json }
      rpc_unhide_content: {
        Args: { p_target_id: string; p_target_type: string }
        Returns: Json
      }
      rpc_unpublish_post: { Args: { p_post_id: string }; Returns: Json }
      rpc_update_comment: {
        Args: { p_body: string; p_comment_id: string }
        Returns: Json
      }
      rpc_update_post: {
        Args: {
          p_body?: string
          p_hide_from_profile?: boolean
          p_meta?: Json
          p_post_id: string
          p_visibility?: string
        }
        Returns: Json
      }
      rpc_upsert_observation_group_with_items: {
        Args: {
          p_common_payload: Json
          p_idempotency_key: string
          p_inventory_refs?: Json
          p_items: Json
          p_log_date: string
          p_payload_version: string
        }
        Returns: Json
      }
      validate_payload_version: { Args: { p_version: string }; Returns: Json }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

