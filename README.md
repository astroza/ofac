# OFAC Elasticsearch Feeder
## Dependencies installation
```bash
bundle install
```
## Update
### One shot
```bash
APP_ENV=development bundle exec ruby ofac_updater.rb once
```
### As service
```bash
APP_ENV=development bundle exec ruby ofac_updater.rb
```
### Debugging
```bash
APP_ENV=development DEBUG=true bundle exec ruby ofac_updater.rb once
```
## Search example
```bash
curl -XGET 'http://localhost:9200/vofac_development/entry/_search?q=_all:mohamed'|json
```
