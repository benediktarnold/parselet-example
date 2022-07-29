require 'parslet'

class QueryParser < Parslet::Parser
  rule(:slop) { (str('~') >> match('[0-9]').repeat(1)).as(:slop) }

  rule(:term) { match('[^\s\*"]').repeat(1).as(:term) }
  rule(:post_wildcard) { (term >> str('*')).as(:post_wildcard) }
  rule(:quote) { str('"') }
  rule(:bool) { (str('OR') | str('or') | str('AND') | str('and')).as(:bool) }
  rule(:operator) { (str('+') | str('-')).as(:operator) }

  rule(:phrase) do
    (quote >> ((post_wildcard | term) >> space.maybe).repeat >> quote >> slop.maybe).as(:phrase)
  end
  rule(:clause) { (operator.maybe >> (phrase | term)).as(:clause) }
  rule(:space) { match('\s').repeat(1) }
  rule(:query) { (clause >> space.maybe).repeat.as(:query) }
  root(:query)
end

$dict = { 'foo' => %w[foobar foolish] }

def join(p, slop = "")
  '("' + p.map {|terms| terms.join(" ")}.join("\"#{slop} OR \"") + "\"#{slop})"
end


class QueryTransformer < Parslet::Transform
  rule(term: simple(:term)) { term.to_s }
  rule(clause: simple(:clause)) {clause.to_s}
  rule(post_wildcard: simple(:pterm)) { $dict[pterm] }
  rule(phrase: subtree(:wp)) do
    *items, last = wp
    wp = items.map {|item| 
      Array(item)
    }
    p = wp[0].product(*wp[1..-1])
    last.is_a?(Hash) ? join(p, last[:slop].to_s) : join(p.product(Array(last)))
  end
  rule(query: sequence(:parts)) { parts.join(" ")}
end

input = '"something foo* bar"~10 OR "foo* fi" OR "this that" OR simpleterm OR (this AND "foo* that")'
puts("Input: "+input)
tree = QueryParser.new.parse(input)
puts('AST: ' + tree.inspect)
query = QueryTransformer.new.apply(tree)
puts('query: ' + query)
# puts(QueryParser.new.parse('foo OR bar'))
