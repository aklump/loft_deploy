SELECT table_name FROM information_schema.tables WHERE table_schema = '$local_db_name' AND (table_name LIKE 'cache%' OR table_name LIKE 'old_%');
