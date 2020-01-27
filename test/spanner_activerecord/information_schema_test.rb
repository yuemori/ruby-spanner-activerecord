require "test_helper"

describe SpannerActiverecord::InformationSchema, :mock_spanner_activerecord  do
  let(:info_schema) { SpannerActiverecord::InformationSchema.new connection }
  let(:tables_schema_result) {
    [
      {
        "TABLE_CATALOG" => "",
        "TABLE_SCHEMA" => "",
        "TABLE_NAME" => "accounts",
        "PARENT_TABLE_NAME" => nil,
        "ON_DELETE_ACTION" => nil,
        "SPANNER_STATE" => "COMMITTED"
      }
    ]
  }

  describe "#new" do
    it "create an instance" do
      info_schema = SpannerActiverecord::InformationSchema.new connection
      info_schema.must_be_instance_of SpannerActiverecord::InformationSchema
    end
  end

  describe "#tables" do
    it "list all tables" do
      info_schema.tables

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.tables WHERE table_schema=''"
      )
    end

    it "list all tables with columns view" do
      mocked_result tables_schema_result
      info_schema.tables view: :columns

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'"
        ]
      )
    end

    it "list all tables with indexes view" do
      mocked_result tables_schema_result
      info_schema.tables view: :indexes

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end

    it "list all tables with full view" do
      mocked_result tables_schema_result
      info_schema.tables view: :full

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema=''",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end
  end

  describe "#table" do
    it "get table" do
      result = info_schema.table "accounts"

      assert_sql_equal(
        last_executed_sql,
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'"
      )
    end

    it "get table with columns view" do
      mocked_result tables_schema_result
      result = info_schema.table "accounts", view: :columns

      assert_sql_equal(
        last_executed_sqls,
        "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
        "SELECT * FROM information_schema.columns WHERE table_name='accounts'"
      )
    end

    it "get table with indexes view" do
      mocked_result tables_schema_result
      result = info_schema.table "accounts", view: :indexes

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end

    it "get table with full view" do
      mocked_result tables_schema_result
      info_schema.table "accounts", view: :full

      assert_sql_equal(
        last_executed_sqls,
        [
          "SELECT * FROM information_schema.tables WHERE table_schema='' AND table_name='accounts'",
          "SELECT * FROM information_schema.columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.index_columns WHERE table_name='accounts'",
          "SELECT * FROM information_schema.indexes WHERE table_name='accounts'"
        ]
      )
    end
  end
end
