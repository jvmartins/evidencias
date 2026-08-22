-- Remove the 13 "Montes de Málaga" venues from the malaga cohort (production).
-- Drafted by the Orquestra Execute agent 2026-08-22. THE AGENT DID NOT RUN THIS.
-- Run it yourself:  psql "$DI_SUPABASE_DB_URL" -f delete-montes-de-malaga.sql
--
-- Companion PR (roster edit, must be merged so a reseed cannot resurrect them):
--   scripts/collection/rosters/malaga.json  33 -> 20 entities
--
-- WHAT CASCADES (ON DELETE CASCADE from entities.id) -- verified against prod:
--   entity_fields             204 rows  <- the collected answers, gone for good
--   entity_channel_state        0 rows
--   entity_contact_override     0 rows
--
-- WHAT DOES NOT CASCADE (slug-keyed text, no FK -- left as orphans on purpose,
-- per the delete-entities.mjs documented default and the ticket's assumption):
--   wa_sessions (restaurant_id)      2 rows   (the two aborted sessions)
--   collection_contacts (entity_slug) 1 row
--   wa_extractions / collection_pause / entity_opt_out / moderation_events
--                                     0 rows each
--
-- IRREVERSIBLE. The AI-visibility baseline moves 33 -> 20, so runs before and
-- after this point are not comparable.

\set ON_ERROR_STOP on
\pset pager off

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Pre-flight. Read these numbers before letting it commit.
--    Expected on 2026-08-22: 33 / 13 / 204 / 0 / 0 / 2 / 1 / 0 / 0 / 0 / 0
-- ---------------------------------------------------------------------------
WITH s(slug) AS (VALUES
  ('el-cortijo-de-santa-isabel'),
  ('senorio-de-lepanto'),
  ('venta-carlos-del-mirador'),
  ('venta-cortijo-los-tres-cincos'),
  ('venta-el-boticario'),
  ('venta-el-detalle'),
  ('venta-el-mijeno'),
  ('venta-el-puerto-del-leon'),
  ('venta-el-trepaolla'),
  ('venta-fuente-de-la-reina'),
  ('venta-la-minilla'),
  ('venta-los-montes'),
  ('venta-ventorrillo-de-santa-clara')
),
e AS (
  SELECT id, slug FROM entities
  WHERE destination = 'malaga' AND slug IN (SELECT slug FROM s)
)
SELECT 'entities (malaga, total)'            AS scope, count(*) AS n FROM entities WHERE destination = 'malaga'
UNION ALL SELECT 'entities (the 13)',             count(*) FROM e
UNION ALL SELECT 'entity_fields (cascades)',      count(*) FROM entity_fields          WHERE entity_id IN (SELECT id FROM e)
UNION ALL SELECT 'entity_channel_state (casc.)',  count(*) FROM entity_channel_state   WHERE entity_id IN (SELECT id FROM e)
UNION ALL SELECT 'entity_contact_override (c.)',  count(*) FROM entity_contact_override WHERE entity_id IN (SELECT id FROM e)
UNION ALL SELECT 'wa_sessions (orphaned)',        count(*) FROM wa_sessions            WHERE restaurant_id IN (SELECT slug FROM s)
UNION ALL SELECT 'wa_extractions (orphaned)',     count(*) FROM wa_extractions         WHERE restaurant_id IN (SELECT slug FROM s)
UNION ALL SELECT 'collection_contacts (orph.)',   count(*) FROM collection_contacts    WHERE entity_slug IN (SELECT slug FROM s)
UNION ALL SELECT 'collection_pause (orphaned)',   count(*) FROM collection_pause       WHERE entity_slug IN (SELECT slug FROM s)
UNION ALL SELECT 'entity_opt_out (orphaned)',     count(*) FROM entity_opt_out         WHERE entity_slug IN (SELECT slug FROM s)
UNION ALL SELECT 'moderation_events (orphaned)',  count(*) FROM moderation_events      WHERE entity_slug IN (SELECT slug FROM s);

-- ---------------------------------------------------------------------------
-- 2. The delete, guarded. Named slugs only -- never a query over `area`, so a
--    row that drifted into the area since drafting cannot be swept in.
--    Either assertion failing raises, which aborts the transaction and turns
--    the COMMIT below into a ROLLBACK. Nothing is left half-done.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  target text[] := ARRAY[
    'el-cortijo-de-santa-isabel',
    'senorio-de-lepanto',
    'venta-carlos-del-mirador',
    'venta-cortijo-los-tres-cincos',
    'venta-el-boticario',
    'venta-el-detalle',
    'venta-el-mijeno',
    'venta-el-puerto-del-leon',
    'venta-el-trepaolla',
    'venta-fuente-de-la-reina',
    'venta-la-minilla',
    'venta-los-montes',
    'venta-ventorrillo-de-santa-clara'
  ];
  deleted   integer;
  remaining integer;
  stragglers integer;
BEGIN
  DELETE FROM entities
   WHERE destination = 'malaga'
     AND slug = ANY (target);
  GET DIAGNOSTICS deleted = ROW_COUNT;

  IF deleted <> 13 THEN
    RAISE EXCEPTION 'aborting: expected to delete 13 entities, matched %', deleted;
  END IF;

  SELECT count(*) INTO remaining FROM entities WHERE destination = 'malaga';
  IF remaining <> 20 THEN
    RAISE EXCEPTION 'aborting: expected 20 malaga entities left, found %', remaining;
  END IF;

  SELECT count(*) INTO stragglers
    FROM entities WHERE destination = 'malaga' AND area = 'Montes de Málaga';
  IF stragglers <> 0 THEN
    RAISE EXCEPTION 'aborting: % Montes de Málaga entities still present', stragglers;
  END IF;

  RAISE NOTICE 'deleted % entities; malaga entities remaining: %', deleted, remaining;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Post-check. Expected: 20 / 0 / 0.
-- ---------------------------------------------------------------------------
SELECT 'entities (malaga, total)' AS scope, count(*) AS n
  FROM entities WHERE destination = 'malaga'
UNION ALL
SELECT 'entities still in Montes de Málaga', count(*)
  FROM entities WHERE destination = 'malaga' AND area = 'Montes de Málaga'
UNION ALL
SELECT 'orphaned entity_fields (must be 0)', count(*)
  FROM entity_fields f LEFT JOIN entities en ON en.id = f.entity_id
 WHERE en.id IS NULL;

COMMIT;
