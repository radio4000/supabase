CONNECTION_STRING=postgres://postgres:postgres@localhost:5432/postgres

install:
	curl -o 00-initial.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/db/init/00-initial-schema.sql
	curl -o 01-auth.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/db/init/01-auth-schema.sql
	curl -o 02-storage.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/db/init/02-storage-schema.sql
	curl -o 03-post-setup.sql https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/db/init/03-post-setup.sql

import:
	psql ${CONNECTION_STRING} -f 00-initial.sql
	psql ${CONNECTION_STRING} -f 01-auth.sql
	psql ${CONNECTION_STRING} -f 02-storage.sql
	psql ${CONNECTION_STRING} -f 03-post-setup.sql
	psql ${CONNECTION_STRING} -f 04-radio4000.sql
