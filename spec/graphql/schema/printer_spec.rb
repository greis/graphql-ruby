require "spec_helper"

describe GraphQL::Schema::Printer do
  let(:schema) {
    node_type = GraphQL::InterfaceType.define do
      name "Node"

      field :id, !types.ID
    end

    choice_type = GraphQL::EnumType.define do
      name "Choice"

      value "FOO"
      value "BAR"
      value "BAZ", deprecation_reason: 'Use "BAR".'
      value "WOZ", deprecation_reason: GraphQL::Directive::DEFAULT_DEPRECATION_REASON
    end

    sub_input_type = GraphQL::InputObjectType.define do
      name "Sub"
      input_field :string, types.String
    end

    variant_input_type = GraphQL::InputObjectType.define do
      name "Varied"
      input_field :id, types.ID
      input_field :int, types.Int
      input_field :float, types.Float
      input_field :bool, types.Boolean
      input_field :enum, choice_type
      input_field :sub, types[sub_input_type]
    end

    comment_type = GraphQL::ObjectType.define do
      name "Comment"
      description "A blog comment"
      interfaces [node_type]

      field :id, !types.ID
    end

    post_type = GraphQL::ObjectType.define do
      name "Post"
      description "A blog post"

      field :id, !types.ID
      field :title, !types.String
      field :body, !types.String
      field :comments, types[!comment_type]
      field :comments_count, !types.Int, deprecation_reason: 'Use "comments".'
    end

    query_root = GraphQL::ObjectType.define do
      name "Query"
      description "The query root of this schema"

      field :post do
        type post_type
        argument :id, !types.ID
        argument :varied, variant_input_type, default_value: { id: "123", int: 234, float: 2.3, enum: "FOO", sub: [{ string: "str" }] }
        resolve -> (obj, args, ctx) { Post.find(args["id"]) }
      end
    end

    GraphQL::Schema.define(query: query_root)
  }

  describe ".print_introspection_schema" do
    it "returns the schema as a string for the introspection types" do
      expected = <<SCHEMA
schema {
  query: Query
}

directive @skip(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

directive @include(if: Boolean!) on FIELD | FRAGMENT_SPREAD | INLINE_FRAGMENT

directive @deprecated(reason: String! = \"No longer supported\") on FIELD_DEFINITION | ENUM_VALUE

type __Directive {
  name: String!
  description: String
  args: [__InputValue!]!
  locations: [__DirectiveLocation!]!
  onOperation: Boolean! @deprecated(reason: \"Moved to 'locations' field\")
  onFragment: Boolean! @deprecated(reason: \"Moved to 'locations' field\")
  onField: Boolean! @deprecated(reason: \"Moved to 'locations' field\")
}

enum __DirectiveLocation {
  QUERY
  MUTATION
  SUBSCRIPTION
  FIELD
  FIELD_DEFINITION
  FRAGMENT_DEFINITION
  FRAGMENT_SPREAD
  INLINE_FRAGMENT
  ENUM_VALUE
}

type __EnumValue {
  name: String!
  description: String
  deprecationReason: String
  isDeprecated: Boolean!
}

type __Field {
  name: String!
  description: String
  type: __Type!
  isDeprecated: Boolean!
  args: [__InputValue!]!
  deprecationReason: String
}

type __InputValue {
  name: String!
  description: String
  type: __Type!
  defaultValue: String
}

type __Schema {
  types: [__Type!]!
  directives: [__Directive!]!
  queryType: __Type!
  mutationType: __Type
  subscriptionType: __Type
}

type __Type {
  name: String
  description: String
  kind: __TypeKind!
  fields(includeDeprecated: Boolean = false): [__Field!]
  ofType: __Type
  inputFields: [__InputValue!]
  possibleTypes: [__Type!]
  enumValues(includeDeprecated: Boolean = false): [__EnumValue!]
  interfaces: [__Type!]
}

enum __TypeKind {
  SCALAR
  OBJECT
  INTERFACE
  UNION
  ENUM
  INPUT_OBJECT
  LIST
  NON_NULL
}
SCHEMA
      assert_equal expected.chomp, GraphQL::Schema::Printer.print_introspection_schema
    end
  end

  describe ".print_schema" do
    it "returns the schema as a string for the defined types" do
      expected = <<SCHEMA
schema {
  query: Query
}

enum Choice {
  FOO
  BAR
  BAZ @deprecated(reason: "Use \\\"BAR\\\".")
  WOZ @deprecated
}

type Comment implements Node {
  id: ID!
}

interface Node {
  id: ID!
}

type Post {
  id: ID!
  title: String!
  body: String!
  comments: [Comment!]
  comments_count: Int! @deprecated(reason: \"Use \\\"comments\\\".\")
}

type Query {
  post(id: ID!, varied: Varied = {id: \"123\", int: 234, float: 2.3, enum: FOO, sub: [{string: \"str\"}]}): Post
}

input Sub {
  string: String
}

input Varied {
  id: ID
  int: Int
  float: Float
  bool: Boolean
  enum: Choice
  sub: [Sub]
}
SCHEMA
      assert_equal expected.chomp, GraphQL::Schema::Printer.print_schema(schema)
    end
  end
end
