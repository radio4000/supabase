CONNECTION_STRING=postgres://postgres:postgres@localhost:5432/postgres

install:
	curl -o 00-initial.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/dockerfiles/postgres/00-initial-schema.sql
	curl -o 01-auth.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/dockerfiles/postgres/auth-schema.sql
	curl -o 02-storage.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/dockerfiles/postgres/storage-schema.sql
	psql ${CONNECTION_STRING} -f 00-initial.sql
	psql ${CONNECTION_STRING} -f 01-auth.sql
	psql ${CONNECTION_STRING} -f 02-storage.sql
	psql ${CONNECTION_STRING} -f 03-radio4000.sql
