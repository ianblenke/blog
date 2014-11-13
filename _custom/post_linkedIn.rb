require 'yaml'
require 'oauth'

class LinkedInPoster
  def initialize
    @config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/../_config.yml'))
    @linkedin_config = YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/linkedin_config.yml'))
  end

  def post_linkedin

    api_key = @linkedin_config['api_key']
    api_secret = @linkedin_config['api_secret']
    user_token = @linkedin_config['user_token']
    user_secret = @linkedin_config['user_secret']

    configuration = { :site => 'https://api.linkedin.com' }
    consumer = OAuth::Consumer.new(api_key, api_secret, configuration)
    access_token = OAuth::AccessToken.new(consumer, user_token, user_secret)
    new_post = generate_post
    puts 'New linkedin post content:'
    puts new_post
    response = access_token.post("https://api.linkedin.com/v1/people/~/shares", generate_post, {'Content-Type'=>'application/xml'})

    puts 'Response of posting to linkedin:'
    puts response.body.gsub(/amp;/,'')

  end

  private

  def generate_post
    post_template = IO.read(File.expand_path(File.dirname(__FILE__) + '/linkedin.xml')).force_encoding("utf-8")
    post_template % {:blog_title => latest_blog_title, :blog_url => generate_blog_url, :blog_summary => latest_blog_summary, :blog_comment => latest_blog_comment}
  end

  def latest_blog_title
    title_line = IO.readlines(latest_blog_file_name)[2]
    title_line["title: ".length..title_line.length].force_encoding("utf-8")
  end

  def latest_blog_summary
    summary_line = IO.readlines(latest_blog_file_name)[3]
    summary_line["summary: ".length..summary_line.length].force_encoding("utf-8")
  end

  def latest_blog_comment
    comment_line = IO.readlines(latest_blog_file_name)[5]
    comment_line["content: ".length..comment_line.length].force_encoding("utf-8")
  end

  def latest_blog_file_name
    blogs_path = File.expand_path(File.dirname(__FILE__) + '/../source/_posts')
    filtered_right_blog = Dir.glob(blogs_path + "/*").select { |f| f.match(/\.markdown/) }
    filtered_right_blog.max_by { |f| File.mtime(f) }
  end

  def generate_blog_url
    full_url = @config['url'] + "/blog/" + convert_to_blog_url(latest_blog_file_name)
    full_url.force_encoding("utf-8")
  end

  def convert_to_blog_url(post_file_name)
    #convert 2012-12-21-demo-blog.markdown file name to be normal blog url: 2012/12/21/demo-blog
    File.basename(post_file_name, ".markdown").gsub(/\d-/) { |s| s[0] + "/" }
  end
end

poster = LinkedInPoster.new
poster.post_linkedin
