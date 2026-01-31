# DOMAIN-MAP — 도메인 관계 지도

- User 1:N Cat
- User 1:N ObservationGroup
- ObservationGroup 1:N ObservationItem(cat별)
- User 1:N Post
- Post 1:N Comment
- Topic 1:N Thread
- Thread 1:N Reply(1-depth)
- User N:M TopicFollow
- Like: User N:M (Post/Comment/Thread/Reply)
- Block: User N:M User (blocker/blocked)
- Report: User 1:N Report → target(Post/Comment/Thread/Reply/User)
- Catalog: Items/Aliases/Suggestions → InventoryItem과 연결(catalog_item_id + raw_text)
- User 1:1 HouseProfile
- User 1:N HouseSlot (room_key='living_room')
- HouseSlot N:0..1 InventoryItem (inventory_item_id)
