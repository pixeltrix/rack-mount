require 'test_helper'

class RegexpWithNamedGroupsTest < Test::Unit::TestCase
  RegexpWithNamedGroups = Rack::Mount::RegexpWithNamedGroups

  def test_normal_regexp
    re = RegexpWithNamedGroups.new(%r{/foo})
    assert_equal(%r{/foo}, re.to_regexp)
    assert_equal({}, re.named_captures)
    assert_equal([], re.names)
  end

  def test_regexp_with_unnamed_captures
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)/([0-9]+)})
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({}, re.named_captures)
    assert_equal([], re.names)
  end

  def test_regexp_with_array_of_captures_string_names
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)/([0-9]+)}, ['name', 'id'])
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
    assert_equal(['name', 'id'], re.names)
  end

  def test_regexp_with_array_of_captures_symbol_names
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)/([0-9]+)}, [:name, :id])
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
    assert_equal(['name', 'id'], re.names)
  end

  def test_regexp_with_hash_of_captures_string_names
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)/([0-9]+)}, {'name' => 1, 'id' => 2})
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
    assert_equal(['name', 'id'], re.names)
  end

  def test_regexp_with_hash_of_captures_symbol_names
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)/([0-9]+)}, {:name => 1, :id => 2})
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
    assert_equal(['name', 'id'], re.names)
  end

  def test_regexp_with_nested_captures_with_array_of_name_captures
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)(/([0-9]+))?}, ['name', nil, 'id'])
    assert_equal(%r{/foo/([a-z]+)(/([0-9]+))?}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [3]}, re.named_captures)
    assert_equal(['name', nil, 'id'], re.names)
  end

  def test_regexp_with_nested_captures_with_hash_of_name_captures
    re = RegexpWithNamedGroups.new(%r{/foo/([a-z]+)(/([0-9]+))?}, {'name' => 1, 'id' => 3})
    assert_equal(%r{/foo/([a-z]+)(/([0-9]+))?}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [3]}, re.named_captures)
    assert_equal(['name', nil, 'id'], re.names)
  end

  def test_regexp_with_comment_captures
    re = RegexpWithNamedGroups.new(%r{/foo/(?:<name>[a-z]+)/(?:<id>[0-9]+)})
    assert_equal(%r{/foo/([a-z]+)/([0-9]+)}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
    assert_equal(['name', 'id'], re.names)
  end

  def test_regexp_with_nested_comment_captures
    re = RegexpWithNamedGroups.new(%r{/foo/(?:<name>[a-z]+)(/(?:<id>[0-9]+))?})
    assert_equal(%r{/foo/([a-z]+)(/([0-9]+))?}, re.to_regexp)
    assert_equal({'name' => [1], 'id' => [3]}, re.named_captures)
    assert_equal(['name', nil, 'id'], re.names)
  end

  if RUBY_VERSION >= '1.9'
    def test_regexp_with_named_regexp_groups
      re = eval('%r{/foo/(?<name>[a-z]+)/(?<id>[0-9]+)}')
      re = RegexpWithNamedGroups.new(re)
      assert_equal(re, re.to_regexp)
      assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
      assert_equal(['name', 'id'], re.names)
    end

    def test_regexp_with_nested_named_regexp_groups
      re = eval('%r{/foo/(?<name>[a-z]+)(/(?<id>[0-9]+))?}')
      re = RegexpWithNamedGroups.new(re)
      assert_equal(re, re.to_regexp)
      assert_equal({'name' => [1], 'id' => [2]}, re.named_captures)
      assert_equal(['name', 'id'], re.names)
    end
  end
end

class SegmentStringTest < Test::Unit::TestCase
  include Rack::Mount::Utils

  def test_simple_string
    re = convert_segment_string_to_regexp("/foo")
    assert_equal %r{^/foo$}, re.to_regexp
    assert_equal [], re.names
    assert_equal({}, re.named_captures)
  end

  def test_another_simple_string
    re = convert_segment_string_to_regexp("/people/show/1")
    assert_equal %r{^/people/show/1$}, re.to_regexp
    assert_equal [], re.names
    assert_equal({}, re.named_captures)
  end

  def test_dynamic_segments
    re = convert_segment_string_to_regexp("/foo/:action/:id")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/foo/(?<action>[^/.?]+)/(?<id>[^/.?]+)$}"), re.to_regexp
    else
      assert_equal %r{^/foo/([^/.?]+)/([^/.?]+)$}, re.to_regexp
    end
    assert_equal ['action', 'id'], re.names
    assert_equal({ 'action' => [1], 'id' => [2] }, re.named_captures)
  end

  def test_requirements
    re = convert_segment_string_to_regexp("/foo/:action/:id", :action => /bar|baz/, :id => /[a-z0-9]+/)

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/foo/(?<action>bar|baz)/(?<id>[a-z0-9]+)$}"), re.to_regexp
    else
      assert_equal %r{^/foo/(bar|baz)/([a-z0-9]+)$}, re.to_regexp
    end
    assert_equal ['action', 'id'], re.names
    assert_equal({ 'action' => [1], 'id' => [2] }, re.named_captures)
  end

  def test_period_separator
    re = convert_segment_string_to_regexp("/foo/:id.:format")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/foo/(?<id>[^/.?]+)\\.(?<format>[^/.?]+)$}"), re.to_regexp
    else
      assert_equal %r{^/foo/([^/.?]+)\.([^/.?]+)$}, re.to_regexp
    end
    assert_equal ['id', 'format'], re.names
    assert_equal({ 'id' => [1], 'format' => [2] }, re.named_captures)
  end

  def test_optional_segment
    re = convert_segment_string_to_regexp("/people(.:format)")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/people(\\.(?<format>[^/.?]+))?$}"), re.to_regexp
      assert_equal ['format'], re.names
      assert_equal({ 'format' => [1] }, re.named_captures)
    else
      assert_equal %r{^/people(\.([^/.?]+))?$}, re.to_regexp
      assert_equal [nil, 'format'], re.names
      assert_equal({ 'format' => [2] }, re.named_captures)
    end
  end

  def test_dynamic_and_optional_segment
    re = convert_segment_string_to_regexp("/people/:id(.:format)")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/people/(?<id>[^/.?]+)(\\.(?<format>[^/.?]+))?$}"), re.to_regexp
      assert_equal ['id', 'format'], re.names
      assert_equal({ 'id' => [1], 'format' => [2] }, re.named_captures)
    else
      assert_equal %r{^/people/([^/.?]+)(\.([^/.?]+))?$}, re.to_regexp
      assert_equal ['id', nil, 'format'], re.names
      assert_equal({ 'id' => [1], 'format' => [3] }, re.named_captures)
    end
  end

  def test_nested_optional_segment
    re = convert_segment_string_to_regexp("/:controller(/:action(/:id(.:format)))")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/(?<controller>[^/.?]+)(/(?<action>[^/.?]+)(/(?<id>[^/.?]+)(\\.(?<format>[^/.?]+))?)?)?$}"), re.to_regexp
      assert_equal ['controller', 'action', 'id', 'format'], re.names
      assert_equal({ 'controller' => [1], 'action' => [2], 'id' => [3], 'format' => [4] }, re.named_captures)
    else
      assert_equal %r{^/([^/.?]+)(/([^/.?]+)(/([^/.?]+)(\.([^/.?]+))?)?)?$}, re.to_regexp
      assert_equal ['controller', nil, 'action', nil, 'id', nil, 'format'], re.names
      assert_equal({ 'controller' => [1], 'action' => [3], 'id' => [5], 'format' => [7] }, re.named_captures)
    end
  end

  def test_glob
    re = convert_segment_string_to_regexp("/files/*files")

    if RUBY_VERSION >= '1.9'
      assert_equal eval("%r{^/files/(?<files>.*)$}"), re.to_regexp
    else
      assert_equal %r{^/files/(.*)$}, re.to_regexp
    end

    assert_equal ['files'], re.names
    assert_equal({ 'files' => [1] }, re.named_captures)
  end
end

class RegexpSegmentExtractTest < Test::Unit::TestCase
  include Rack::Mount::Utils

  def test_simple_regexp
    re = %r{^/foo$}
    assert_equal ["foo"], extract_static_segments(re)
  end

  def test_another_simple_regexp
    re = %r{^/people/show/1$}
    assert_equal ["people", "show", "1"], extract_static_segments(re)
  end

  def test_regexp_with_hash_of_requirements
    re = %r{^/foo/(bar|baz)/([a-z0-9]+)}
    assert_equal ["foo"], extract_static_segments(re)
  end

  def test_regexp_with_period_separator
    re = %r{^/foo\.([a-z]+)$}
    assert_equal ["foo"], extract_static_segments(re)
  end

  if RUBY_VERSION >= '1.9'
    def test_regexp_with_named_regexp_groups
      re = eval('%r{/(?<controller>[a-z0-9]+)/(?<action>[a-z0-9]+)/(?<id>[0-9]+)}')
      assert_equal [], extract_static_segments(re)
    end
  end
end
