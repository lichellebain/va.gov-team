# frozen_string_literal: true

require 'rails_helper'

describe Sidekiq::ErrorTag do
  # rubocop:disable Style/GlobalVars
  class TestJob
    include Sidekiq::Worker

    def perform
      $named_tags = Sidekiq.logger.named_tags
    end
  end

  before do
    req = ActionDispatch::TestRequest.create('HTTP_USER_AGENT' => 'banana', 'REMOTE_ADDR' => '99.99.99.99')
    req.request_id = '123'
    allow_any_instance_of(ApplicationController).to receive(:request).and_return(req)

    ApplicationController.new.send(:set_tags_and_extra_context)
  end

  it 'tags raven before each sidekiq job' do
    TestJob.perform_async
    expect(Raven).to receive(:tags_context).with(job: 'TestJob', request_id: '123')
    expect(Raven).to receive(:user_context).with(id: 'N/A', remote_ip: '99.99.99.99', user_agent: 'banana')
    TestJob.drain
  end

  it 'adds controller metadata to semantic logger named tags' do
    Sidekiq::Testing.inline! do
      TestJob.perform_async
      expect($named_tags[:request_id]).to eq('123')
      expect($named_tags[:remote_ip]).to eq('99.99.99.99')
      expect($named_tags[:user_agent]).to eq('banana')
      expect($named_tags[:user_uuid]).to eq('N/A')
    end
  end
  # rubocop:enable Style/GlobalVars
end
