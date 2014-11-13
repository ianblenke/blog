require 'yaml'
require 'oauth'

config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/../_config.yml'))
linkedin_config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/linkedin_config.yml'))

api_key = linkedin_config['api_key']
api_secret = linkedin_config['api_secret']
user_token = linkedin_config['user_token']
user_secret = linkedin_config['user_secret']

configuration = { :site => 'https://api.linkedin.com' }
consumer = OAuth::Consumer.new(api_key, api_secret, configuration)
access_token = OAuth::AccessToken.new(consumer, user_token, user_secret)
response = access_token.get("https://api.linkedin.com/v1//people/~/network/updates", {'Content-Type'=>'application/xml'})

puts response.inspect

