require 'elasticsearch'

class Man
  attr_accessor :client

  def initialize
    @client = Elasticsearch::Client.new(host: 'localhost', port: 9200)
  end

  def create_index
    indices = {
      index: 'elasticsearch_message',
      body: {
        mappings: {
          document: {
            properties: {
              command: {
                type: :text
              },
              description: {
                type: :text,
                analyzer: :english
              },
              man_page: {
                type: :text,
                analyzer: :english
              }
            }
          }
        }
      }
    }
    client.indices.create(indices)
  end

  def fill_pages
    all_pages = `apropos .`.split "\n"

    apropos_regex = /(.*)\s\(\d*.*\)\s*-\s*(.*)/
    all_pages.each do |line|
      matches = apropos_regex.match line
      command = matches[1]
      description = matches[2]
      manpage = `man #{command}`

      @client.index index: 'elastic_manpages',
                    type: :document,
                    body: {
                      command: command,
                      description: description,
                      manpage: manpage
                    }
    end
  end

  def search(term)
    search_query = { index: 'elastic_manpages',
                     size: 10,
                     body: {
                       query: {
                         multi_match: {
                           query: term,
                           type: :cross_fields,
                           fields: ['command', 'description^3', 'manpage^3'],
                           operator: :or,
                           tie_breaker: 1.0,
                           cutoff_frequency: 0.1
                         }
                       }
                     } }

    result = @client.search(search_query)

    result['hits']['hits'].map do |hit|
      {
        command: hit['_source']['command'],
        description: hit['_source']['description'],
        manpage: hit['_source']['manpage']
      }
    end
  end
end
