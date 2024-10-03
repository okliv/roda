require_relative "../spec_helper"

describe "custom_block_results plugin" do
  before do
    app(:custom_block_results) do
      :sym
    end
  end

  it "should handle classes" do
    2.times do
      @app.handle_block_result(Symbol) do |s|
        "v#{s}"
      end
      body.must_equal "vsym"
    end
  end

  it "should handle other objects supporting ===" do
    @app.handle_block_result(/sy/) do |s|
      "x#{s}"
    end
    body.must_equal "xsym"
  end

  it "should work in subclasses" do
    @app = Class.new(@app)
    @app.handle_block_result(/sy/) do |s|
      "x#{s}"
    end
    body.must_equal "xsym"
  end

  it "should handle frozen applications" do
    @app.freeze
    proc do
      @app.handle_block_result(Symbol){|s| }
    end.must_raise
  end

  it "should still raise for unhandled types" do
    proc{body}.must_raise Roda::RodaError
  end
end
