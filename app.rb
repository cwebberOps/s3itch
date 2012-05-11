require 'bundler'
Bundler.setup

require 'sinatra'
require 'fog'
require 'mime/types'

class S3itchApp < Sinatra::Base

  configure do
    if ENV['HTTP_USER'] && ENV['HTTP_PASS']
      use Rack::Auth::Basic, "Restricted Area" do |username, password|
        [username, password] == [ENV['HTTP_USER'], ENV['HTTP_PASS']]
      end
    end
  end
  # When Skitch uploads via WebDAV, it uses
  # the file name as the URL and includes the
  # image in the body.
  put '/:name' do
    retries = 0
    begin
      content_type = MIME::Types.type_for(params[:name]).first.content_type
      file = bucket.files.create(key: params[:name], public: true, body: request.body.read, content_type: content_type)
      puts "Uploaded file #{params[:name]} to SDSC"
      redirect "http://#{ENV['BUCKET']}/#{params[:name]}", 201
    rescue => e
      puts "Error uploading file #{params[:name]} to SDSC: #{e.message}"
      if e.message =~ /Broken pipe/ && retries < 5
        retries += 1
        retry
      end

      500
    end
  end

  delete '/:name' do
    file = bucket.files.get(params[:name])
    file.destroy
  end

  def bucket
    sdsc = Fog::Storage.new(provider: 'Rackspace', rackspace_api_key: ENV['RACKSPACE_API_KEY'], rackspace_username: ENV['RACKSPACE_USERNAME'], rackspace_auth_url: ENV['RACKSPACE_AUTH_URL'])
    sdsc.directories.get(ENV['BUCKET'])
  end
end
