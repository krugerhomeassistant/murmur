# Sprite overrides

A PNG here replaces the procedural drawing of a building. See [docs/SPRITES_DESIGN.md](../../../docs/SPRITES_DESIGN.md).

Layout: `<age>/b<building id>_<level>.png`, then `<age>/b<id>.png`, falling back through older ages and then `all/`. Ages: `ancient`, `medieval`, `industrial`, `modern`. Building ids are in `client/scripts/catalog.gd` (`Catalog.Id`). One tile is 32 px; any square size works (64 or 128 px for sharper art).

Templates: `xvfb-run godot --path client -s tools/bake_sprites.gd -- art/bake 2` renders every current drawing to PNG (not live; copy the ones you want here).
