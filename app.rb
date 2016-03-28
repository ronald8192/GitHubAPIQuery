require 'net/http'
require 'json'
require 'mongo'
require 'csv'

class Query
  attr_accessor :client_id, :client_secret

  @dbclient
  @client_id = ''
  @client_secret = ''

  def getJSON(path)
    http = Net::HTTP.new('api.github.com', 443)
    http.use_ssl = true
    puts http.address + path
    reply = http.get("#{path}?client_id=#{@client_id}&client_secret=#{@client_secret}")
    #puts reply.inspect

    puts "RateLimit-Remaining: " + reply.get_fields('X-RateLimit-Remaining')[0]

    json = ''
    if reply.response.kind_of? Net::HTTPSuccess or reply.response.kind_of? Net::HTTPMovedPermanently or reply.response.kind_of? Net::HTTPTemporaryRedirect
      json = JSON.parse(reply.body)
      if(json.key?('message'))
        puts json['message']
        uri = URI.parse json['url']
        json = getJSON uri.path
      end
    else
      raise "#{reply.response.code} #{reply.response.message}"
      #puts "#{reply.response.code} #{reply.response.message}"
    end
    json
  end

  def getUserDetails(username)
    path_prefix = '/users/'
    details = getJSON "#{path_prefix}#{username}"
    {:username => username, :location => details['location'], :email => details['email']}
  end

  # List languages for the specified repository. The value on the right of a language is the number of bytes of code written in that language.
  # { "C": 78769, "Python": 7769 }
  def getRepoLanguages(reponame)
    path_prefix = '/repos/'
    path_suffix = '/languages'
    details = getJSON "#{path_prefix}#{reponame}#{path_suffix}"
    {:repo_name => reponame, :language => details}
  end

  def initDB
    @client = Mongo::Client.new(['localhost'], :database => 'datamining')
    # db = @client.use("datamining")
  end

  def saveToDB(collection, document)
    @client[collection].insert_one(document)
  end

  def find(collection, key, value)
    @client[collection].find(key => value)
  end
end

##################################################################

query = Query.new
query.initDB
apikey = JSON.parse(File.read('githubapi.json'))
query.client_id = apikey['client_id']
query.client_secret = apikey['client_secret']

dataFiles = Dir.entries('data/').select{|dataFile| dataFile.end_with?('.csv')}

dataFiles.map{ |dataFile|
  file = File.open("data/#{dataFile}")
  firstLine = file.readline.strip
  CSV.foreach(file, {col_sep:',',row_sep: :auto, skip_lines:firstLine}) do |csvRow|
    puts csvRow.inspect # [type, actor_name, repo_name, created_at]

    csvRow = csvRow.to_a

    apiQueryFailed = false

    actor = query.find(:user, :username, csvRow[1]).to_a
    if actor.count == 0
      begin
        actor = query.getUserDetails(csvRow[1])
        Thread.new{
          query.saveToDB(:user,{username:actor[:username],location:actor[:location], email:actor[:email]})
        }
      rescue Exception => e
        STDERR.puts e.message
        apiQueryFailed = true
      end
    else
      actor = actor[0]
    end

    if !apiQueryFailed
      repo = query.find(:repo, :repo_name, csvRow[2]).to_a
      if repo.count == 0
        begin
          repo = query.getRepoLanguages(csvRow[2])
          Thread.new{
            query.saveToDB(:repo,{repo_name:repo[:repo_name], language:repo[:language]})
          }
        rescue Exception => e
          STDERR.puts e.message
          apiQueryFailed = true
        end
      else
        repo = repo[0]
      end
    end

    if !apiQueryFailed
      puts actor.inspect
      puts repo.inspect
      document = {
          type:csvRow[0],
          actor_name:actor[:username],
          actor_location: actor[:location],
          actor_email:actor[:email],
          repo_name: repo[:repo_name],
          language: repo[:language],
          created_at: csvRow[3]
      }
      Thread.new{
        query.saveToDB(:githubData,document)
      }
    end

  end
}