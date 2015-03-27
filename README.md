# OFAC Elasticsearch Feeder
## Update
### One shot
```bash
ruby ofac_updater.rb once
```
### As service
```bash
ruby ofac_updater.rb
```
### Debugging
```bash
DEBUG=true ruby ofac_updater.rb once
```
## Search example
```bash
curl -XGET 'http://localhost:9200/vofac/entry/_search?q=_all:mohamed'|json
```
