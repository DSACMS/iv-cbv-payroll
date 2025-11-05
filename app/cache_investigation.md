# Cache Investigation

---
I gave a shot installing and running `solid_cache` on this branch with limited success.
Beyond the commit itself, here's the cli steps I ran to get the database installed to where I was at least able to call `Rails.cache.fetch`:
```bash
bundle add solid_cache
bin/rails railties:install:migrations FROM=solid_cache # might not be necessary
bin/rails solid_cache:install
bin/rails db:prepare
bin/rails db:migrate:cache
bin/rake db:setup
```

The problems I ran into were returning from the cache itself, there's something about the way the data is being serialized/deserialized that is causing issues. If you run through the flow you'll see what I mean.
