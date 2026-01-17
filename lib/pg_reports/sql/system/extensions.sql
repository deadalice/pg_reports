-- Installed extensions
-- Shows all installed PostgreSQL extensions

SELECT
  extname AS name,
  extversion AS version,
  n.nspname AS schema,
  c.description
FROM pg_extension e
JOIN pg_namespace n ON e.extnamespace = n.oid
LEFT JOIN pg_description c ON c.objoid = e.oid AND c.classoid = 'pg_extension'::regclass
ORDER BY extname;
