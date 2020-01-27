require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "google/cloud/spanner"
require "active_record"
require "spanner_activerecord"

module MiniTest::Assertions
  def assert_sql_equal exp, act, msg = nil
    exp_sqls = Array(exp).map do |obj|
      obj.respond_to?(:sql) ? obj.sql : obj
    end

    act_sqls = Array(act).map do |obj|
      obj.respond_to?(:sql) ? obj.sql : obj
    end

    act_sqls.each_with_index do |act_sql, i|
      assert_equal exp_sqls[i].to_s.split, act_sql.to_s.split, msg
    end
  end
end

module MiniTest::Expectations
  infect_an_assertion :assert_sql_equal, :must_sql_equal
end

class MockSpannerActiveRecord < Minitest::Spec
  let(:project_id) { "test-project" }
  let(:instance_id) { "test-instance" }
  let(:database_id) { "test-database" }
  let(:credentials) { "test-credentials-file" }
  let(:connection) {
    SpannerActiverecord::Connection.new(
      project_id,
      instance_id,
      database_id,
      init_client: true
    )
  }

  after do
    MockGoogleSpanner.mocked_result&.clear
    MockGoogleSpanner.last_executed_sqls&.clear
  end

  register_spec_type(self) do |desc, *addl|
    addl.include? :mock_spanner_activerecord
  end

  def mocked_result result = nil, &block
    MockGoogleSpanner.mocked_result = block || result
  end

  def last_executed_sqls
    MockGoogleSpanner.last_executed_sqls
  end

  def last_executed_sql
    MockGoogleSpanner.last_executed_sqls.last
  end
end

module MockGoogleSpanner
  def self.included base
    base.instance_eval do
      alias orig_spanner spanner
      def spanner *args
        MockProject.new(*args)
      end
    end
  end

  def self.mocked_result= result
    @mocked_result ||= []
    @mocked_result << result
  end

  def self.mocked_result
    return unless @mocked_result
    result = @mocked_result.pop
    return result.call if result&.is_a? Proc
    result
  end

  def self.last_executed_sqls sql = nil
    if sql
      @last_executed_sqls ||= []
      @last_executed_sqls << sql
    end
    @last_executed_sqls
  end

  class MockProject
    def initialize *args
      @connection_args = args
    end

    def project_id
      @connection_args.first
    end

    def create_database instance_id, database_id
      MockJob.execute request: {
        instance_id: instance_id, database_id: database_id
      }
    end

    def database *args
      MockClient.new(*args)
    end

    def client *args
      MockClient.new(*args)
    end
  end

  class MockClient
    attr_reader :connection_args

    def initialize *args
      @connection_args = args
    end

    def close
      MockGoogleSpanner.mocked_result
    end

    def reset
      MockGoogleSpanner.mocked_result
    end

    def execute_query sql, params: nil, types: nil, single_use: nil
      MockGoogleSpanner.last_executed_sqls OpenStruct.new(
        sql: sql, options: {
          params: params, types: types, single_use: single_use
        }
      )
      OpenStruct.new(rows: MockGoogleSpanner.mocked_result || [])
    end
    alias execute execute_query

    def update statements: nil, operation_id: nil
      MockGoogleSpanner.last_executed_sqls \
        OpenStruct.new sql: statements, options: { operation_id: operation_id }
      MockJob.execute statements
    end

    def last_executed_statements
      @last_query&.sql
    end
  end

  class MockJob
    attr_accessor :error, :request, :result

    def initialize error: nil, done: true, request: nil, result: nil
      @error = error
      @done = done
      @result = result
      @request = request
    end

    def wait_until_done!
      true
    end

    def error?
      !@error.nil?
    end

    def done?
      @done
    end

    def method_missing m, *args, &block
      @result
    end

    def self.execute request
      job = new request: request

      begin
        job.result = MockGoogleSpanner.mocked_result
      rescue StandardError => e
        job.error = e
      end

      job
    end
  end
end

require "google-cloud-spanner"
Google::Cloud.send :include, MockGoogleSpanner
