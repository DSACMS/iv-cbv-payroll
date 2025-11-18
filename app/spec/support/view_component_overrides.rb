module ViewComponentOverrides
  # ViewComponent's `render_inline` is broken: it was inadvertently updated to
  # use a Nokogiri parser that will try to fix invalid HTML, such as by
  # removing an outer <td> tag unless surrounded by a <tr>. This is a
  # probably-unintentional regression in the 4.0 release.
  #
  # A fix is pending upstream. Let's override the implementation with the fixed
  # version until this PR is merged and released:
  # https://github.com/ViewComponent/view_component/pull/2426
  #
  # After that PR is merged, this file should be able to be deleted.
  def render_inline(component, **args, &block)
    raise <<~PSA if ViewComponent::VERSION::MAJOR > 4 || ViewComponent::VERSION::MINOR > 1
      Check whether the monkeypatch for `render_inline` is still necessary.
      If the PR has been merged, delete the overrides.
      Otherwise, bump the version in this monkeypatch message.
    PSA

    @page = nil
    @rendered_content = vc_test_view_context.render(component, args, &block)

    fragment = Nokogiri::HTML5.fragment(@rendered_content, context: "template")
    @vc_test_view_context = nil
    fragment
  end
end
