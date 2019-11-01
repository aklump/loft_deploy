# Using Environment Variables

## Database connection

If your database credentials are in the environment then you should configure something like the following.  If it's in one variable as an URL then use the `url` key, e.g., `mysql://USER:PASSWORD@HOST:PORT/DB_NAME`.

    local:
      database:
        backups: private/default/db/purgeable
        uri: $DATABASE_URL
        
If you need to point to an environment file to be automatically loaded first you can add this
    
    local:
      env_file:
        - .env
