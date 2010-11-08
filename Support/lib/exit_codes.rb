module TextMate
  module_function

  def exit_discard
    exit 200
  end

  def exit_replace_text(out = nil)
    print out if out
    exit 201
  end

  def exit_replace_document(out = nil)
    print out if out
    exit 202
  end

  def exit_insert_text(out = nil)
    print out if out
    exit 203
  end

  def exit_insert_snippet(out = nil)
    print out if out
    exit 204
  end

  def exit_show_html(out = nil)
    print out if out
    exit 205
  end

  def exit_show_tool_tip(out = nil)
    print out if out
    exit 206
  end

  def exit_create_new_document(out = nil)
    print out if out
    exit 207
  end
end