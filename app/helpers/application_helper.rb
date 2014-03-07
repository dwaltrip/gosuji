module ApplicationHelper
  def javascript(*files)
    content_for(:javascript_tags) { javascript_include_tag(*files) }
  end
end
