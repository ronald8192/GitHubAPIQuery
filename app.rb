require 'net/http'
require 'json'
require 'mongo'


# Net::HTTP.get('example.com', '/index.html')
#
# file = File.read('test.json')
# hash = JSON.parse(file)

class Query

  @dbclient

  def getJSON(path)
    http = Net::HTTP.new('api.github.com', 443)
    http.use_ssl = true
    puts http.address + path
    reply = http.get(path)
    json = ''
    if reply.response.kind_of? Net::HTTPSuccess
      json = JSON.parse(reply.body)
    else
      raise "#{reply.response.code} #{reply.response.message}"
    end
    json
  end

  def getUserDetails(username)
    path_prefix = '/users/'
    details = getJSON "#{path_prefix}#{username}"
    {:username => username, :location => details['location'], :email => details['email']}
  end

  def getRepoDetails(username, reponame)
    path_prefix = '/repos/'
    details = getJSON "#{path_prefix}#{username}/#{reponame}"
    {:repo_name => reponame, :language => details['language']}
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



query = Query.new
userDetails = query.getUserDetails('hermanwahyudi')
repoDetails = query.getRepoDetails('petrkutalek', 'png2pos')

query.initDB

if query.find(:user, :actor_name,userDetails[:username]).count==0
  query.saveToDB(:user,{actor_name:userDetails[:username],location:userDetails[:location], email:userDetails[:email]})
end
if query.find(:repo, :repo_name,repoDetails[:repo_name]).count==0
  query.saveToDB(:repo,{repo_name:repoDetails[:repo_name], language:repoDetails[:language]})
end


user = query.find(:user, :actor_name,userDetails[:username]).to_a[0]
puts user[:actor_name]
puts user[:location]
puts user[:email]

repo = query.find(:repo, :repo_name,repoDetails[:repo_name]).to_a[0]
puts repo[:repo_name]
puts repo[:language]
