require File.expand_path('../spec_helper.rb', __FILE__)

def destination_response
  sleep 1
  $destination_responses.last
end

describe Rack::RequestReplication::Forwarder do
  include Rack::Test::Methods

  let(:app) { TestApp.new }
  let(:forwarder) { Rack::RequestReplication::Forwarder.new(app, options) }
  let(:options) do
    {
      port: destination_port
    }
  end
  let(:request) do
    OpenStruct.new({
      request_method: request_method,
      scheme: scheme,
      port: source_port,
      path: path
    })
  end

  let(:request_method) { 'GET' }
  let(:scheme) { 'http' }
  let(:source_port) { 80 }
  let(:destination_port) { 3000 }
  let(:host) { 'localhost' }
  let(:path) { '/' }

  describe 'a GET request' do
    before { get '/' }

    it { expect(last_response.body).to eq destination_response }
  end

  describe 'a POST request' do
    it 'posts correct parameters along parameters' do
      post '/', foo: 'bar'
      expect(destination_response).to eq "{\"foo\"=>\"bar\"}"
    end

    it "works with nested parameters" do
      post '/', foo: { bar: 'buz' }
      expect(destination_response).to eq "{\"foo\"=>{\"bar\"=>\"buz\"}}"
    end
  end

  describe 'a PUT request' do
    it 'posts correct parameters along parameters' do
      put '/', foo: { bar: 'buz' }
      expect(destination_response).to eq "{\"foo\"=>{\"bar\"=>\"buz\"}}"
    end
  end

  describe 'a PATCH request' do
    it 'posts correct parameters along parameters' do
      patch '/', foo: { bar: 'buz' }
      expect(destination_response).to eq "{\"foo\"=>{\"bar\"=>\"buz\"}}"
    end
  end

  describe 'a DELETE request' do
    before { delete '/' }

    it { expect(last_response.body).to eq destination_response }
  end

  describe '#port_matches_scheme?' do
    subject { forwarder.port_matches_scheme? request }
    it { is_expected.to be false }

    context 'default port' do
      let(:destination_port) { 80 }
      it { is_expected.to be true }
    end
  end
end
