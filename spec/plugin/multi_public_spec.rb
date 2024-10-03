require_relative "../spec_helper"

describe "multi_public plugin" do 
  it "adds r.multi_public for serving static files from public folder" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views', :b => 'spec'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    status("/about/_test.erb\0").must_equal 404
    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/foo/.././/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "respects the application's :root option" do
    app(:bare) do
      opts[:root] = File.expand_path('../../', __FILE__)
      plugin :multi_public, :a => 'views', :b => '.'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "appends to directories if loaded a second time" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views'
      plugin :multi_public, :b => 'spec'

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/foo/.././/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
  end

  it "support headers and default mime types per directory" do
    app(:bare) do
      plugin :multi_public,
        :a => ['spec/views', {'x-foo' => 'bar'}, nil],
        :b => ['spec', nil, 'foo/bar']

      route do |r|
        r.on 'static' do
          r.multi_public(:b)
        end

        r.multi_public(:a)
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header(RodaResponseHeaders::CONTENT_TYPE, '/about/_test.erb').must_equal 'text/plain'
    header('x-foo', '/about/_test.erb').must_equal 'bar'

    body('/static/views/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header(RodaResponseHeaders::CONTENT_TYPE, '/static/views/about/_test.erb').must_equal 'foo/bar'
    header('x-foo', '/static/views/about/_test.erb').must_be_nil
  end


  it "loads the public plugin with the given options" do
    app(:bare) do
      plugin :multi_public, {}, :root=>'spec/views', :headers=>{'x-foo' => 'bar'}, :default_mime=>'foo/bar'

      route do |r|
        r.public
      end
    end

    body('/about/_test.erb').must_equal File.read('spec/views/about/_test.erb')
    header(RodaResponseHeaders::CONTENT_TYPE, '/about/_test.erb').must_equal 'foo/bar'
    header('x-foo', '/about/_test.erb').must_equal 'bar'
  end

  types = [
    [:gzip, 'gzip', '.gz'],
    [:brotli, 'br', '.br'],
    [:zstd, 'zstd', '.zst'],
  ]
  types.each do  |type, accept, ext|
    [true, false].each do |use_encodings|
      opts = {}
      if use_encodings
        opts[:encodings] = [[accept, ext]]
        opts[:encodings] << ['zstd', '.zst'] if type == :brotli
        opts[:encodings] << ['gzip', '.gz'] unless type == :gzip
      else
        opts[:gzip] = opts[type] = true
      end

      it "handles serving files with #{ext} extension if client supports accepts #{accept} encoding when :encodings is #{'not ' unless use_encodings}given" do
        app(:bare) do
          plugin :multi_public, {:a => 'spec/views', :b => 'spec'}, opts

          route do |r|
            r.on 'static' do
              r.multi_public(:b)
            end

            r.multi_public(:a)
          end
        end

        ['', '/static/views'].each do |prefix|
          body("#{prefix}/about/_test.erb").must_equal File.read('spec/views/about/_test.erb')
          header(RodaResponseHeaders::CONTENT_ENCODING, '/about/_test.erb').must_be_nil

          body("#{prefix}/about.erb").must_equal File.read('spec/views/about.erb')
          header(RodaResponseHeaders::CONTENT_ENCODING, '/about.erb').must_be_nil
          
          accept_encoding = "deflate,#{' gzip,' unless type == :gzip} #{accept}"

          body("#{prefix}/about/_test.erb", 'HTTP_ACCEPT_ENCODING'=>accept_encoding).must_equal File.binread("spec/views/about/_test.erb.gz")
          h = req("#{prefix}/about/_test.erb", 'HTTP_ACCEPT_ENCODING'=>accept_encoding)[1]
          h[RodaResponseHeaders::CONTENT_ENCODING].must_equal 'gzip'
          h[RodaResponseHeaders::CONTENT_TYPE].must_equal 'text/plain'

          body("#{prefix}/about/_test2.css", 'HTTP_ACCEPT_ENCODING'=>accept_encoding).must_equal File.binread("spec/views/about/_test2.css#{ext}")
          h = req("#{prefix}/about/_test2.css", 'HTTP_ACCEPT_ENCODING'=>accept_encoding)[1]
          h[RodaResponseHeaders::CONTENT_ENCODING].must_equal accept
          h[RodaResponseHeaders::CONTENT_TYPE].must_equal 'text/css'

          s, h, b = req("#{prefix}/about/_test2.css", 'HTTP_IF_MODIFIED_SINCE'=>h[RodaResponseHeaders::LAST_MODIFIED], 'HTTP_ACCEPT_ENCODING'=>accept_encoding)
          s.must_equal 304
          h[RodaResponseHeaders::CONTENT_ENCODING].must_be_nil
          h[RodaResponseHeaders::CONTENT_TYPE].must_be_nil
          b.must_equal []
        end
      end
    end
  end

  it "does not handle non-GET requests" do
    app(:bare) do
      plugin :multi_public, :a => 'spec/views'

      route do |r|
        r.multi_public(:a)
      end
    end

    status("/about/_test.erb", "REQUEST_METHOD"=>"POST").must_equal 404
  end
end

