# Updater
## One shot
```bash
ruby ofac_updater.rb once
```
## As service
```bash
ruby ofac_updater.rb
```

# Search example
```bash
curl -XGET 'http://localhost:9200/vofac/entry/_search?q=_all:torres'|json
```
