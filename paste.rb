%w[bundler/setup sinatra/base haml sequel coderay digest].each {|r| require r }

DB = Sequel.connect("sqlite://paste.db")

unless DB.tables.include?(:paste)
  DB.create_table :paste do
    column :hash, :string
    column :content, :bytea
    column :public, :boolean
  end
end

LANGS = [:text, :c, :cpp, :css, :diff, :erb, :haml, :html, :java, :javascript, :json, :php, :python, :ruby, :sql, :xml, :yaml]

class App < Sinatra::Base
self.inline_templates = __FILE__

get '/' do
  @langs = LANGS
  haml :index
end

post '/new' do
  hash = Digest::SHA1.hexdigest(params[:content])
  DB[:paste].insert(hash: hash, content: params[:content], public: (params[:public] && params[:public] == 'true'))  unless DB[:paste][hash: hash]
  redirect to("/p/#{hash}?hl=#{params[:lang]}")
end

get '/search' do
  if @term = params[:q]
    @pastes = DB[:paste].where(public: true).filter(:content.like("%#{@term}%"))
  end
  haml :search
end

get '/p/:id' do |id|
  @paste = DB[:paste][hash: id]
  haml :paste
end

get '/raw/:id' do |id|
  content_type 'text/plain'
  @paste = DB[:paste][hash: id][:content]
end

end

Rack::Handler::Thin.run(App.new, :Port => (ARGV[0] || 4000))

__END__

@@ layout
!!!
%html
  %head
    %title Paste
    :css
      .CodeRay { border: 1px solid #999 }
      .CodeRay td { padding: 5px; }
      pre { margin: 0px }
  %body= yield

@@ index
%h1 Paste
%form{action: "/new", method: "POST"}
  %textarea{name: "content", rows: 30, style: "width: 100%" }
  %br/
  %select{name: "lang"}
    - @langs.each do |lang|
      %option{name: lang}= lang
  %input{type: "checkbox", id: "public", name: "public", value: "true", checked: true}
  %label{for: "public"} Public?
  %input{type: "submit", value: "Paste"}

@@ paste
%h1= (@paste[:public] ? "Public" : "Private") + " paste " + @paste[:hash]
= CodeRay.scan(@paste[:content], params[:hl]).div(line_numbers: :table)
%a{href: "/raw/#{@paste[:hash]}"} Raw Format
|
%a{href: "/"} New Paste
|
%a{href: "/search"} Search

@@ search
%h1 Search
%form{action: "/search", method: "GET"}
  %input{type: "text", name: "q"}
  %input{type: "submit", value: "Search"}
%hr
- if @pastes && @pastes.any?
  %h3 Pastes matching "#{@term}"
  %ul
    - @pastes.each do |paste|
      %li
        %a{href: "/p/" + paste[:hash]}= paste[:hash]
