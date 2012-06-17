['sinatra', 'haml', 'sequel', 'coderay', 'ostruct', 'digest'].each {|r| require r }

DB = Sequel.connect("sqlite://paste.db")

unless DB.tables.include?(:paste)
  DB.create_table :paste do
    column :hash, :string
    column :lang, :string
    column :content, :bytea
    column :public, :boolean
  end
end

LANGS = [:none, :c, :clojure, :cpp, :css, :delphi, :diff, :erb, :groovy, :haml, :html,
  :java, :javascript, :json, :php, :python, :ruby, :sql, :xml, :yaml]

VIEWS = {
  :layout => <<-EOS,
!!!
%html
  %head
    %title Paste
    :css
      .CodeRay { border: 1px solid #999 }
      .CodeRay td { padding: 5px; }
      pre { margin: 0px }
  %body
    = content
EOS
  :root => <<-EOS,
%h1 Paste
%form{action: "/new", method: "POST"}
  %textarea{name: "content", rows: 50, style: "width: 100%" }
  %br/
  %select{name: "lang"}
    - langs.each do |lang|
      %option{name: lang}= lang
  %input{type: "checkbox", id: "public", name: "public", value: "true", checked: true}
  %label{for: "public"} Public?
  %input{type: "submit", value: "Paste"}
EOS
  :paste => <<-EOS,
%h1= (paste[:public] ? "Public" : "Private") + " paste " + paste[:hash]
= CodeRay.scan(paste[:content], paste[:lang]).div(line_numbers: :table)
%a{href: "/"} New Paste
EOS
  :search => <<-EOS,
%h1 Search
%form{action: "/search", method: "GET"}
  %input{type: "text", name: "q"}
  %input{type: "submit", value: "Search"}
%hr
- if pastes && pastes.any?
  %h3 Pastes matching \#{term}
  %ul
    - pastes.each do |paste|
      %li
        %a{href: "/" + paste[:hash]}= paste[:hash]
EOS
}

def render_view template, data
  Haml::Engine.new(template).render(OpenStruct.new(data))
end

def view name, data = {}
  content = render_view VIEWS[name.to_sym], data
  render_view VIEWS[:layout], content: content
end

get '/' do
  view :root, langs: LANGS
end

post '/new' do
  hash = Digest::SHA1.hexdigest(params[:content])
  DB[:paste].insert(hash: hash, content: params[:content], lang: params[:lang],
    public: (params[:public] && params[:public] == 'true'))
  redirect to("/#{hash}")
end

get '/search' do
  if term = params[:q]
    pastes = DB[:paste].where(public: true).filter(:content.like("%#{term}%"))
  end
  view :search, pastes: pastes, term: term
end

get '/:id' do |id|
  paste = DB[:paste][:hash => id]
  view :paste, paste: paste
end
